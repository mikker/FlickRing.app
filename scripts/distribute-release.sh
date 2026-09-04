#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_INPUT="${1:-}"
CHANGELOG_FILE="${CHANGELOG_FILE:-$ROOT/CHANGELOG.md}"
APPCAST_FILE="${APPCAST_FILE:-$ROOT/Updates/appcast.xml}"
HOMEBREW_TAP_PATH="${HOMEBREW_TAP_PATH:-$ROOT/../homebrew-tap}"
HOMEBREW_CASK_PATH="$HOMEBREW_TAP_PATH/Casks/flick-ring.rb"
LEGACY_APPCAST_S3_BUCKET="${LEGACY_APPCAST_S3_BUCKET:-}"
SPARKLE_ED_PRIVATE_KEY="${SPARKLE_ED_PRIVATE_KEY:-}"
SPARKLE_ED_PRIVATE_KEY_FILE="${SPARKLE_ED_PRIVATE_KEY_FILE:-}"
EDITOR_CMD="${EDITOR:-${VISUAL:-}}"
SKIP_CHANGELOG_EDIT="${SKIP_CHANGELOG_EDIT:-0}"
PBXPROJ="$ROOT/FlickRing.xcodeproj/project.pbxproj"
ZIP="$ROOT/dist/FlickRing.app.zip"
APP="$ROOT/build/FlickRing.xcarchive/Products/Applications/FlickRing.app"

say() {
  echo "==> $*"
}

die() {
  echo "$*" >&2
  exit 1
}

