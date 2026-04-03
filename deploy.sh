#!/bin/bash
# ============================================================
# GamePass UZ — Deploy Script
# Run: chmod +x deploy.sh && ./deploy.sh
# Requires: supabase CLI logged in (supabase login)
# ============================================================

set -e

SUPABASE="$HOME/development/supabase"
PROJECT_DIR="$(dirname "$0")"
FLUTTER_BIN="$HOME/development/flutter/bin"

echo "🎮 GamePass UZ — Deploy"
echo "========================"

# ── 1. Check Supabase login ─────────────────────────────
echo ""
echo "📡 Checking Supabase auth..."
$SUPABASE projects list 2>/dev/null || {
  echo "❌ Not logged in. Run: $SUPABASE login"
  exit 1
}

# ── 2. Ask for project ref ──────────────────────────────
read -p "Enter your Supabase project ref (e.g. abcdefghij): " PROJECT_REF

# ── 3. Link project ─────────────────────────────────────
echo ""
echo "🔗 Linking to project $PROJECT_REF..."
cd "$PROJECT_DIR"
$SUPABASE link --project-ref "$PROJECT_REF"

# ── 4. Run migrations ───────────────────────────────────
echo ""
echo "🗃️  Running database migrations..."
$SUPABASE db push

# ── 5. Deploy Edge Functions ────────────────────────────
echo ""
echo "⚡ Deploying Edge Functions..."
$SUPABASE functions deploy checkin       --no-verify-jwt
$SUPABASE functions deploy rahmat-webhook --no-verify-jwt
$SUPABASE functions deploy qr-validate
$SUPABASE functions deploy payout-calc   --no-verify-jwt

# ── 6. Set Edge Function secrets ────────────────────────
echo ""
echo "🔐 Setting secrets (from .env file if exists)..."
if [ -f "$PROJECT_DIR/.env" ]; then
  while IFS='=' read -r key value; do
    [[ "$key" =~ ^#.*$ ]] && continue
    [[ -z "$key" ]] && continue
    $SUPABASE secrets set "$key=$value" 2>/dev/null || true
  done < "$PROJECT_DIR/.env"
  echo "✅ Secrets set from .env"
else
  echo "⚠️  No .env file found. Create one from .env.example and run manually:"
  echo "   $SUPABASE secrets set RAHMAT_API_KEY=xxx"
fi

# ── 7. Flutter build ────────────────────────────────────
echo ""
read -p "Build Flutter APK? (y/N): " BUILD_FLUTTER
if [[ "$BUILD_FLUTTER" == "y" || "$BUILD_FLUTTER" == "Y" ]]; then
  export PATH="$FLUTTER_BIN:$PATH"
  cd "$PROJECT_DIR/flutter_app"
  echo "📱 Building Flutter APK..."
  flutter build apk --release \
    --dart-define=SUPABASE_URL=https://$PROJECT_REF.supabase.co \
    --dart-define=SUPABASE_ANON_KEY=$(grep SUPABASE_ANON_KEY "$PROJECT_DIR/.env" | cut -d= -f2)
  echo "✅ APK: build/app/outputs/flutter-apk/app-release.apk"
fi

echo ""
echo "✅ Deploy complete!"
echo ""
echo "Next steps:"
echo "  1. Set Rahmat.uz webhook URL in their dashboard:"
echo "     https://YOUR_PROJECT.supabase.co/functions/v1/rahmat-webhook"
echo "  2. Import n8n workflows from ./n8n-workflows/*.json"
echo "  3. Set n8n env vars: SUPABASE_URL, SUPABASE_SERVICE_KEY, ESKIZ_TOKEN, FCM_SERVER_KEY"
echo "  4. Open web-admin/index.html and set SUPABASE_URL + SUPABASE_ANON in app.js"
