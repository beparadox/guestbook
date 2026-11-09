#!/usr/bin/env bash
# Scan for secrets with gitleaks (native binary if installed, else via Podman/Docker).
#   scripts/scan-secrets.sh            scan every file git WOULD commit (tracked + untracked, minus .gitignore)
#   scripts/scan-secrets.sh --staged   scan only staged changes (used by the pre-commit hook)
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
IMG=docker.io/zricethezav/gitleaks:v8.30.1@sha256:c00b6bd0aeb3071cbcb79009cb16a60dd9e0a7c60e2be9ab65d25e6bc8abbb7f  # keep in sync with .github/workflows/ci.yml
CFG="$PWD/.gitleaks.toml"

if [ "${1:-}" = "--staged" ]; then
  src="$PWD"; args=(protect --staged)
else
  # Copy exactly the committable file set to a temp dir so ignored build output isn't scanned.
  src="$(mktemp -d)"; trap 'rm -rf "$src"' EXIT
  git ls-files -z -co --exclude-standard | xargs -0 -r cp --parents -t "$src"
  cp "$CFG" "$src/.gitleaks.toml"
  args=(detect --no-git)
  echo "Scanning $(git ls-files -co --exclude-standard | wc -l) committable files..."
fi

if command -v gitleaks >/dev/null; then
  gitleaks "${args[@]}" --config "$src/.gitleaks.toml" --redact -v --source "$src"; exit $?
fi
for rt in podman docker; do
  if command -v "$rt" >/dev/null; then
    timeout 300 "$rt" run --rm -v "$src:/repo:Z" -w /repo "$IMG" \
      "${args[@]}" --config /repo/.gitleaks.toml --redact -v --source /repo; exit $?
  fi
done
echo "gitleaks not available (install it, or Podman/Docker)" >&2; exit 2
