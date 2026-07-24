#!/usr/bin/env bash
# federate.sh - run the pipeline and PUBLISH it so a federation can mirror + verify you. It commits the
# files FIRST (so each foton can carry a commit-pinned git permalink), authors the fotons, commits the
# registry, and pushes. Then open a "Register a participant" issue on the federation with your repo.
# For a purely local run (no git/GitHub), use ./scripts/run-local.sh instead.
#
#   ./scripts/federate.sh [id]       (id defaults to your repo name)
set -euo pipefail
cd "$(dirname "$0")/.."
REMOTE=$(git config --get remote.origin.url 2>/dev/null || true)
REPO=$(printf '%s' "$REMOTE" | sed -E 's#(git@github.com:|https://github.com/)##; s#\.git$##')
if [ -z "$REPO" ]; then echo "no git 'origin' remote - fork/push this repo first, or use run-local.sh"; exit 1; fi
export PLANKTON_DIR="$PWD/registry/plankton" NEKTON_DIR="$PWD/registry/nekton"
export NEKTON_TEMPLATES="$PWD/templates" PATH="$PWD/bin:$PATH"
ID="${1:-$(basename "$REPO")}"; S="session-$ID"
mkdir -p registry/plankton registry/nekton registry/keys keys "$S"

[ -f "keys/$ID.key" ]        || plankton keygen "keys/$ID"        >/dev/null
[ -f "keys/$ID-claims.key" ] || nekton   keygen "keys/$ID-claims" >/dev/null
cp keys/$ID*.pub registry/keys/

cp pipeline/*.py "$S/"
python3 "$S/clean.py"       "$S/clean.csv"
python3 "$S/standardise.py" "$S/clean.csv"        "$S/standardized.csv"
python3 "$S/cluster.py"     "$S/standardized.csv" "$S/clustered.csv"
python3 "$S/summarise.py"   "$S/clustered.csv"    "$S/summary.json"

# 1) COMMIT THE FILES FIRST - a commit-pinned permalink needs the sha
git add data "$S"
git commit -m "pipeline files ($ID)" >/dev/null
git push
SHA=$(git rev-parse HEAD)
B="https://raw.githubusercontent.com/$REPO/$SHA"
L(){ printf -- '--located %s=%s/%s ' "$1" "$B" "$1"; }
au(){ plankton author "$@" --sign "keys/$ID.key" --add --print-id; }

# 2) author each foton with commit-pinned git permalinks so peers can fetch + re-hash your bytes
au --in data/penguins.csv    $(L data/penguins.csv)    --in "$S/clean.py"       $(L "$S/clean.py")       --out "$S/clean.csv"        $(L "$S/clean.csv")        --cmd "python $S/clean.py"       >/dev/null
au --in "$S/clean.csv"       $(L "$S/clean.csv")       --in "$S/standardise.py" $(L "$S/standardise.py") --out "$S/standardized.csv" $(L "$S/standardized.csv") --cmd "python $S/standardise.py" >/dev/null
au --in "$S/standardized.csv" $(L "$S/standardized.csv") --in "$S/cluster.py"   $(L "$S/cluster.py")     --out "$S/clustered.csv"    $(L "$S/clustered.csv")    --cmd "python $S/cluster.py"     >/dev/null
au --in "$S/clustered.csv"   $(L "$S/clustered.csv")   --in "$S/summarise.py"   $(L "$S/summarise.py")   --out "$S/summary.json"     $(L "$S/summary.json")     --cmd "python $S/summarise.py"   >/dev/null

# 3) commit the registry (the signed records) + push - that is "publishing"
git add registry
git commit -m "fotons ($ID)" >/dev/null
git push

echo ""
echo "published. Your signed registry is live at https://raw.githubusercontent.com/$REPO/main/registry/"
echo "Now register with a federation: open its 'Register a participant' issue with repo = $REPO"
echo "(check your pubkeys are committed:  git ls-files registry/keys)"
