#!/usr/bin/env bash
# Proprietary-notice gate (OVH-142). Plain bash + git, no network, no Docker, well under a second.
# Fails when the standard set drifts: LICENSE must be the canonical text, NOTICE.md must exist,
# README.md must carry the confidentiality line, every first-party package.json must say
# "license": "UNLICENSED", and legal lines must spell the owner "Digital Disruptors L.L.C.".
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

LICENSE_SHA256="28cdea036b51d7d984ea919bc785c45cd91bcd14817c666f71b252099a32cad1"
CONF_LINE="Digital Disruptors L.L.C. · Confidential. Internal use only; do not distribute without written permission."
fail=0
err() { echo "proprietary-check: $*" >&2; fail=1; }

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

if [[ ! -f LICENSE ]]; then
  err "LICENSE is missing"
elif [[ "$(sha256 LICENSE)" != "$LICENSE_SHA256" ]]; then
  err "LICENSE differs from the canonical Digital Disruptors L.L.C. licence (sha256 $LICENSE_SHA256)"
fi

[[ -f NOTICE.md ]] || err "NOTICE.md is missing"

if [[ ! -f README.md ]] || ! grep -qF "$CONF_LINE" README.md; then
  err "README.md lacks the confidentiality line: $CONF_LINE"
fi

# First-party manifests: tracked package.json files outside vendored trees.
while IFS= read -r manifest; do
  [[ -z "$manifest" ]] && continue
  case "$manifest" in node_modules/*|*/node_modules/*|vendor/*|*/vendor/*|third_party/*|*/third_party/*) continue ;; esac
  grep -qE '"license"[[:space:]]*:[[:space:]]*"UNLICENSED"' "$manifest" || err "$manifest lacks \"license\": \"UNLICENSED\""
done < <(git ls-files -- 'package.json' '*/package.json')

# Legal lines (copyright, rights reserved, proprietary, confidentiality, licensing) must not
# misspell the owner. Data such as fixtures and tenant names carries no legal marker, so it is not matched.
legal='copyright|trademark|property of|©|&copy;|all rights reserved|proprietary|confidential|licensing inquiries'
bad='Digital Disruptors(,[[:space:]]*|[[:space:]]+)(LLC|L\.L\.C([^.]|$)|Inc\b|Ltd\b)|Digital Disruptors,[[:space:]]*L\.L\.C\.'
hits="$(git grep -nIiE "$legal" -- . ':!package-lock.json' ':!scripts/ci/proprietary-check.sh' | grep -E "$bad" || true)"
if [[ -n "$hits" ]]; then
  err "legal line(s) misspell the owner; use \"Digital Disruptors L.L.C.\":"
  echo "$hits" >&2
fi

if [[ $fail -ne 0 ]]; then exit 1; fi
echo "proprietary-check: ok"
