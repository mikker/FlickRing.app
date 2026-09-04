#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-}"
BUILD_OVERRIDE="${BUILD_OVERRIDE:-}"
NOTARYTOOL_PROFILE="${NOTARYTOOL_PROFILE:-TunaNotary}"
NOTARYTOOL_KEY_ID="${NOTARYTOOL_KEY_ID:-}"
NOTARYTOOL_ISSUER_ID="${NOTARYTOOL_ISSUER_ID:-}"
NOTARYTOOL_KEY_PATH="${NOTARYTOOL_KEY_PATH:-}"
NOTARYTOOL_APPLE_ID="${NOTARYTOOL_APPLE_ID:-}"
NOTARYTOOL_APP_PASSWORD="${NOTARYTOOL_APP_PASSWORD:-}"
NOTARYTOOL_TEAM_ID="${NOTARYTOOL_TEAM_ID:-}"

PBXPROJ="$ROOT/FlickRing.xcodeproj/project.pbxproj"
APP="$ROOT/build/FlickRing.xcarchive/Products/Applications/FlickRing.app"

say() {
  echo "==> $*"
}

die() {
  echo "$*" >&2
  exit 1
}

setting() {
  local key="$1"
  KEY="$key" PBXPROJ="$PBXPROJ" ruby -e '
    key = ENV.fetch("KEY")
    path = ENV.fetch("PBXPROJ")
    File.foreach(path) do |line|
      if line =~ /\b#{Regexp.escape(key)} = ([^;]+);/
        puts $1.strip
        exit
      end
    end
    exit 1
  '
}

next_patch_version() {
  VERSION="$1" ruby -e '
    parts = ENV.fetch("VERSION").split(".")
    abort("Unexpected MARKETING_VERSION") unless parts.all? { |part| part.match?(/\A\d+\z/) }
    parts[-1] = (parts[-1].to_i + 1).to_s
    puts parts.join(".")
  '
}

resolve_build_number() {
  local current_build git_build next_build
  current_build="$(setting CURRENT_PROJECT_VERSION)"
  git_build="$(git -C "$ROOT" rev-list --count HEAD 2>/dev/null || true)"
  [[ -n "$git_build" ]] || die "Unable to compute build number from git history."
  git_build="$((git_build + 100))"
  next_build="$((current_build + 1))"
  if ((git_build > next_build)); then
    next_build="$git_build"
  fi
  if [[ -n "$BUILD_OVERRIDE" ]]; then
    [[ "$BUILD_OVERRIDE" =~ ^[0-9]+$ ]] || die "BUILD_OVERRIDE must be an integer."
    next_build="$BUILD_OVERRIDE"
  fi
  echo "$next_build"
}

update_versions() {
  VERSION="$1" BUILD="$2" ruby -pi -e '
    gsub(/MARKETING_VERSION = [^;]+;/, "MARKETING_VERSION = #{ENV.fetch("VERSION")};")
    gsub(/CURRENT_PROJECT_VERSION = [^;]+;/, "CURRENT_PROJECT_VERSION = #{ENV.fetch("BUILD")};")
  ' "$PBXPROJ"
}

resolve_signing_identity() {
  if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
    echo "$DEVELOPER_ID_APPLICATION"
    return 0
  fi

  local identity_line=""
  identity_line="$(security find-identity -v -p codesigning 2>/dev/null | ruby -ne 'if $_ =~ /\s+[0-9]+\) ([0-9A-F]+) ".*Developer ID Application:/i; puts $1; exit; end' || true)"
  [[ -n "$identity_line" ]] || return 1
  echo "$identity_line"
}

