#!/usr/bin/env bash
set -euo pipefail

# Find latest .xcresult bundle produced by swift test
RESULT_BUNDLE=$(ls -t .build/*.xcresult 2>/dev/null | head -n1 || true)
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

# Fallback to llvm-cov using profdata
PROF=$(ls -t .build/debug/codecov/*.profdata 2>/dev/null | head -n1 || true)
if [[ -z "${PROF}" ]]; then
  echo "No coverage artifacts found. Ensure 'swift test --enable-code-coverage' was run."
  exit 0
fi

TEST_BIN=$(find .build -type f -path "*/EntityKitPackageTests.xctest/Contents/MacOS/*" | head -n1 || true)
if [[ -z "${TEST_BIN}" ]]; then
  # Try a generic test binary
  TEST_BIN=$(find .build -type f -name "*Tests" | head -n1 || true)
fi

if [[ -z "${TEST_BIN}" ]]; then
  echo "Could not locate test binary for llvm-cov report"
  exit 0
fi

if ! command -v xcrun >/dev/null; then
  echo "xcrun not found; skipping coverage summary"
  exit 0
fi

echo "Swift coverage (llvm-cov)"
xcrun llvm-cov report "${TEST_BIN}" -instr-profile "${PROF}" || true
