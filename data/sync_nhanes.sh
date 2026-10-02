#!/bin/bash
# sync_nhanes.sh — download all public NHANES 2017-2018 XPT files (no login).
# Docs: https://wwwn.cdc.gov/nchs/nhanes/continuousnhanes/default.aspx?BeginYear=2017

set -euo pipefail

CYCLE="2017-2018"
BEGIN_YEAR="2017"
BASE_URL="https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/${BEGIN_YEAR}/DataFiles"
OUT_DIR="$(cd "$(dirname "$0")" && pwd)/raw/nhanes/${CYCLE}"
MANIFEST="${OUT_DIR}/_download_manifest.txt"

mkdir -p "${OUT_DIR}"
cd "${OUT_DIR}"

echo "=== NHANES ${CYCLE}: discovering public XPT files ==="

python3 - <<'PY' > "${MANIFEST}"
import re, sys, urllib.request

BEGIN_YEAR = "2017"
COMPONENTS = ("Demographics", "Dietary", "Examination", "Laboratory", "Questionnaire")
STEM_RE = re.compile(r"\b([A-Za-z0-9_]+_J)\.(?:xpt|XPT)\b", re.I)
HARD_WITHDRAWN = {"SSEVD_J"}
stems = set()

for component in COMPONENTS:
    url = (
        "https://wwwn.cdc.gov/nchs/nhanes/search/datapage.aspx"
        f"?Component={component}&CycleBeginYear={BEGIN_YEAR}"
    )
    html = urllib.request.urlopen(url, timeout=90).read().decode("utf-8", "replace")
    for match in STEM_RE.finditer(html):
        stem = match.group(1).upper()
        lo, hi = max(0, match.start() - 250), min(len(html), match.end() + 250)
        if stem in HARD_WITHDRAWN or re.search(r"Withdrawn", html[lo:hi], re.I):
            continue
        stems.add(stem)

for stem in sorted(stems):
    print(stem)
print(f"# discovered {len(stems)} files", file=sys.stderr)
PY

mapfile -t FILES < <(grep -E '^[A-Z0-9_]+_J$' "${MANIFEST}")
COUNT="${#FILES[@]}"
[[ "${COUNT}" -gt 0 ]] || { echo "ERROR: no files discovered" >&2; exit 1; }

echo "=== downloading ${COUNT} files into ${OUT_DIR} ==="
ok=0; skip=0; fail=0
failed_names=()

for stem in "${FILES[@]}"; do
  f="${stem}.xpt"
  if [[ -s "${f}" ]]; then
    echo "skip (exists): ${f}"
    skip=$((skip + 1))
    continue
  fi
  echo "-> ${f}"
  if curl -fL --retry 3 --retry-delay 2 -o "${f}.partial" "${BASE_URL}/${f}"; then
    mv "${f}.partial" "${f}"
    ok=$((ok + 1))
  else
    rm -f "${f}.partial"
    fail=$((fail + 1))
    failed_names+=("${f}")
  fi
done

echo "=== downloaded=${ok} skipped=${skip} failed=${fail} listed=${COUNT} ==="
[[ "${fail}" -eq 0 ]] || { printf 'failed: %s\n' "${failed_names[*]}" >&2; exit 1; }
