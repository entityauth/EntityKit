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

# Fallback to llvm-cov using profdata
# Prefer the path reported by SwiftPM itself only if it ends with .profdata (ignore JSON)
PROF=""
PROF_CANDIDATE=$(swift test --show-codecov-path 2>/dev/null || true)
if [[ -n "${PROF_CANDIDATE}" && -f "${PROF_CANDIDATE}" && "${PROF_CANDIDATE}" == *.profdata ]]; then
  PROF="${PROF_CANDIDATE}"
fi
if [[ -z "${PROF}" ]]; then
  # Prefer default.profdata when present
  if DEFAULT_PROF=$(find .build -type f -path "*/debug/codecov/default.profdata" -print 2>/dev/null | head -n1); then
    PROF="${DEFAULT_PROF}"
  fi
fi
if [[ -z "${PROF}" ]]; then
  # Otherwise pick the newest .profdata in codecov folder
  PROF=$(find .build -type f -name "*.profdata" -path "*/debug/codecov/*" -print 2>/dev/null | sort -r | head -n1 || true)
fi
if [[ -z "${PROF}" ]]; then
  echo "No coverage artifacts found. Ensure 'swift test --enable-code-coverage' was run."
  exit 0
fi

# Locate the test binary (avoid matching files nested under dSYM inside the bundle)
TEST_BIN=$(find .build -type f -regex ".*/EntityKitPackageTests\\.xctest/Contents/MacOS/[^/]+$" | head -n1 || true)
if [[ -z "${TEST_BIN}" ]]; then
  # Try a generic test binary
  TEST_BIN=$(find .build -type f -regex ".*/[^/]*Tests$" | head -n1 || true)
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
if REPORT_OUT=$(xcrun llvm-cov report "${TEST_BIN}" -instr-profile "${PROF}" 2>&1); then
  echo "${REPORT_OUT}"
else
  # Hide noisy llvm-cov errors on newer toolchains that emit unsupported formats
  if echo "${REPORT_OUT}" | grep -qiE "unsupported coverage format version|invalid instrumentation profile data|not recognized as a valid object file"; then
    echo "Coverage artifacts found, but llvm-cov cannot read them on this toolchain. Skipping summary."
  else
    echo "llvm-cov failed:\n${REPORT_OUT}"
  fi
fi
