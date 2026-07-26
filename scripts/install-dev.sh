#!/bin/bash

set -euo pipefail

APP_NAME="OpenWhispr"
BUNDLE_ID="dev.openwhispr.app"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_ROOT="$PROJECT_DIR/build/dev"
BUILT_APP="$BUILD_ROOT/DerivedData/Build/Products/Debug/$APP_NAME.app"
INSTALL_DIR="${OPENWHISPR_INSTALL_DIR:-/Applications}"
INSTALLED_APP="$INSTALL_DIR/$APP_NAME.app"

log() {
    printf '==> %s\n' "$1"
}

fail() {
    printf 'ERROR: %s\n' "$1" >&2
    exit 1
}

designated_requirement() {
    codesign --display --requirements - "$1" 2>&1 \
        | sed -n 's/^designated => //p'
}

find_signing_identity() {
    local identities
    local identity

    identities="$(security find-identity -v -p codesigning 2>/dev/null || true)"

    if [[ -n "${OPENWHISPR_SIGNING_IDENTITY:-}" ]]; then
        identity="$OPENWHISPR_SIGNING_IDENTITY"
    else
        identity="$(
            awk '/"Apple Development:/ { print $2; exit }' <<< "$identities"
        )"
        if [[ -z "$identity" ]]; then
            identity="$(
                awk '$1 ~ /^[0-9]+\)$/ { print $2; exit }' <<< "$identities"
            )"
        fi
    fi

    [[ -n "$identity" ]] || return 1

    if ! grep -Fq "$identity" <<< "$identities"; then
        fail "Signing identity '$identity' is not available in the keychain."
    fi

    printf '%s\n' "$identity"
}

if [[ -z "$INSTALL_DIR" || "$INSTALL_DIR" != /* ||
      "$INSTALLED_APP" != */OpenWhispr.app || "$INSTALL_DIR" == "/" ]]; then
    fail "Refusing unsafe installation path: $INSTALLED_APP"
fi

SIGNING_IDENTITY="$(find_signing_identity || true)"
if [[ -z "$SIGNING_IDENTITY" ]]; then
    cat >&2 <<'EOF'
ERROR: No valid code-signing identity is installed.

One-time setup:
  1. Open Xcode > Settings > Accounts.
  2. Add your Apple ID if needed.
  3. Select your team, choose Manage Certificates, and create an
     Apple Development certificate.
  4. Run `make dev-install` again.

Stable signing is required so macOS can preserve Accessibility permission
between builds. An ad-hoc signature would recreate the original problem.
EOF
    exit 2
fi

log "Building a signed Debug app"
log "Signing identity: $SIGNING_IDENTITY"

xcodebuild \
    -project "$PROJECT_DIR/OpenWhispr.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Debug \
    -derivedDataPath "$BUILD_ROOT/DerivedData" \
    -destination "platform=macOS" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
    build

[[ -d "$BUILT_APP" ]] || fail "Expected build product was not created: $BUILT_APP"

codesign --verify --deep --strict --verbose=2 "$BUILT_APP"

BUILT_REQUIREMENT="$(designated_requirement "$BUILT_APP")"
[[ -n "$BUILT_REQUIREMENT" ]] \
    || fail "The built app has no designated code requirement."

if [[ -d "$INSTALLED_APP" ]]; then
    INSTALLED_REQUIREMENT="$(designated_requirement "$INSTALLED_APP" || true)"
    if [[ -n "$INSTALLED_REQUIREMENT" && "$INSTALLED_REQUIREMENT" != "$BUILT_REQUIREMENT" ]]; then
        printf '%s\n' \
            "NOTE: The signing identity changed. macOS may require one final" \
            "      Accessibility approval after this installation."
    fi
fi

log "Stopping the currently installed app"
osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true

for _ in {1..20}; do
    if ! pgrep -x "$APP_NAME" >/dev/null; then
        break
    fi
    sleep 0.1
done

if pgrep -x "$APP_NAME" >/dev/null; then
    pkill -x "$APP_NAME" || true
fi

mkdir -p "$INSTALL_DIR"
if [[ -e "$INSTALLED_APP" ]]; then
    rm -rf "$INSTALLED_APP"
fi

log "Installing $INSTALLED_APP"
ditto "$BUILT_APP" "$INSTALLED_APP"
codesign --verify --deep --strict --verbose=2 "$INSTALLED_APP"

INSTALLED_REQUIREMENT="$(designated_requirement "$INSTALLED_APP")"
[[ "$INSTALLED_REQUIREMENT" == "$BUILT_REQUIREMENT" ]] \
    || fail "The installed app's designated requirement changed while copying."

log "Launching $APP_NAME"
open "$INSTALLED_APP"

printf '\nInstalled and launched %s\n' "$INSTALLED_APP"
printf 'Designated requirement: %s\n' "$INSTALLED_REQUIREMENT"
