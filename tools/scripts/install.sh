#!/usr/bin/env bash
set -Eeuo pipefail

die(){ echo "[ERR] $*" >&2; exit 1; }
trap 'die "failed at line $LINENO"' ERR

# 0) Ensure we are inside a Git repository
[ -d .git ] || die ".git/ not found. Run this script at the root of your Git project."
command -v curl >/dev/null 2>&1 || die "required: curl"
command -v tar  >/dev/null 2>&1 || die "required: tar"

BIN_DIR=".git/hooks/bin"
HOOK_FILE=".git/hooks/pre-commit"
mkdir -p "$BIN_DIR" ".git/hooks"

# 1) Detect OS/ARCH to match Gitleaks release asset names
uname_s="$(uname -s | tr '[:upper:]' '[:lower:]')"  # linux/darwin
uname_m="$(uname -m)"
case "$uname_m" in
  x86_64|amd64) arch="x64" ;;
  arm64|aarch64) arch="arm64" ;;
  *) die "Unsupported arch: $uname_m" ;;
esac
case "$uname_s" in
  linux|darwin) os="$uname_s" ;;
  *) die "Unsupported OS: $uname_s" ;;
esac

# 2) Resolve version: latest via API, or override with GITLEAKS_VERSION=vX.Y.Z
if [ -n "${GITLEAKS_VERSION:-}" ]; then
  ver="${GITLEAKS_VERSION#v}"
else
  # Parse the latest "vX.Y.Z" tag without GNU-specific tools
  ver="$(curl -fsSL https://api.github.com/repos/gitleaks/gitleaks/releases/latest \
        | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"v\([0-9.][0-9.]*\)".*/\1/p')"
fi
[ -n "$ver" ] || die "Cannot determine latest Gitleaks version (API rate limit?). Set GITLEAKS_VERSION=vX.Y.Z."

asset="gitleaks_${ver}_${os}_${arch}.tar.gz"
url="https://github.com/gitleaks/gitleaks/releases/download/v${ver}/${asset}"

echo "[INFO] Downloading $asset ..."
tmpdir="$(mktemp -d)"; trap 'rm -rf "$tmpdir"' EXIT
curl -fL "$url" -o "$tmpdir/gitleaks.tgz" || die "Download failed: $url"

echo "[INFO] Installing gitleaks into $BIN_DIR ..."
tar -xzf "$tmpdir/gitleaks.tgz" -C "$tmpdir"
install -m 0755 "$tmpdir/gitleaks" "$BIN_DIR/gitleaks"

# 3) Write an idempotent pre-commit hook that runs gitleaks on staged changes
cat > "$HOOK_FILE" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail

# Opt-out via git config (default: true)
ENABLED="$(git config --bool gitleaks.precommit.enable 2>/dev/null || echo true)"
[[ "$ENABLED" == "false" ]] && exit 0

# Use repo-scoped gitleaks binary
export PATH="$PWD/.git/hooks/bin:$PATH"

# Protect staged changes; redact findings; fail on leaks
ARGS=(protect --staged --redact --exit-code 1)
[ -f ".gitleaks.toml" ] && ARGS+=(--config ".gitleaks.toml")

exec gitleaks "${ARGS[@]}"
HOOK
chmod +x "$HOOK_FILE"

# 4) Drop a minimal config with a Telegram Bot Token rule, if none exists yet
if [ ! -f ".gitleaks.toml" ]; then
  cat > .gitleaks.toml <<'TOML'
title = "Local rules"

[[rules]]
id = "telegram-bot-token"
description = "Telegram Bot Token"
# Example token shape: 1234567890:AAAAAAAAAAAAAAAAAAAAAAAAAAA111
regex = '''(?i)(\b\d{9,10}:[A-Za-z0-9_-]{35}\b)'''
tags = ["token","telegram","secret"]
entropy = 0.0
TOML
  echo "[INFO] Wrote default .gitleaks.toml (includes Telegram rule)"
fi

# 5) Enable the hook by default
git config --local gitleaks.precommit.enable true || true

echo "[OK] gitleaks -> $BIN_DIR/gitleaks"
echo "[OK] pre-commit hook -> $HOOK_FILE"
echo
echo "Try (no token printed to console/history):"
echo "  bash -c 'TOKEN=\$(LC_ALL=C tr -dc \"A-Za-z0-9_-\" </dev/urandom | head -c 35); \\"
echo "  git add demo.env && git commit -m \"test: demo token\"  # commit should fail"
