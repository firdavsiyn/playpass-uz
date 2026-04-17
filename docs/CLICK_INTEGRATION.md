# Click.uz интеграция — план внедрения

## Что нужно получить от Click

1. **Merchant ID** (merchant_id) — выдаётся после подписания договора.
2. **Service ID** (service_id) — ID конкретной услуги «PlayPass подписка».
3. **Secret key** — для подписи запросов/ответов.
4. **Merchant User ID** — для API доступа.

Зайти в кабинет мерчанта: https://my.click.uz/

## Архитектура

```
┌─────────────┐     1. Купить     ┌──────────────┐
│  Flutter    │ ────────────────► │ Supabase     │
│  App        │ plan=vip, uid     │ Edge Function│
│             │ ◄─────────────── │ /click-create│
└─────────────┘  payment_url      └──────────────┘
       │                                  │
       │  2. User pays in Click            │ 2. Create pending
       ▼                                  │    payment record
┌─────────────┐                           │
│  Click.uz   │                           ▼
│  Webview    │                    ┌──────────────┐
└─────────────┘                    │  Supabase DB │
       │                           │  payments    │
       │  3. Payment done           └──────────────┘
       ▼                                  ▲
┌─────────────┐  Prepare+Complete         │
│  Click.uz   │ ──────────────────────────┤
│  Webhook    │       webhook              │ 4. Update status,
└─────────────┘                           │    activate sub
                                           │
                                   ┌──────────────┐
                                   │ Edge Function│
                                   │ /click-webhk │
                                   └──────────────┘
```

## Компоненты

### 1. Edge Function: `click-create-payment`
**Endpoint:** `POST /functions/v1/click-create-payment`
**Body:** `{ plan: 'vip' | 'pro' | 'standard' | 'basic' }`
**Response:** `{ payment_url: string, order_id: string }`

Логика:
1. Валидировать, что пользователь авторизован.
2. Получить цену из `subscription_plans`.
3. Создать запись в `payments` с `status='pending'`.
4. Сгенерировать URL оплаты Click (с `merchant_id`, `amount`, `transaction_param=order_id`).
5. Вернуть URL.

### 2. Edge Function: `click-webhook`
**Endpoint:** `POST /functions/v1/click-webhook`
**Security:** проверка подписи `sign_string` с secret_key.

Click вызывает два этапа:
- **Prepare** (action=0): подтверждаем, что заказ валиден.
- **Complete** (action=1): подтверждаем, что деньги получены — активируем подписку.

Логика Complete:
1. Валидировать подпись.
2. Проверить, что `order_id` существует и ещё не оплачен.
3. Обновить `payments.status='completed'`.
4. Создать/продлить `subscriptions` запись для пользователя.
5. Отправить push-уведомление «Подписка активирована».

### 3. Database

```sql
CREATE TABLE IF NOT EXISTS payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) NOT NULL,
  plan TEXT NOT NULL,
  amount_uzs INTEGER NOT NULL,
  provider TEXT NOT NULL CHECK (provider IN ('click', 'payme', 'manual')),
  provider_transaction_id TEXT,  -- Click transaction ID after payment
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed', 'cancelled')),
  created_at TIMESTAMPTZ DEFAULT now(),
  completed_at TIMESTAMPTZ
);

CREATE INDEX idx_payments_user ON payments(user_id);
CREATE INDEX idx_payments_status ON payments(status);

ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
CREATE POLICY payments_select_own ON payments FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR is_superadmin());
-- INSERT/UPDATE only via edge function with service role (no user policy needed)
```

### 4. Flutter: PaymentScreen refactor

Текущий `payment_screen.dart` — ручная заявка (пользователь загружает скрин чека). После интеграции:

1. Убрать поля «телефон», «чек».
2. Кнопка «Оплатить через Click» → вызов edge function → получить `payment_url`.
3. Открыть `WebView` с URL или использовать `url_launcher` для внешнего браузера.
4. После возврата из Click → показать экран «Ожидаем подтверждение…».
5. Polling статуса `payments` раз в 3 сек (или realtime subscription).
6. Статус `completed` → успех, переход на `/home`.

## Click.uz Docs (reference)

- API docs: https://docs.click.uz/click-api/
- Sign formula: `md5(click_trans_id + service_id + SECRET_KEY + merchant_trans_id + amount + action + sign_time)`

## TODO для запуска

- [ ] Подписать договор с Click
- [ ] Получить `merchant_id`, `service_id`, `secret_key`
- [ ] Создать таблицу `payments`
- [ ] Развернуть edge function `click-create-payment`
- [ ] Развернуть edge function `click-webhook`
- [ ] Зарегистрировать webhook URL в кабинете Click
- [ ] Refactor payment_screen.dart на real-payment flow
- [ ] Тестовые транзакции в sandbox Click
- [ ] Production switch
