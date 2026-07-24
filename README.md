# plankton participant

A template for **joining a kton federation**: you run a small, reproducible data pipeline, sign every
computation and every reproduction, publish the signed records, and register with an aggregator. You never
message anyone — you cooperate by publishing verifiable records that others reproduce.

Everything you need is in this repo, including the two CLIs (`bin/plankton`, `bin/nekton`).

## Two ways to run it
- **Local — no GitHub, no account.** `./scripts/run-local.sh` runs the reference pipeline, signs a foton per
  step (with local `file://` locators), and builds a viewer union you open **offline**. Run it again with a
  different id (`./scripts/run-local.sh bob`) to watch **↻N** reproduction accrue. Just trying it? Start here.
- **Federate — publish to a federation.** `./scripts/federate.sh` commits your files, authors fotons with
  **commit-pinned git permalinks**, and pushes — so an aggregator can mirror + verify you. Then register (step 4).
- **Cooperative science (open-ended).** Point a Claude session at `CLAUDE.md` and it writes its *own* scripts —
  evolving the pipeline and reproducing others. The two scripts above run a fixed reference pipeline
  (`pipeline/*.py`); `CLAUDE.md` is the mode where the pipeline is discovered cooperatively.

## 4 steps (the federate path, by hand)

### 1. Use this template
Click **Use this template → Create a new repository**. You now own a participant repo.

### 2. Run the cooperation loop
Point a Claude session (or several) at **`CLAUDE.md`** — it is the complete brief: set the env, make a
signing identity, then extend / reproduce / reuse steps of the pipeline over `data/penguins.csv`, recording a
signed **foton** per computation and a signed **reproduces** claim per reproduction.

```bash
export PLANKTON_DIR="$PWD/registry/plankton"
export NEKTON_DIR="$PWD/registry/nekton"
export NEKTON_TEMPLATES="$PWD/templates"
export PATH="$PWD/bin:$PATH"
```

The determinism checklist and the reproduce recipe in `CLAUDE.md` are what make independent results match
byte-for-byte (L0). Your signed records accumulate under `registry/`.

### 3. Publish (just commit + push — there is no build step)
Your committed `registry/` **is** the published record set. `CLAUDE.md` has you commit the data/scripts/outputs
first (so each foton can carry a commit-pinned permalink), then commit the fotons:
```bash
git add registry data <your-session-dir> && git commit -m "my run" && git push
```
That's it — the aggregator reads your `registry/` straight from GitHub.
> Keep `keys/*.key` **out** of git (the shipped `.gitignore` handles the root `/keys/`), but make sure
> `registry/keys/*.pub` **is** committed — the aggregator needs it to verify you. Check: `git ls-files registry/keys`.

### 4. Register with a federation
Open a **Register a participant** issue on the federation you want to join (an aggregator set up from
`plankton-federation-template`), giving your repo (`owner/repo`) and a mirror interval. Once a maintainer adds
the `approved` label, the aggregator mirrors and **verifies** your records on that interval, and your work
appears — with its `↻N` reproduction count — in the federated view alongside everyone else's.

## What you'll see
Even before you join, your own records form a provenance graph. After the federation mirrors several
participants, each output shows **↻N** — the number of independent signers who produced those exact bytes.
That number growing across independent repos, with every signature re-verified, *is* the federation working.

## Layout
```
CLAUDE.md            the cooperation brief (authoritative)
bin/                 plankton, nekton  (committed so you need no build)
data/                penguins.csv + DATA.md (the Python env: numpy/scikit-learn/scipy; no pandas)
templates/           nekton claim templates (reproduces, working-on)
pipeline/            the reference pipeline scripts (clean/standardise/cluster/summarise)
scripts/             run-local.sh (offline, no git) + federate.sh (git permalinks + push)
viewer/              the local viewer (used by run-local.sh to show your ↻N graph offline)
registry/            your signed stores: plankton/ (fotons), nekton/ (claims), keys/ (your published .pub)
session-1/           a workspace (add more if you run several sessions)
keys/                your PRIVATE signing keys — gitignored (never published)
```

Trust model: nothing here is trusted blindly. Every record is content-addressed and signed; a federation
**verifies** each signature on ingest. Publishing exposes records; it never grants authority.
