# Android Build & Release Guide

## Prerequisites

- Flutter SDK 3.24+
- Android Studio / command-line tools (for `keytool`)
- Google Play Developer account ($25 one-time)
- JDK 17

## Step 1: Generate release keystore (ONE TIME)

```bash
cd ~/playpass-keys  # or any safe location OUTSIDE the repo
keytool -genkey -v -keystore playpass-release.jks \
        -keyalg RSA -keysize 2048 -validity 10000 \
        -alias playpass
```

You will be asked:
- Keystore password (save in 1Password)
- Key password (same as above is fine)
- Your name, org unit, org, city, state, country

**CRITICAL:** Back up `playpass-release.jks` somewhere safe. If you lose it, you CANNOT update the app in Play Store — you'd have to publish a new app.

## Step 2: Configure key.properties

Copy the example and fill in real values:

```bash
cp flutter_app/android/key.properties.example flutter_app/android/key.properties
# Edit flutter_app/android/key.properties — set real passwords + storeFile path
```

This file is gitignored.

## Step 3: Bump version

Open `flutter_app/pubspec.yaml`:

```yaml
version: 1.0.0+1   # format: semver+buildNumber
```

For each release:
- Update semver (`1.0.1`, `1.1.0`, `2.0.0`) on user-facing changes
- Increment build number (`+2`, `+3`, ...) on every upload (Play Store rejects duplicate codes)

## Step 4: Production build

```bash
cd flutter_app

# Option A: APK (for sideloading / testing)
flutter build apk --release \
  --dart-define=SENTRY_DSN="<YOUR_DSN>" \
  --dart-define=APP_VERSION="1.0.0" \
  --dart-define=ENVIRONMENT="production"

# Option B: AAB (for Google Play — recommended)
flutter build appbundle --release \
  --dart-define=SENTRY_DSN="<YOUR_DSN>" \
  --dart-define=APP_VERSION="1.0.0" \
  --dart-define=ENVIRONMENT="production"
```

Outputs:
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- AAB: `build/app/outputs/bundle/release/app-release.aab`

## Step 5: Test APK on a real device

```bash
flutter install  # installs to connected Android device
```

Test critical flows:
- [ ] Регистрация → email подтверждение
- [ ] Логин
- [ ] Покупка подписки (в тестовом режиме Click)
- [ ] QR-скан в клубе
- [ ] Пуш-уведомления
- [ ] Переключение RU/UZ
- [ ] Dark/Light theme
- [ ] Оффлайн режим (показ ошибок)

## Step 6: Upload to Google Play Console

1. Зайти в https://play.google.com/console
2. Создать новое приложение (если ещё нет):
   - Название: PlayPass
   - Язык по умолчанию: Русский (Россия)
   - Тип: Приложение
   - Бесплатное/платное: Бесплатное
3. Перейти в **Production → Create new release**
4. Upload `app-release.aab`
5. Release notes (RU/UZ)
6. Submit for review

**Первая публикация проверяется Google 3–7 дней.** Последующие обновления — несколько часов.

## Step 7: Play Console checklist

Перед первой публикацией нужно заполнить:

- [ ] **Privacy Policy URL** — хостинг `docs/PRIVACY_POLICY_RU.md` на `playpass.uz/privacy`
- [ ] **App content rating** — пройти анкету (обычно получится 3+ или 12+)
- [ ] **Target audience** — возраст от 14+
- [ ] **Data safety** — декларация что собираем: Email, Name, Location (approx), Device ID, Crash logs, Photos (avatar), Geo (при чекине)
- [ ] **Screenshots** — минимум 2 на телефон, 1080×1920 рекомендовано
- [ ] **Feature graphic** — 1024×500, PNG без прозрачности
- [ ] **App icon** — 512×512
- [ ] **Short description** — до 80 символов
- [ ] **Full description** — до 4000 символов

## Env var для CI

Для automated builds в GitHub Actions:

```yaml
env:
  ANDROID_KEYSTORE_BASE64: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
  ANDROID_KEY_PROPERTIES: ${{ secrets.ANDROID_KEY_PROPERTIES }}
  SENTRY_DSN: ${{ secrets.SENTRY_DSN }}
```

Расшифровать `.jks` из base64:
```bash
echo "$ANDROID_KEYSTORE_BASE64" | base64 -d > android/app/playpass.jks
echo "$ANDROID_KEY_PROPERTIES" > android/key.properties
```

## Troubleshooting

**Build fails with "Key not found"**
→ Проверь путь `storeFile` в `key.properties` — должен быть абсолютный.

**Play Console says "Version code already used"**
→ Увеличь build number в `pubspec.yaml` (часть после `+`).

**"Your app is currently not compliant with Google Play Policies"**
→ Обычно из-за отсутствия Privacy Policy URL. Заполни в Play Console → App content.

**R8/ProGuard crashes в release**
→ Добавь `-keep class <problem_class>` в `proguard-rules.pro`.
