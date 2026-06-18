-- ════════════════════════════════════════════════════════════════════════
-- Audit 2026-06-18 — HIGH fixes #1, #2, #3, #6 (+ adversarial-review fixes)
--   #1 activate_subscription_from_payment: idempotent (payment-level guard) +
--      locked search_path. Prevents lost/double subscriptions on webhook retry.
--   #2 Day-Pass money-safe: daily grants 2 visits; check-in off-peak gate now
--      covers 'daily' too (edge fn) → worst case 2×10000 < 25000 price.
--   #3 redeem_promo now actually APPLIES the bonus to the active subscription.
--   #6 redeem_promo uses the real columns (expires_at / used_count).
-- Review fixes: (a) end_date stacking was a captured-variable lost-update →
--   now column-relative + FOR UPDATE; (b) `record IS NOT NULL` is true only
--   when ALL columns are non-null, so the stacking/rollover branches were dead
--   → use `.id IS NOT NULL`; (c) unlimited sub no longer burns an hours promo;
--   (d) best-effort notification can't roll back provisioning.
-- ════════════════════════════════════════════════════════════════════════

-- #1/#4 — idempotency marker on payments.
ALTER TABLE public.payments
  ADD COLUMN IF NOT EXISTS activated boolean NOT NULL DEFAULT false;
UPDATE public.payments SET activated = true WHERE status = 'completed';

-- #2 — Day-Pass visit count (kept in sync with the forced value in the fn).
UPDATE public.subscription_plans SET hours = 2 WHERE code = 'daily';

-- Review (d): make sure notifications.title/body exist so the activation
-- INSERT can never fail on a fresh environment (no-op where already present).
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS title text;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS body  text;

