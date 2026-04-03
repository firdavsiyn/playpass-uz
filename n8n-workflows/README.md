# GamePass UZ — n8n Workflows

Import each JSON file via: n8n → Workflows → Import from file

## Workflows

| File | Trigger | Description |
|------|---------|-------------|
| 01_subscription_activated.json | Webhook POST /subscription-activated | Push + SMS when subscription activates |
| 02_daily_hmac.json | Cron 00:00 daily | Generate daily_secret + update QR tokens |
| 03_expiry_reminder_5d.json | Cron daily 10:00 | Remind users 5 days before expiry |
| 04_expiry_reminder_1d.json | Cron daily 10:00 | Remind users 1 day before expiry |
| 05_monthly_payout.json | Cron 1st of month 09:00 | Calculate and initiate club payouts |
| 06_referral_bonus.json | Webhook POST /referral-bonus | Apply +3h bonus to inviter and invitee |
| 07_checkin_notification.json | Supabase Webhook on visits INSERT | Notify club on new visit |

## Environment Variables (set in n8n Credentials)

- SUPABASE_URL
- SUPABASE_SERVICE_KEY
- ESKIZ_EMAIL + ESKIZ_PASSWORD
- FCM_SERVER_KEY
- N8N_WEBHOOK_SECRET
