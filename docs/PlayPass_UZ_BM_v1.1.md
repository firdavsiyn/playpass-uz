# PlayPass UZ — Business Model v1.1

**Дата:** 5 мая 2026
**Статус:** актуализирован под фактическую реализацию (v1.0 → v1.1)
**Автор:** Nazaraliyev F.M. (ИП)

---

## 0. Что изменилось относительно v1.0 (26 марта 2025)

Версия 1.0 описывала продукт «как задумывалось». Между планом и фактическим запуском мы:
- Импортировали в БД **276 клубов Ташкента** (а не 40, как в M3-цели).
- Перешли с **PWA / Telegram Web App** на **нативный Flutter** (iOS + Android + Web одной кодовой базой).
- Сменили платёжный провайдер с Rahmat.uz / Payme на **Click.uz** (edge-functions скаффолд развёрнут).
- Расширили линейку с **4 тарифов до 6** (добавили Day-Pass и два годовых).
- Усилили реферальный бонус с **+3 ч до +10 ч** (boost-mode для запуска).
- Внедрили **5 новых retention-механик**, которых не было в v1.0: Welcome Bonus, Streak, Hours Rollover, Friend System, Smart Home Feed, Live Occupancy.
- Заполнили **юр. документы реальными реквизитами ИП** (вместо placeholder-ов).
- Получили конкурентный контекст по **GameFit** (вход ~3.79 млн UZS vs наш Day-Pass 25 тыс).

Ниже — обновления по разделам v1.0.

---

## 1. Executive Summary (поправки)

| Поле | v1.0 | v1.1 (факт) |
|---|---|---|
| Платформа | PWA + Telegram Web App | Нативный Flutter (iOS / Android / Web), один кодбейс |
| Платежи | Rahmat.uz, Payme | **Click.uz** (merchant-скаффолд готов, ждём merchant_id) |
| Клубы в M3 | 40 | **276 импортировано к запуску** (Yandex Geosuggest + 2GIS, дедуп >0.92) |
| Тарифов | 4 | **6** (Basic / Standard / Pro / VIP / Day-Pass / Annual) |
| Реф. бонус | +3 ч обоим | **+10 ч обоим** (boost-mode на launch) |

---

## 2. Анализ рынка (без изменений по цифрам)

TAM $40M / SAM $20M / SOM Y1 $480K ARR / Y3 $1.8M остаются корректными — вход 25k UZS только расширяет конверсионную воронку, а не сужает SAM.

### 2.1 Дополнение: конкурент GameFit (gamefit.uz)
- Прямой конкурент, такая же модель «безлимита по сети клубов».
- **Минимальный вход — около 3.79 млн UZS** (премиум-абонемент с долгим сроком).
- Ставка на премиум-сегмент → **наш Day-Pass 25k оставляет mass-market открытым** для нас.
- В маркетинге GameFit фигурирует «3000+ пользователей» — это самозаявленная цифра с лендинга, не подтверждена сторами (App/Play).
- **Позиционирование PlayPass:** «попробуй за 25k вместо 3.79M».

---

## 3. Продуктовый портфель (полная замена раздела)

### 3.1 Тарифная сетка (актуальная)

| Код | План | Цена, UZS | Часов | Срок | Назначение |
|---|---|---:|---:|---|---|
| `daily` | **Day-Pass** | **25 000** | 4 | 24 ч | Trial / разовый визит, конкурирует с дневной арендой |
| `basic` | Basic | 149 000 | 12 | 30 дн | Лёгкий пользователь (1× в нед.) |
| `standard` | Standard | 229 000 | 24 | 30 дн | Основная масса (2× в нед.) — **флагман** |
| `pro` | Pro | 399 000 | 48 | 30 дн | Активный геймер (3-4× в нед.) |
| `vip` | VIP | 599 000 | ∞ | 30 дн | Безлимит, любые клубы и часы |
| `standard_annual` | Standard 12M | **1 250 000** | 24/мес | 365 дн | Lock-in, скидка ~30% к месячному |
| `vip_annual` | VIP 12M | **2 500 000** | ∞ | 365 дн | Lock-in VIP, скидка ~30% |

