#!/bin/bash
# Xcode Cloud runs this right after cloning, before it resolves packages and builds.
# It installs Tuist, writes the per-Kit secret plists from the workflow's environment
# variables, sets the build number and generates Deskmates.xcworkspace.
# Xcode Cloud runs it with macOS's /bin/bash 3.2, so no bash 4+ features.
set -euo pipefail

REPO="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/../.." && pwd)}"
IOS="$REPO/ios"
APP_NAME="Deskmates"

echo "=== Xcode Cloud post-clone (${CI_WORKFLOW:-local}, ${CI_BRANCH:-no branch}, build ${CI_BUILD_NUMBER:-n/a}) ==="

# --- Secrets ---
# A Kit linked in Project.swift reads its plist at launch and stops the app if a key is
# missing, so a missing variable fails the build here instead of shipping a build that
# crashes on open. Kits that are commented out in Project.swift need nothing.
kit_linked() {
  grep -Eq "^[[:space:]]*(let [A-Za-z]+ = )?add$1\(\)" "$IOS/Project.swift"
}

missing=""
require() {
  local name
  for name in "$@"; do
    if [ -z "${!name:-}" ]; then missing="$missing $name"; fi
  done
}

kit_linked SupabaseKit && require SUPABASE_URL SUPABASE_KEY
kit_linked AnalyticsKit && require POSTHOG_API_KEY POSTHOG_HOST
kit_linked InAppPurchaseKit && require REVENUECAT_API_KEY
kit_linked NotifKit && require ONESIGNAL_APP_ID

if [ -n "$missing" ]; then
  echo "error: set these environment variables on the Xcode Cloud workflow \"${CI_WORKFLOW:-?}\":$missing"
  echo "error: (App Store Connect → Xcode Cloud → Manage Workflows → ${CI_WORKFLOW:-workflow} → Environment)"
  exit 1
fi

# write_plist <Kit> <PlistName> <KEY>... writes Targets/<Kit>/Config/<PlistName>-Info.plist
write_plist() {
  local kit=$1 name=$2; shift 2
  local file="$IOS/Targets/$kit/Config/$name-Info.plist" key value
  mkdir -p "$(dirname "$file")"
  {
    echo '<?xml version="1.0" encoding="UTF-8"?>'
    echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
    echo '<plist version="1.0">'
    echo '<dict>'
    for key in "$@"; do
      value=$(printf '%s' "${!key}" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g')
      printf '    <key>%s</key>\n    <string>%s</string>\n' "$key" "$value"
    done
    echo '</dict>'
    echo '</plist>'
  } > "$file"
  echo "Wrote $kit/Config/$name-Info.plist"
}

kit_linked SupabaseKit && write_plist SupabaseKit Supabase SUPABASE_URL SUPABASE_KEY
kit_linked AnalyticsKit && write_plist AnalyticsKit PostHog POSTHOG_API_KEY POSTHOG_HOST
kit_linked InAppPurchaseKit && write_plist InAppPurchaseKit RevenueCat REVENUECAT_API_KEY
kit_linked NotifKit && write_plist NotifKit OneSignal ONESIGNAL_APP_ID

# --- Build number ---
# Xcode Cloud counts builds per product, so every upload gets a new, increasing number.
if [ -n "${CI_BUILD_NUMBER:-}" ]; then
  echo "Setting build number to ${CI_BUILD_NUMBER}"
  sed -i '' "s/let appBuildNumber = \"[0-9]*\"/let appBuildNumber = \"${CI_BUILD_NUMBER}\"/" "$IOS/Project.swift"
fi

# --- Office art ---
# The LimeZu sprites are packed by ios/Tools/officeart/pack.py. Without them the app builds
# with the procedural fallback office.
if compgen -G "$IOS/Targets/OfficeKit/Resources/OfficeArt/*.png" > /dev/null; then
  echo "Office art: $(find "$IOS/Targets/OfficeKit/Resources/OfficeArt" -type f | wc -l | tr -d ' ') files"
else
  echo "warning: no packed office art in the repo, this build uses the fallback sprites"
fi

# --- Tuist ---
echo "Installing mise..."
curl -fsSL https://mise.run | sh
export PATH="$HOME/.local/bin:$PATH"

echo "Installing Tuist via mise..."
export MISE_HTTP_TIMEOUT=300
cd "$IOS"
mise install --yes || mise install --yes
echo "Tuist $(mise exec -- tuist version)"

echo "Running tuist generate..."
mise exec -- tuist generate --no-open

# --- Swift packages ---
# Xcode Cloud never resolves packages on its own: it needs Package.resolved inside the
# workspace. Tuist restores it from ios/.package.resolved (commit that file to pin versions)
# and resolves after generating. If that left nothing behind, resolve here.
RESOLVED="$IOS/$APP_NAME.xcworkspace/xcshareddata/swiftpm/Package.resolved"
if [ ! -s "$RESOLVED" ]; then
  echo "No Package.resolved after generate, resolving packages..."
  xcodebuild -resolvePackageDependencies -workspace "$IOS/$APP_NAME.xcworkspace" -scheme "$APP_NAME"
fi
if [ ! -s "$RESOLVED" ]; then
  echo "error: $RESOLVED is missing, Xcode Cloud can't resolve the Swift packages"
  exit 1
fi
if [ ! -s "$IOS/.package.resolved" ]; then
  echo "warning: ios/.package.resolved isn't committed, so package versions below each pin can drift between builds"
fi

echo "=== Post-clone complete ==="