notary_auth_args() {
  if [[ -n "$NOTARYTOOL_PROFILE" ]]; then
    echo "--keychain-profile $NOTARYTOOL_PROFILE"
    return 0
  fi

  if [[ -n "$NOTARYTOOL_KEY_ID" || -n "$NOTARYTOOL_ISSUER_ID" || -n "$NOTARYTOOL_KEY_PATH" ]]; then
    [[ -n "$NOTARYTOOL_KEY_ID" && -n "$NOTARYTOOL_ISSUER_ID" && -n "$NOTARYTOOL_KEY_PATH" ]] || die "Set NOTARYTOOL_KEY_ID, NOTARYTOOL_ISSUER_ID, and NOTARYTOOL_KEY_PATH together."
    echo "--key $NOTARYTOOL_KEY_PATH --key-id $NOTARYTOOL_KEY_ID --issuer $NOTARYTOOL_ISSUER_ID"
    return 0
  fi

  if [[ -n "$NOTARYTOOL_APPLE_ID" || -n "$NOTARYTOOL_APP_PASSWORD" || -n "$NOTARYTOOL_TEAM_ID" ]]; then
    [[ -n "$NOTARYTOOL_APPLE_ID" && -n "$NOTARYTOOL_APP_PASSWORD" && -n "$NOTARYTOOL_TEAM_ID" ]] || die "Set NOTARYTOOL_APPLE_ID, NOTARYTOOL_APP_PASSWORD, and NOTARYTOOL_TEAM_ID together."
    echo "--apple-id $NOTARYTOOL_APPLE_ID --password $NOTARYTOOL_APP_PASSWORD --team-id $NOTARYTOOL_TEAM_ID"
    return 0
  fi

  die "Set NOTARYTOOL_PROFILE or notary API/App Store credentials."
}

codesign_item() {
  local identity="$1"
  local path="$2"
  [[ -e "$path" ]] || return 0
  /usr/bin/codesign \
    --force \
    --options runtime \
    --timestamp \
    --preserve-metadata=entitlements \
    --sign "$identity" \
    "$path"
}

resign_app() {
  local identity="$1"
  local frameworks_dir="$APP/Contents/Frameworks"
  local sparkle="$frameworks_dir/Sparkle.framework"

  if [[ -d "$sparkle" ]]; then
    local sparkle_ver="$sparkle/Versions/Current"
    codesign_item "$identity" "$sparkle_ver/XPCServices/Downloader.xpc"
    codesign_item "$identity" "$sparkle_ver/XPCServices/Installer.xpc"
    codesign_item "$identity" "$sparkle_ver/Updater.app"
    codesign_item "$identity" "$sparkle_ver/Autoupdate"
    codesign_item "$identity" "$sparkle_ver/Sparkle"
  fi

  if [[ -d "$frameworks_dir" ]]; then
    while IFS= read -r framework; do
      codesign_item "$identity" "$framework"
    done < <(find "$frameworks_dir" -mindepth 1 -maxdepth 1 -type d -name '*.framework' ! -name 'Sparkle.framework' | sort)
  fi

  codesign_item "$identity" "$sparkle"
  codesign_item "$identity" "$APP"
}

[[ -f "$PBXPROJ" ]] || die "Missing project file: $PBXPROJ"
command -v xcodebuild >/dev/null 2>&1 || die "xcodebuild not found."
command -v xcrun >/dev/null 2>&1 || die "xcrun not found."
command -v just >/dev/null 2>&1 || die "just not found."

if [[ -z "$VERSION" ]]; then
  VERSION="$(next_patch_version "$(setting MARKETING_VERSION)")"
fi
BUILD="$(resolve_build_number)"

say "Bumping version to $VERSION ($BUILD)"
update_versions "$VERSION" "$BUILD"

say "Archiving release build"
just archive
[[ -d "$APP" ]] || die "Missing built app at $APP"

SIGNING_IDENTITY="$(resolve_signing_identity || true)"
[[ -n "$SIGNING_IDENTITY" ]] || die "Developer ID Application identity not found. Set DEVELOPER_ID_APPLICATION."

say "Re-signing app for Developer ID"
resign_app "$SIGNING_IDENTITY"

AUTH_ARGS=($(notary_auth_args))
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
SUBMIT_ZIP="$TMPDIR/FlickRing-notary-${VERSION}-${BUILD}.zip"

say "Submitting for notarization"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$SUBMIT_ZIP"
xcrun notarytool submit "$SUBMIT_ZIP" --wait "${AUTH_ARGS[@]}"

say "Stapling notarization ticket"
xcrun stapler staple "$APP"

OUTDIR="$ROOT/dist"
mkdir -p "$OUTDIR"
ZIP="$OUTDIR/FlickRing.app.zip"
META="$OUTDIR/release.json"
rm -f "$ZIP"

ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
printf '{ "version": "%s", "build": "%s", "zip": "%s" }\n' "$VERSION" "$BUILD" "$ZIP" > "$META"

say "Release package ready: $ZIP"
say "Release metadata: $META"