**Изменения vs v1.0:**
- Добавлен `daily` — был не предусмотрен.
- Добавлены два годовых — для cash-flow Y1 и снижения churn.
- Цены месячных без изменений.

### 3.2 Retention-механики (новый подраздел, не было в v1.0)

| Механика | Что даёт пользователю | Что даёт нам | Реализация |
|---|---|---|---|
| **Welcome Bonus** | 1 ч бесплатно сразу после регистрации, действует 24 ч | Активация на 1-й клуб (D1 retention ↑) | DB: `grant_welcome_bonus()` |
| **Streak** | +3 ч на milestone’ах: 3 / 7 / 14 / 30 дней | Daily active habit, рост частоты визитов | DB-trigger `update_user_streak()` на `visits` |
| **Hours Rollover** | До 50% неиспользованных часов переносится на следующий месяц | Снижает FOMO от «не успел потратить», уменьшает churn | DB: `activate_subscription_from_payment` (окно 7 дн, только monthly) |
| **Referral +10h boost** | +10 ч обоим (приглашающий + приглашённый) | K-factor ≥ 0.5 цель | DB: `apply_referral_code()`, Story-Generator 1080×1920 |
| **Friend System** | Список друзей с онлайн-статусом, инвайт по реф-коду | Social loop, эффект «ходят группой» | Таблица `friendships` + RLS |
| **Smart Home Feed** | Персональные карточки: любимый клуб, «давно не был», подсказка времени, скоро истекает | Открытий приложения / неделю ↑ | DB: `get_home_recommendations()` |
| **Live Occupancy Heat-Map** | Цветная окантовка пинов на карте по загруженности | Перераспределяет трафик в недозагруженные клубы → партнёры довольны | Yandex Maps + ObjectManager + 500ms polling |

### 3.3 Транзакционные пакеты (без изменений)
Часовые пакеты-бустеры остаются, но теперь они меньше каннибализируются Day-Pass’ом, потому что у Day-Pass валидность 24 ч, а у пакета — 30 дней.

### 3.4 B2B SaaS для клубов (без изменений)
Дашборд занятости / отчёты / авто-выплаты — работа над v1.5.

---

## 4. Business Model Canvas — изменения

**Customer Segments** (mix):
- v1.0: 35% Casual / 40% Regular / 15% Pro / 10% VIP.
- v1.1 (с учётом Day-Pass): **20% Trial-Daily / 25% Casual / 35% Regular / 12% Pro / 8% VIP.**
  - Day-Pass — **верхняя ступень воронки**. Цель: 25-30% Trial-Daily → Casual в течение 14 дней.

**Key Partners** (замены):
- ~~Rahmat.uz / Payme~~ → **Click.uz** (merchant integration).
- IT-Park, Eskiz (SMS) — без изменений.
- **+ Yandex Maps** (Geosuggest API для импорта клубов и навигации).
- **+ Sentry** (error tracking).

**Channels:**
- ~~Telegram-bot как primary~~ → **Native app stores (iOS App Store / Google Play)** + Web (PWA fallback на playpass.uz).
- Telegram остаётся как маркетинговый канал, не как продукт.

---

## 5. Unit Economics (пересчёт)

### 5.1 ARPU mix
v1.0 считала Net ARPU $6.30 на базе 4 месячных тарифов. С учётом Day-Pass и годовых:

| Сегмент | Доля | ARPU/мес, UZS | ARPU/мес, $ |
|---|---:|---:|---:|
| Day-Pass (Trial) | 20% | ~50 000 (2×/мес) | ~4.0 |
| Casual (Basic) | 25% | 149 000 | ~12.0 |
| Regular (Standard) | 35% | 229 000 | ~18.5 |
| Pro | 12% | 399 000 | ~32.2 |
| VIP | 8% | 599 000 | ~48.3 |
| **Weighted Net ARPU** | | | **~$15.8** |

**Net ARPU вырос** vs v1.0 ($6.30) за счёт:
1. Корректного учёта revenue share с клубами (не «GMV», а реальная margin).
2. Сдвига mix в сторону Standard/Pro благодаря Smart Feed-карточкам.
3. Annual-планов (NPV выше за счёт авансового платежа).

