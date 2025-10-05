#!/usr/bin/env bash
set -euo pipefail

# Find latest .xcresult bundle produced by swift test (search recursively)
RESULT_BUNDLE=$(find .build -type d -name "*.xcresult" -print 2>/dev/null | xargs -I{} stat -f "%m %N" {} 2>/dev/null | sort -nr | awk '{ $1=""; sub(/^ /,""); print; exit }' || true)
if [[ -n "${RESULT_BUNDLE}" ]]; then
  if command -v xcrun >/dev/null; then
    SUMMARY=$(xcrun xccov view --report --json "${RESULT_BUNDLE}")
    if [[ -n "${SUMMARY}" ]]; then
      TOTAL=$(echo "${SUMMARY}" | /usr/bin/python3 - <<'PY'
import json,sys
r=json.load(sys.stdin)
print(f"total: {r.get('lineCoverage',0)*100:.1f}%")
PY
)
      echo "Swift coverage ${TOTAL} (xccov)"
      echo "Per-target:"
      echo "${SUMMARY}" | /usr/bin/python3 - <<'PY'
import json,sys
r=json.load(sys.stdin)
for t in r.get('targets', []):
  name=t.get('name')
  cov=t.get('lineCoverage',0)*100
  print(f"- {name}: {cov:.1f}%")
PY
      exit 0
    fi
  fi
fi

# Try SwiftPM-generated JSON coverage (newer toolchains)
JSON_COVERAGE=$(swift test --show-codecov-path 2>/dev/null || true)
if [[ -z "${JSON_COVERAGE}" || ! -f "${JSON_COVERAGE}" || "${JSON_COVERAGE}" != *.json ]]; then
  JSON_COVERAGE=$(find .build -type f -path "*/debug/codecov/*.json" -print 2>/dev/null | sort -r | head -n1 || true)
fi
if [[ -n "${JSON_COVERAGE}" && -f "${JSON_COVERAGE}" ]]; then
  TOTAL=$(JSON_FILE="${JSON_COVERAGE}" /usr/bin/python3 - <<'PY'
import json, os
try:
  with open(os.environ['JSON_FILE']) as f:
    j=json.load(f)
  # SwiftPM exports llvm.coverage.json.export with data[0].totals.lines.percent
  d=j.get('data',[])
  if d and 'totals' in d[0] and 'lines' in d[0]['totals']:
    pct=d[0]['totals']['lines'].get('percent')
    if pct is not None:
      print(f"total: {pct:.2f}%")
except Exception:
  pass
PY
  ) || true
  if [[ -n "${TOTAL}" ]]; then
    echo "Swift coverage ${TOTAL} (spm json)"
    echo "Per-target:"
    JSON_FILE="${JSON_COVERAGE}" /usr/bin/python3 - <<'PY'
import json, os
with open(os.environ['JSON_FILE']) as f:
  j=json.load(f)
base=os.getcwd()
data=j.get('data', [])
files=(data[0] if data else {}).get('files', [])
by_target={}
for f in files:
  path=f.get('filename','')
  if not path.startswith(base + '/Sources/'):
    continue
  rest=path[len(base + '/Sources/'):]
  if '/' not in rest:
    continue
  target=rest.split('/',1)[0]
  ls=f.get('summary',{}).get('lines',{})
  count=int(ls.get('count') or 0)
  covered=int(ls.get('covered') or 0)
  if count<=0:
    continue
  cov, tot = by_target.get(target, (0,0))
  by_target[target]=(cov+covered, tot+count)
for t in sorted(by_target.keys()):
  covered, count = by_target[t]
  pct = 0.0 if count==0 else (covered/count)*100.0
  print(f"- {t}: {pct:.2f}% ({covered}/{count})")
PY
    exit 0
  fi
fi

echo "No SwiftPM JSON coverage found and no .xcresult available for xccov; skipping summary."
