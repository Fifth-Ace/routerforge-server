#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
for f in manager.sh install.sh bootstrap.sh; do bash -n "$f"; done
for cmd in help version; do bash manager.sh "$cmd" >/dev/null; done
D=$(mktemp -d); trap 'rm -rf "$D"' EXIT
cat > "$D/test.csv" <<'CSV'
IP,ORIGIN,CERT_DOMAIN,CERT_ISSUER,GEO_CODE
203.0.113.1,x,example.com,Let's Encrypt,US
203.0.113.2,x,a.example,DigiCert Inc,US
203.0.113.2,x,a.example,DigiCert Inc,US
203.0.113.3,x,b.example,LETS ENCRYPT,US
203.0.113.4,x,c.example,Sectigo,US
CSV
bash manager.sh filter "$D/test.csv" "$D/filtered.csv" > "$D/summary"
[[ $(wc -l < "$D/filtered.csv") == 3 ]]
grep -q 'LETS_ENCRYPT_EXCLUDED: 2' "$D/summary"
grep -q 'RETAINED: 2' "$D/summary"
! grep -qi 'encrypt' "$D/filtered.csv"
# No side-effect for passive actions.
bash manager.sh help >/dev/null
printf 'BASH: PASS\nFILTER: PASS\nDEDUP: PASS\n'

# P3 offline smoke checks: read-only commands and installer source invariants.
grep -q 'self-update)' manager.sh
grep -q '/usr/local/bin/rfs' install.sh
grep -q 'codeload.github.com' bootstrap.sh
! grep -Eq 'systemctl[[:space:]]+(restart|stop)|ufw[[:space:]]+enable' install.sh bootstrap.sh
printf 'P3_BOOTSTRAP_STATIC: PASS\n'