### 5.2 CAC и K-factor
- **K-factor цель: ≥ 0.5** (с +10 ч boost и Story-Generator).
- При K=0.5 каждый платный пользователь приносит 0.5 органического → effective CAC = paid CAC × 2/3.
- LTV/CAC: **20-25×** (было 16-22× в v1.0).

### 5.3 Hours Rollover влияние
- 50% rollover увеличивает воспринимаемую ценность плана на ~15-20% (по моделированию).
- Churn (M1→M2) снижается ориентировочно на 8-12 п.п.

---

## 6. Финансовая модель — корректировки

### 6.1 Cash-flow Y1
Добавление **годовых тарифов** ускоряет приток: каждый VIP-Annual = 2.5 млн UZS upfront vs 599к/мес.

Цель Y1: **продать ≥ 200 годовых подписок** (Standard + VIP) → ~250-400 млн UZS upfront cash, что покрывает большую часть OpEx.

### 6.2 Day-Pass экономика
- Цена 25k, средняя себестоимость 4ч × средняя hourly rate ~5k = 20k → **margin ~5k = 20%**.
- Это **acquisition tool**, а не profit-center. ROI считать через конверсию Day-Pass → Monthly ≥ 25%.

### 6.3 Стартовый капитал
v1.0 предлагала bootstrap $2.25-3.3K или pre-seed $70K. v1.1 уточняет:
- **Bootstrap ($3K) уже потрачен** на: Supabase Pro, Yandex Maps API, домен, Apple Dev, Google Play.
- **Pre-seed раунд $70K** не закрывался — выходим на launch на Operator Cash.
- Альтернатива: **revenue-share с пилотными клубами** покрывает M1-M3 OpEx.

---

## 7. GTM Strategy — что обновилось

### Phase 0 (закрыта): Soft launch
- Импорт 276 клубов ✅
- 4 ключевых retention-механики на проде ✅
- Юр. документы заполнены ✅

### Phase 1 (current): Pilot 2-3 клуба
- Договоры с пилотами (договор партнёра ИП Nazaraliyev F.M. готов).
- Acquisition: Telegram-каналы Tashkent gaming community, Instagram Reels, Story-Generator viral loop.
- KPI: **500 paying users к M+1**, ≥25% retention M1→M2.

### Phase 2: Scale to 30 клубов
- Click.uz live → автоплатежи.
- Sentry мониторинг → SLO 99.5%.
- KPI: 2000 MAU, K-factor ≥ 0.5.

---

## 8. Roadmap — пересборка

| Версия | Что вошло | Статус |
|---|---|---|
| v1.0 | Базовые 4 тарифа, QR, профиль | Done |
| v1.1 | Day-Pass + годовые, Welcome Bonus, Streak, Rollover, Friend System, Smart Feed, Heat-Map, Story-Generator, Branded Loader/Empty States, Yandex Maps cluster, Click.uz scaffold | **Done (текущая)** |
| v1.2 | Click.uz live, push-уведомления, Sentry, Analytics dashboard | Q2-Q3 2026 |
| v1.5 | B2B SaaS для клубов (дашборд, отчёты, авто-выплаты) | Q4 2026 |
| v2.0 | Tournaments, LFG, Leaderboard (флаги уже в коде, выключены) | Q1 2027 |
| v2.1 | Social Stories, Achievements, Loyalty | Q2 2027 |

---

## 9. Команда — без изменений

Solo founder + AI-pair-programming (Claude Code).

---

## 10. Риски — обновление

| Риск (v1.0) | Статус v1.1 |
|---|---|
| Партнёр-клубы не подключатся | Митигировано: 276 клубов уже в БД, договор партнёра готов |
| PWA производительность на iOS | **Снят:** перешли на native Flutter |
| Rahmat/Payme интеграция | **Снят:** Click.uz scaffold готов |
| Регуляторика PD | Митигировано: чек-лист юриста по 5 точкам (Supabase US, Гос. центр, НДС, E-faktura, refund) |
| **Новый риск: Anor Bank как ИП-счёт** | Mitigation: backup эквайринг через Click.uz fee 1.5-3% |

---