run_legacy_tool() {
  if [[ "$(uname -m)" == "arm64" ]]; then
    arch -x86_64 "$@"
  else
    "$@"
  fi
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

git_clean() {
  git -C "$ROOT" diff --quiet --ignore-submodules HEAD --
}

current_branch() {
  git -C "$ROOT" rev-parse --abbrev-ref HEAD
}

repo_slug() {
  local remote
  remote="$(git -C "$ROOT" config --get remote.origin.url)"
  REMOTE="$remote" ruby -e '
    remote = ENV.fetch("REMOTE")
    slug = case remote
    when %r{github\.com[:/](.+?)(?:\.git)?$} then $1
    else nil
    end
    abort("Unable to derive GitHub repo slug from #{remote}") if slug.nil? || slug.empty?
    puts slug
  '
}

last_tag() {
  git -C "$ROOT" describe --tags --abbrev=0 --match 'v*' 2>/dev/null || true
}

ensure_changelog_file() {
  [[ -f "$CHANGELOG_FILE" ]] || printf '# Changelog\n\n' > "$CHANGELOG_FILE"
}

seed_notes() {
  local range="$1"
  local notes
  notes="$(git -C "$ROOT" log --no-merges --pretty=format:'- %s' $range 2>/dev/null || true)"
  if [[ -z "${notes//[$' \t\r\n']/}" ]]; then
    notes='- Maintenance release'
  fi
  printf '%s\n' "$notes"
}

prepend_changelog_entry() {
  local heading="$1"
  local notes="$2"
  local tmp
  tmp="$(mktemp)"
  {
    printf '%s\n\n' "$heading"
    printf '%s\n\n' "$notes"
    cat "$CHANGELOG_FILE"
  } > "$tmp"
  mv "$tmp" "$CHANGELOG_FILE"
}

extract_changelog_section() {
  local heading="$1"
  awk -v heading="$heading" '
    $0 == heading { in_section = 1; next }
    in_section && /^## / { exit }
    in_section { print }
  ' "$CHANGELOG_FILE"
}

edit_changelog() {
  [[ -n "$EDITOR_CMD" ]] || return 0
  [[ "$SKIP_CHANGELOG_EDIT" == "1" ]] && return 0
  [[ -t 0 && -t 1 ]] || return 0

  local editor_base="${EDITOR_CMD%% *}"
  command -v "$editor_base" >/dev/null 2>&1 || return 0

  IFS=' ' read -r -a editor_args <<< "$EDITOR_CMD"
  "${editor_args[@]}" "$CHANGELOG_FILE"
}

extract_signature() {
  local output signature private_key
  private_key="$SPARKLE_ED_PRIVATE_KEY"
  if [[ -z "$private_key" && -n "$SPARKLE_ED_PRIVATE_KEY_FILE" ]]; then
    private_key="$(tr -d '\n' < "$SPARKLE_ED_PRIVATE_KEY_FILE")"
  fi

  if [[ -n "$private_key" ]]; then
    output="$(run_legacy_tool "$ROOT/bin/sign_update" -s "$private_key" "$ZIP")"
  else
    output="$(run_legacy_tool "$ROOT/bin/sign_update" "$ZIP")"
  fi

  signature="$(printf '%s\n' "$output" | ruby -ne 'if $_ =~ /sparkle:edSignature="([^"]+)"/; puts $1; exit; end')"
  [[ -n "$signature" ]] || die "Failed to extract Sparkle signature."
  printf '%s\n' "$signature"
}

html_notes() {
  NOTES="$1" ruby -rcgi -e '
    items = []
    ENV.fetch("NOTES").each_line do |line|
      line = line.strip
      next if line.empty?
      next unless line.start_with?("- ")
      text = line.sub(/^-\s+/, "")
      items << "<li>#{CGI.escapeHTML(text)}</li>"
    end
    items = ["<li>Maintenance release</li>"] if items.empty?
    puts "<ul>\n#{items.join("\n")}\n</ul>"
  '
}

write_appcast() {
  local version="$1"
  local build="$2"
  local signature="$3"
  local notes="$4"
  local slug="$5"
  local minimum_system_version length pub_date release_url description

  minimum_system_version="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$APP/Contents/Info.plist")"
  length="$(stat -f%z "$ZIP")"
  pub_date="$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')"
  release_url="https://github.com/$slug/releases/download/v${version}/FlickRing.app.zip"
  description="$(html_notes "$notes")"

  mkdir -p "$(dirname "$APPCAST_FILE")"
  cat > "$APPCAST_FILE" <<EOF
<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
<channel>
<title>FlickRing</title>
<item>
<title>${version}</title>
<pubDate>${pub_date}</pubDate>
<sparkle:minimumSystemVersion>${minimum_system_version}</sparkle:minimumSystemVersion>
<enclosure url="${release_url}" sparkle:version="${build}" sparkle:shortVersionString="${version}" length="${length}" type="application/octet-stream" sparkle:edSignature="${signature}"/>
<description><![CDATA[
${description}
]]></description>
</item>
</channel>
</rss>
EOF
}

homebrew_tap_git_operation() {
  local git_dir marker
  git_dir="$(git -C "$HOMEBREW_TAP_PATH" rev-parse --git-dir 2>/dev/null || true)"
  [[ -n "$git_dir" ]] || return 1
  [[ "$git_dir" == /* ]] || git_dir="$HOMEBREW_TAP_PATH/$git_dir"

  for marker in rebase-apply rebase-merge MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD; do
    if [[ -e "$git_dir/$marker" ]]; then
      echo "$marker"
      return 0
    fi
  done

  return 1
}

homebrew_tap_has_upstream() {
  git -C "$HOMEBREW_TAP_PATH" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' >/dev/null 2>&1
}

update_homebrew_tap() {
  local version="$1"
  local build="$2"
  local slug="$3"
  local sha git_operation

  [[ -d "$HOMEBREW_TAP_PATH/.git" ]] || return 0

  git_operation="$(homebrew_tap_git_operation || true)"
  if [[ -n "$git_operation" ]]; then
    echo "Skipping Homebrew tap update: $HOMEBREW_TAP_PATH has an in-progress git operation ($git_operation)." >&2
    return 0
  fi

  if homebrew_tap_has_upstream; then
    git -C "$HOMEBREW_TAP_PATH" pull --rebase
  fi

  sha="$(shasum -a 256 "$ZIP" | awk '{print $1}')"
  mkdir -p "$(dirname "$HOMEBREW_CASK_PATH")"

  cat > "$HOMEBREW_CASK_PATH" <<EOF
cask("flick-ring") do
  version("${version}")
  sha256("${sha}")

  url(
    "https://github.com/${slug}/releases/download/v#{version}/FlickRing.app.zip",
    verified: "github.com/${slug}/"
  )
  name("FlickRing")
  desc("Action ring for your normie mouse")
  homepage("https://github.com/${slug}")
  auto_updates(true)

  livecheck do
    url("https://mikker.github.io/FlickRing/appcast.xml")
    strategy(:sparkle, &:short_version)
  end

  app("FlickRing.app")

  zap(
    trash: [
      "~/Library/Application Support/FlickRing",
      "~/Library/Caches/com.brnbw.FlickRing",
      "~/Library/Preferences/com.brnbw.FlickRing.plist",
      "~/Library/Saved Application State/com.brnbw.FlickRing.savedState"
    ]
  )
end
EOF

  if ! git -C "$HOMEBREW_TAP_PATH" diff --quiet -- Casks/flick-ring.rb 2>/dev/null; then
    git -C "$HOMEBREW_TAP_PATH" add Casks/flick-ring.rb
    git -C "$HOMEBREW_TAP_PATH" commit -m "Update flick-ring to ${version} (${build})" -- Casks/flick-ring.rb
    if homebrew_tap_has_upstream; then
      git -C "$HOMEBREW_TAP_PATH" push
    fi
  fi
}

sync_legacy_appcast() {
  [[ -n "$LEGACY_APPCAST_S3_BUCKET" ]] || return 0
  command -v s3cmd >/dev/null 2>&1 || die "s3cmd not found; unset LEGACY_APPCAST_S3_BUCKET to skip."
  s3cmd put -P "$APPCAST_FILE" "s3://$LEGACY_APPCAST_S3_BUCKET/appcast.xml"
}

command -v gh >/dev/null 2>&1 || die "gh not found."
command -v git >/dev/null 2>&1 || die "git not found."
[[ -x "$ROOT/bin/sign_update" ]] || die "Missing Sparkle signer at $ROOT/bin/sign_update"
[[ -f "$PBXPROJ" ]] || die "Missing project file: $PBXPROJ"
[[ "$(current_branch)" == "main" ]] || die "Run distribute from main."
git_clean || die "Working tree must be clean before distribute."

say "Packaging release"
"$ROOT/scripts/release-package.sh" "$VERSION_INPUT"

[[ -f "$ZIP" ]] || die "Missing release zip: $ZIP"
[[ -d "$APP" ]] || die "Missing built app: $APP"

VERSION="$(setting MARKETING_VERSION)"
BUILD="$(setting CURRENT_PROJECT_VERSION)"
TAG="v${VERSION}"
SLUG="$(repo_slug)"
LAST_TAG="$(last_tag)"

ensure_changelog_file
CHANGELOG_RANGE="HEAD"
if [[ -n "$LAST_TAG" ]]; then
  CHANGELOG_RANGE="$LAST_TAG..HEAD"
fi

HEADING="## ${VERSION} (${BUILD})"
if ! grep -Fqx "$HEADING" "$CHANGELOG_FILE" 2>/dev/null; then
  prepend_changelog_entry "$HEADING" "$(seed_notes "$CHANGELOG_RANGE")"
fi
edit_changelog
NOTES="$(extract_changelog_section "$HEADING")"
if [[ -z "${NOTES//[$' \t\r\n']/}" ]]; then
  NOTES='- Maintenance release'
fi

say "Signing Sparkle archive"
SIGNATURE="$(extract_signature)"

say "Writing appcast"
write_appcast "$VERSION" "$BUILD" "$SIGNATURE" "$NOTES" "$SLUG"

if ! git -C "$ROOT" diff --quiet -- "$PBXPROJ" "$CHANGELOG_FILE" "$APPCAST_FILE" 2>/dev/null; then
  git -C "$ROOT" add "$PBXPROJ" "$CHANGELOG_FILE" "$APPCAST_FILE"
  git -C "$ROOT" commit -m "Release ${VERSION} (${BUILD})"
fi

if ! git -C "$ROOT" rev-parse "$TAG" >/dev/null 2>&1; then
  git -C "$ROOT" tag -a "$TAG" -m "Release ${VERSION} (${BUILD})"
fi

say "Pushing release commit"
git -C "$ROOT" push origin main
git -C "$ROOT" push origin "$TAG"

NOTES_FILE="$(mktemp)"
trap 'rm -f "$NOTES_FILE"' EXIT
printf '%s\n' "$NOTES" > "$NOTES_FILE"

if gh release view "$TAG" --repo "$SLUG" >/dev/null 2>&1; then
  say "Updating GitHub release"
  gh release upload "$TAG" "$ZIP" --clobber --repo "$SLUG"
  gh release edit "$TAG" --title "$VERSION" --notes-file "$NOTES_FILE" --repo "$SLUG"
else
  say "Creating GitHub release"
  gh release create "$TAG" "$ZIP" --title "$VERSION" --notes-file "$NOTES_FILE" --repo "$SLUG"
fi

say "Updating Homebrew tap"
update_homebrew_tap "$VERSION" "$BUILD" "$SLUG"

say "Syncing legacy S3 appcast"
sync_legacy_appcast

say "Done"