-- ── #1 / #2: activation — idempotent, search_path locked, daily forced safe ──
CREATE OR REPLACE FUNCTION public.activate_subscription_from_payment(payment_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  p RECORD;
  existing_sub RECORD;
  plan_hours INT;
  rollover_hours INT := 0;
  duration_days INT := 30;
BEGIN
  -- Lock the payment row → concurrency-safe + idempotent.
  SELECT * INTO p FROM payments WHERE id = payment_id FOR UPDATE;
  IF p IS NULL THEN RAISE EXCEPTION 'Payment not found'; END IF;
  IF p.status != 'completed' THEN RAISE EXCEPTION 'Payment not completed'; END IF;
  IF p.activated THEN RETURN; END IF;  -- already provisioned → no-op

  SELECT hours INTO plan_hours FROM subscription_plans WHERE code = p.plan;
  IF plan_hours = -1 THEN plan_hours := NULL; END IF;

  IF p.plan = 'daily' THEN
    duration_days := 1;
    plan_hours := 2;  -- money-safe: 2 off-peak visits (2*10000 < 25000)
  ELSIF p.plan LIKE '%_annual' THEN
    duration_days := 365;
  ELSE
    duration_days := 30;
  END IF;

  -- Lock the existing active sub so concurrent same-user activations serialize.
  SELECT * INTO existing_sub FROM subscriptions
    WHERE user_id = p.user_id AND status = 'active' AND end_date > CURRENT_DATE
    ORDER BY end_date DESC LIMIT 1
    FOR UPDATE;

  IF existing_sub.id IS NOT NULL THEN
    -- Column-relative write (NOT existing_sub.end_date) so a serialized
    -- second activation extends the already-extended value (no lost update).
    UPDATE subscriptions SET
      end_date = end_date + (duration_days || ' days')::INTERVAL,
      hours_balance = COALESCE(hours_balance, 0) + COALESCE(plan_hours, 0),
      hours_total = COALESCE(hours_total, 0) + COALESCE(plan_hours, 0)
    WHERE id = existing_sub.id;
  ELSE
    IF p.plan != 'daily' THEN
      SELECT * INTO existing_sub FROM subscriptions
        WHERE user_id = p.user_id AND status = 'active'
          AND end_date BETWEEN CURRENT_DATE - INTERVAL '7 days' AND CURRENT_DATE
        ORDER BY end_date DESC LIMIT 1;
      IF existing_sub.id IS NOT NULL AND existing_sub.hours_balance IS NOT NULL THEN
        rollover_hours := LEAST(FLOOR(existing_sub.hours_balance * 0.5)::INT, COALESCE(plan_hours / 2, 0));
      END IF;
    END IF;

    INSERT INTO subscriptions (user_id, plan, start_date, end_date, hours_balance, hours_total, status, price_uzs, hours_rolled_over)
    VALUES (
      p.user_id, p.plan, CURRENT_DATE,
      CURRENT_DATE + (duration_days || ' days')::INTERVAL,
      COALESCE(plan_hours + rollover_hours, NULL),
      COALESCE(plan_hours + rollover_hours, NULL),
      'active', p.amount_uzs, rollover_hours
    );
  END IF;

  -- Mark provisioned so retries are no-ops.
  UPDATE payments SET activated = true WHERE id = payment_id;

  -- Best-effort notification — must NEVER roll back the money-critical
  -- provisioning above if the notifications schema differs.
  BEGIN
    INSERT INTO notifications (user_id, title, body, type, event)
    VALUES (
      p.user_id,
      CASE WHEN p.plan = 'daily' THEN 'Day Pass активирован!'
           WHEN p.plan LIKE '%_annual' THEN 'Годовая подписка активирована!'
           ELSE 'Подписка активирована' END,
      CASE WHEN p.plan = 'daily' THEN 'Доступно ' || COALESCE(plan_hours, 0) || ' визита (08:00–18:00), 1 день.'
           WHEN p.plan LIKE '%_annual' THEN 'Срок действия: 365 дней.'
           WHEN rollover_hours > 0 THEN 'Бонус: ' || rollover_hours || ' часов перенесено.'
           ELSE 'Ваша подписка ' || p.plan || ' активирована!' END,
      'push', 'subscription_activated'
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;  -- swallow: notification is non-critical
  END;
END;
$function$;

-- ── #3 / #6: redeem_promo — correct columns + actually apply the bonus ──
CREATE OR REPLACE FUNCTION public.redeem_promo(p_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_promo public.promos%ROWTYPE;
  v_already_used boolean;
  v_sub public.subscriptions%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'not_authenticated');
  END IF;

  -- FOR UPDATE on the promo row serializes all redemptions of this code,
  -- so the EXISTS-then-INSERT below is race-safe without a unique index.
  SELECT * INTO v_promo
    FROM public.promos
   WHERE code = p_code
     AND is_active = true
     AND (expires_at IS NULL OR expires_at > now())
     AND (max_uses = 0 OR used_count < max_uses)
   FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'invalid_or_exhausted');
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.promo_usages
     WHERE user_id = v_uid AND promo_id = v_promo.id
  ) INTO v_already_used;

  IF v_already_used THEN
    RETURN jsonb_build_object('success', false, 'reason', 'already_used');
  END IF;

  -- Apply the bonus to the user's active subscription (audit High #3).
  IF v_promo.type IN ('hours', 'days') THEN
    SELECT * INTO v_sub FROM public.subscriptions
      WHERE user_id = v_uid AND status = 'active' AND end_date >= CURRENT_DATE
      ORDER BY end_date DESC LIMIT 1
      FOR UPDATE;
    IF v_sub.id IS NULL THEN
      RETURN jsonb_build_object('success', false, 'reason', 'no_active_subscription');
    END IF;

    IF v_promo.type = 'hours' THEN
      -- Unlimited sub: an hours bonus is meaningless — don't burn the code.
      IF v_sub.hours_balance IS NULL THEN
        RETURN jsonb_build_object('success', false, 'reason', 'no_bonus_needed');
      END IF;
      UPDATE public.subscriptions
         SET hours_balance = hours_balance + v_promo.value,
             hours_total   = COALESCE(hours_total, 0) + v_promo.value
       WHERE id = v_sub.id;
    ELSE  -- 'days'
      UPDATE public.subscriptions
         SET end_date = end_date + (v_promo.value || ' days')::INTERVAL
       WHERE id = v_sub.id;
    END IF;
  END IF;
  -- 'discount' (and any other type): just record usage, applied at purchase.

  UPDATE public.promos SET used_count = used_count + 1 WHERE id = v_promo.id;
  INSERT INTO public.promo_usages (user_id, promo_id) VALUES (v_uid, v_promo.id);

  RETURN jsonb_build_object('success', true, 'type', v_promo.type, 'value', v_promo.value);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.redeem_promo(text) TO authenticated;

NOTIFY pgrst, 'reload schema';