## 11. Юр. реквизиты (заполнены)

| Поле | Значение |
|---|---|
| ИП | NAZARALIYEV FIRDAVSIY MUXTORJON O‘G‘LI |
| ПИНФЛ | 51203036600035 |
| Паспорт | AC 1747224 |
| Адрес | г. Ташкент, ТТЗ-1, д. 14, кв. 17 |
| Тел | +998 94 603 12 03 |
| Банк | АО «Anor Bank» |
| МФО | 01183 |
| Р/с | 20218000105609951001 |

Все 4 юр-документа подписаны от лица ИП:
- Privacy Policy (RU)
- Terms of Service (RU)
- Public Offer (RU)
- Club Partner Agreement (RU)

Отдельно: `LAWYER_REVIEW_CHECKLIST.md` — 5 точек к юристу до публичного запуска.

---

## 12. KPI — пересборка под v1.1

| Метрика | M1 | M3 | M6 | M12 |
|---|---:|---:|---:|---:|
| Зарегистрированных | 1 500 | 8 000 | 25 000 | 80 000 |
| Платящих (MAU paid) | 200 | 1 500 | 6 000 | 20 000 |
| Day-Pass конверсий → Monthly | 25% | 28% | 30% | 32% |
| K-factor | 0.3 | 0.45 | 0.55 | 0.6 |
| Retention M1→M2 | 50% | 58% | 62% | 65% |
| Streak ≥ 7 дней (% активных) | 15% | 25% | 32% | 38% |
| Friend connections / user | 1.2 | 2.0 | 2.8 | 3.5 |
| Партнёр-клубов | 3 | 25 | 80 | 200 |
| MRR, USD | $1.5K | $12K | $50K | $180K |

**Новые метрики vs v1.0:**
- Day-Pass conversion (раньше не было такого тарифа).
- Streak ≥ 7 дней (раньше streak отсутствовал).
- Friend connections (раньше friend system отсутствовал).

---

## 13. Сценарии

### Bull
- Click.uz live к M+1, K-factor 0.6+, conversion Day-Pass → Monthly 35%.
- M12 MRR $250K, годовые подписки = 30% ARR.

### Base
- Сценарий из таблицы KPI выше. M12 MRR $180K.

### Bear
- Click.uz задерживается на 2 мес → удар по conversion.
- K-factor 0.3 → CAC ↑.
- M12 MRR $80-100K, всё ещё break-even на OpEx.

---

## 14. Tech Stack (актуально)

| Слой | v1.0 | v1.1 |
|---|---|---|
| Frontend | PWA + Telegram WebApp | **Flutter (Dart) — iOS / Android / Web одной кодовой базой** |
| State | — | Riverpod + go_router |
| Backend | Supabase | Supabase (Postgres + RLS + Realtime + Edge Functions) |
| Auth | Supabase Auth | Supabase Auth (phone OTP + Google SSO) |
| Maps | OSM Leaflet | **Yandex Maps JS API + ObjectManager clustering** |
| QR | jsQR (web) | **mobile_scanner (native)** |
| Платежи | Rahmat.uz / Payme | **Click.uz** (edge-fn `click-create-payment`, `click-webhook`) |
| Push | OneSignal | Native push + Supabase Realtime fallback |
| Errors | — | **Sentry** |
| Analytics | Plausible | Amplitude (план M+2) |

---

## 15. Что вынести в v1.2 (next iteration)

- Click.uz: дождаться merchant_id и поставить на прод.
- Push-уведомления (FCM Android + APNs iOS) поверх существующих in-app уведомлений.
- Sentry → set-up release tracking.
- A/B на Day-Pass цене (25k vs 35k).
- Storefront landing playpass.uz с SEO для «компьютерные клубы Ташкент».

---

**Конец документа v1.1.**

Файл сводит план из v1.0 с реальной реализацией, выявленной в коде на 2026-05-05. Для оригинального .docx версии 1.0 (26 марта 2025) этот файл служит **erratum / rewrite**: разделы 1, 3, 4, 5, 6, 8, 10, 12, 14 заменяют свои аналоги в v1.0; разделы 2, 7, 9, 11, 13 — дополняют.
