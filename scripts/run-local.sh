#!/usr/bin/env bash
# run-local.sh - run the whole pipeline LOCALLY. No git, no push, no federation, no GitHub account needed.
# It signs a foton per step (with local file:// locators) and builds a viewer union you can open offline.
# This is the "just try it" mode. To PUBLISH your run to a federation instead, use ./scripts/federate.sh.
#
#   ./scripts/run-local.sh [id]      (id defaults to "local"; use distinct ids to simulate several runs)
set -euo pipefail
cd "$(dirname "$0")/.."
export PLANKTON_DIR="$PWD/registry/plankton" NEKTON_DIR="$PWD/registry/nekton"
export NEKTON_TEMPLATES="$PWD/templates" PATH="$PWD/bin:$PATH"
ID="${1:-local}"; S="session-$ID"
mkdir -p registry/plankton registry/nekton registry/keys keys "$S"

# identity (reuse if it already exists - never re-keygen, it changes your keyid)
[ -f "keys/$ID.key" ]        || plankton keygen "keys/$ID"        >/dev/null
[ -f "keys/$ID-claims.key" ] || nekton   keygen "keys/$ID-claims" >/dev/null
cp keys/$ID*.pub registry/keys/

# run the deterministic reference pipeline (numpy only; see data/DATA.md)
cp pipeline/*.py "$S/"
python3 "$S/clean.py"       "$S/clean.csv"
python3 "$S/standardise.py" "$S/clean.csv"        "$S/standardized.csv"
python3 "$S/cluster.py"     "$S/standardized.csv" "$S/clustered.csv"
python3 "$S/summarise.py"   "$S/clustered.csv"    "$S/summary.json"

# author a foton per step with LOCAL file:// locators (--located-auto); every input incl. the script
au(){ plankton author "$@" --located-auto --sign "keys/$ID.key" --add --print-id; }
au --in data/penguins.csv    --in "$S/clean.py"       --out "$S/clean.csv"        --cmd "python $S/clean.py"       >/dev/null
au --in "$S/clean.csv"       --in "$S/standardise.py" --out "$S/standardized.csv" --cmd "python $S/standardise.py" >/dev/null
au --in "$S/standardized.csv" --in "$S/cluster.py"    --out "$S/clustered.csv"    --cmd "python $S/cluster.py"     >/dev/null
au --in "$S/clustered.csv"   --in "$S/summarise.py"   --out "$S/summary.json"     --cmd "python $S/summarise.py"   >/dev/null

# build a viewer union (+ keys) from the local registry, for offline viewing
python3 - <<'PY'
import json, glob, hashlib
recs=[json.load(open(f)) for f in sorted(glob.glob('registry/plankton/objects/sha256/*.json')
                                        +glob.glob('registry/nekton/objects/sha256/*.json'))]
json.dump(recs, open('viewer/data/union.json','w'), separators=(',',':'))
keys={}
for f in glob.glob('registry/keys/*.pub'):
    h=open(f).read().strip()
    try: keys[hashlib.sha256(bytes.fromhex(h)).hexdigest()[:16]]=h
    except Exception: pass
json.dump(keys, open('viewer/data/keys.json','w'), separators=(',',':'))
PY

echo ""
echo "done - $(ls registry/plankton/objects/sha256 | wc -l) fotons in registry/plankton, viewer union built."
echo "see it:  python3 -m http.server 8000   (from this directory), then open"
echo "  http://localhost:8000/viewer/viewer.html?union=data/union.json&keys=data/keys.json"
echo ""
echo "run it again with a different id to see reproduction accrue:  ./scripts/run-local.sh bob"
