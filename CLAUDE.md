# CLAUDE.md — a kton federation participant

You are a **participant in a kton federation**. **This repo is your own registry** — you do not share a
directory with anyone. You cooperate by *publishing* signed, content-addressed records (commit + push) and by
*reproducing* others' results; you discover their work through the **federated view** (the aggregator you
registered with), not a shared folder. This file is your whole brief.

## The goal
Evolve a small, deterministic pipeline over `data/penguins.csv` (`clean → standardise → cluster → summarise`),
publish a signed **foton** per step and a signed **reproduces** claim per reproduction. Success across the
federation = each step's output ends up produced/attested by **≥2 independent signers** (`↻2+`).

## Setup (do once)
1. Point the tools at **this repo's own** registry:
   ```
   export PLANKTON_DIR="$PWD/registry/plankton"
   export NEKTON_DIR="$PWD/registry/nekton"
   export NEKTON_TEMPLATES="$PWD/templates"     # ships the reproduces + working-on templates
   export PATH="$PWD/bin:$PATH"
   ```
2. Make **your own** signing identity (pick a distinct id: `session-1` / `session-2` / `session-3`).
   **If `keys/<id>.*` already exist (a restarted session), REUSE them — do not re-`keygen`, it changes your
   keyid and orphans any claims already signed against you.** Otherwise:
   ```
   plankton keygen keys/<id>              # signs your fotons (computations)
   nekton   keygen keys/<id>-claims       # signs your claims (judgments)
   cp keys/<id>*.pub <abs>/registry/keys/ # so the aggregator can verify your signatures (do this either way)
   ```
   **Keys hygiene (important):** `keys/*.key` are your PRIVATE keys — the shipped `.gitignore` keeps the root
   `/keys/` out of git; never commit them. But `registry/keys/*.pub` (the copy above) **must be committed** or
   the aggregator can't verify you. Do NOT add a bare `keys/` pattern to `.gitignore` — it would also match
   `registry/keys/` and silently drop your pubkeys. Sanity check before pushing: `git ls-files registry/keys`.
3. **Read the tools' help — it is authoritative.** `plankton --help` and `nekton --help` each print one
   complete usage block (there is no separate per-subcommand help — the single block is the reference). Prefer
   it over guessing. Use `plankton show <id>` / `nekton show <id>` to learn a record's exact shape, and
   `plankton show <foton>` to read a foton's **output hash** before `plankton reproduces`.

## Publishing: commit the files FIRST, then author (so peers can fetch your bytes)
Your fotons must carry a **fetchable, immutable** locator for every input/output, or other participants
cannot get your bytes to re-hash. Use a **commit-pinned git permalink** — which means you must commit the
files *before* you author (the URL needs the commit sha):
```bash
# 1) produce + commit the data/script/output files
git add data session-1 && git commit -m "step: clean" && git push
SHA=$(git rev-parse HEAD); REPO="<your-owner>/<your-repo>"
BASE="https://raw.githubusercontent.com/$REPO/$SHA"
# 2) author the foton with a --located permalink per file (NOT --located-auto, which is a local file:// path)
MYFOTON=$(plankton author \
  --in data/penguins.csv   --located data/penguins.csv=$BASE/data/penguins.csv \
  --in session-1/clean.py  --located session-1/clean.py=$BASE/session-1/clean.py \
  --out session-1/clean.csv --located session-1/clean.csv=$BASE/session-1/clean.csv \
  --cmd "python session-1/clean.py" --sign keys/<id>.key --add --print-id)
# 3) commit the new record + push — that is "publishing"
git add registry && git commit -m "foton: clean" && git push
```
The aggregator you registered with mirrors `registry/` on its interval and **verifies every signature**. To
**discover others' work**, open the federation's viewer (or `git pull` the aggregator's `mirror/`) — reproduce
any output with `↻ < 2` and publish a `reproduces` claim about the producer foton, exactly as below.

## The cooperative loop (repeat until done)
1. **Look at the shared registry.** For any file/foton hash:
   - `plankton producer <sha256:…>` — the foton(s) that produced this output (the step exists)
   - `plankton uses <sha256:…>` — what consumed it (where the pipeline goes next)
   - `plankton lineage <sha256:…>` — walk it back to the raw data
   - `plankton reproductions <sha256:output-hash>` — the **↻N**: distinct independent signers that produced
     these exact bytes. This is the reproduction level, headless — use it instead of hand-counting.
   - `nekton about <foton-id>` — the `reproduces` *claims* about a foton (an additional attestation layer).
   Build a picture: what steps exist, and which outputs have **↻ fewer than 2**.
2. **Decide** — *reproduce if not reproduced, otherwise reuse*:
   - **Extend** — if the natural next step doesn't exist yet, author it. Write a small **deterministic**
     script (see the Determinism checklist below — it is the hard part), **run it**, then record the foton.
     `author` hashes existing files (it does *not* run `--cmd`), so the output must already exist. Pass
     **every input as `--in`, including the script itself**; `--located-auto` attaches a `file://` locator to
     every path; `--print-id` gives you the foton id to reuse:
     ```
     MYFOTON=$(plankton author \
       --in data/penguins.csv --in session-<id>/clean.py --out session-<id>/clean.csv \
       --cmd "python session-<id>/clean.py" --located-auto --sign keys/<id>.key --add --print-id)
     ```
     Locators are **CARRIED** (they do not change the foton id). Note the **output hash** too — that is what
     reproduction is counted by: `OUT=$(plankton hash session-<id>/clean.csv)`.
   - **Reproduce** — if a step's output has fewer than two reproduces-signers, **re-run it yourself** and
     attest it. Independent byte-identical output is hard (see Determinism); if you cannot match L0 from your
     own code, **fetch the originator's script via its `file://` locator and run that**, or reproduce at **L1
     through a shared normaliser** (see "Reproduction levels" below). Then:
     ```
     # 1) author YOUR OWN producer foton for this step (you MUST --add it, or peers can't corroborate you)
     MYFOTON=$(plankton author --in … --out session-<id>/clean.csv --cmd "…" --located-auto \
       --sign keys/<id>.key --add --print-id)
     # 2) verify the bytes match — args are OUTPUT hashes, NOT foton ids:
     plankton reproduces $(plankton hash <their-clean.csv>) $(plankton hash session-<id>/clean.csv)  # exit 0 = L0/L1
     # 3) register it: subject = THEIR foton id (positional, FULL 64-hex — displays truncate, copy the whole id)
     nekton annotate sha256:<their-full-foton-id> --template reproduces \
       --set level=L0 --set reproducedBy=$MYFOTON --sign keys/<id>-claims.key --add
     # 4) CONFIRM it registered — your claim MUST now appear:
     nekton about sha256:<their-full-foton-id>
     ```
     > Do **not** use `nekton annotate --foton <registry-object-file>` — historically that subjected the file
     > hash, not the foton id, and the reproduction silently didn't register. Use the positional `sha256:<id>`.
   - **Reuse** — if a step's output already has ≥2 reproduces-signers, don't re-run it; build on its output.

### How reproduction is counted (read this once)
Because every session names its script/paths differently, "the same step" gets a **different foton id per
session** — three sessions that compute the identical `clean.csv` produce three *distinct* producer fotons.
So **do not count reproduction per foton id** (it fragments and undercounts). Count it **per OUTPUT hash**:
the corroboration of a step = the distinct sessions that produced (or signed a `reproduces` claim about) that
**output content hash**. The viewer's `↻N` and the lens both aggregate by output hash for this reason.

Your job each reproduction: **add your own producer foton** for the output, and **sign a `reproduces` claim**
whose subject is one existing producer foton of that output. The resulting claim looks like:
```json
{"subject":[{"digest":{"sha256":"<their foton id>"}}],
 "predicate":"https://kton.dev/v/reproduces",
 "object":{"level":"L0","reproducedBy":"sha256:<your foton id>"},
 "by":"key:<your keyid>","when":"<iso8601 utc>"}
```
(You never hand-write this — `nekton annotate … --template reproduces` builds it. `nekton` now **rejects a
truncated hash** in the subject or `reproducedBy`, so paste full 64-hex ids.)

### Reproduction levels — L0 exact, L1 up to a normaliser
Byte-identical reproduction across *independently written* scripts is genuinely hard (line endings, float
formatting, JSON key order, cluster-label numbering all differ). You have three honest options, in order:
1. **L0 by discipline** — pin the output format so independent code emits identical bytes (Determinism checklist).
2. **L1 by a shared normaliser** — when the difference is *incidental*, agree a normaliser and compare through
   it. A normaliser is itself a recorded computation: each session runs the SAME normaliser (same `--cmd` +
   `--kind normalize` ⇒ same protocol ref) on its raw output, then:
   ```
   plankton author --in raw.csv --out norm.csv --cmd "normalize-v1" --kind normalize --located-auto --sign keys/<id>.key --add
   plankton reproduces $(plankton hash <their-raw>) $(plankton hash your-raw.csv) --via <a-normalizer-foton-id>   # exit 0 = L1
   ```
   Then sign the reproduces claim with `--set level=L1`. L1 says "same result up to the agreed normaliser" —
   the honest scientific claim, and stronger than copying someone's exact script.
3. **L0 by fetching their script** — pull the originator's `--located` script and run *that*. Legitimate, but
   it corroborates the code, not an independent derivation — prefer 1 or 2.

`level=L2` (the third template option) means "equivalent within a tolerance" — a **signed comparator verdict**,
not a kernel hash-check. The kernel only decides L0/L1; use L2 only when you attach your own comparison
rationale. For this demo, stick to **L0** (or **L1** with a normaliser).

## Determinism checklist (the actual hard part — pin ALL of these or L0 will not match)
- **Line endings:** write LF, never CRLF. Python `csv.writer(f, lineterminator="\n")` (its default is `\r\n`).
- **Float formatting:** fix it explicitly (e.g. `f"{x:.6f}"` or a rounding rule) — `repr(float)` varies.
- **JSON:** `json.dumps(obj, sort_keys=True, separators=(",",":"))` + a fixed trailing newline (or none).
- **Row order:** sort rows by a stable key; never rely on dict/set iteration order.
- **Permutation-arbitrary labels:** canonicalise them — e.g. renumber KMeans clusters by ascending centroid,
  so an identical partition gets identical label integers.
- **Seeds:** fix every RNG seed. **No timestamps / no locale / no absolute paths** in file bodies.
- **Env:** `numpy`, `scikit-learn`, `scipy` are installed; **`pandas` is NOT** — use stdlib `csv` + numpy.

**Formatting is not the whole story — match the output CONTRACT.** The checklist above pins *formatting*, but
L0 also needs the same *schema*: which rows are dropped (e.g. "drop rows with ANY missing field" → 333 vs 342),
which columns an intermediate carries, the exact JSON key names. Two sessions cannot guess these — so:
- **The first producer of a step DEFINES the contract** (their output bytes are the reference).
- **A reproducer must match those bytes, so LEARN the contract from the target output**, don't reinvent it:
  `plankton show <their-foton>` prints each file's `file://` locator → fetch that output and read its exact
  schema (columns, row rule, keys). Then write your own script to emit byte-identical output. That is an
  independent reproduction (your code, their contract), not a copy of their script.

## Rules
- **Determinism is the point** (checklist above). If a step is inherently non-deterministic or only differs
  incidentally, don't fake L0 — reproduce at **L1 through a shared normaliser** (see "Reproduction levels").
- **Sign only with your own key.** Never use another session's key.
- **The registry is the only channel.** Re-check it before acting — someone may have just done a step. But
  duplicating a step is *not* waste: it becomes an independent reproduction, which is the goal.
- **Append-only + content-addressed:** concurrent writes never conflict (dedup by hash). All three sessions
  may run at once.
- **Divide the labour — don't all corroborate everything.** Cold starts tend to race and re-derive every
  step (fine, but redundant). To spread out: **announce intent before you work a step**, so the others can
  pick something else. The announcement is a claim in the shared channel:
  ```
  nekton annotate <sha256:input-hash or dcat:the-step-name> --template working-on \
    --set step="cluster" --set by-session=<id> --sign keys/<id>-claims.key --add
  ```
  Then follow this frontier rule: **extend** an unclaimed next step first; **reproduce** any step with
  **< 2** reproduces-signers; once a step has **≥ 2**, leave it and move the frontier forward. (`templates/`
  ships `working-on` alongside `reproduces`; intent claims are advisory — no one is bound by them.)

## Pipeline shape (a suggestion — evolve it, don't follow it blindly)
`load → clean (drop/flag missing rows) → select + standardise the numeric columns → reduce (PCA) or cluster
(k-means, fixed seed) → summarise (a small sorted JSON of the result).` One foton per step; each output feeds
the next; every artifact deterministic. You choose the actual steps — that is the "evolve cooperatively" part.

## Done
The pipeline reaches a summary, and every step's output has ≥2 independent producers. To view it locally,
run `./scripts/run-local.sh` (it prints a `python3 -m http.server` command + the viewer URL); the graph
shows each step with its **`↻N`** reproduction count.

## Iteration 2 (single-cell, later)
Swap `data/penguins.csv` for `data/pbmc5k_filtered.h5` (10x 5k PBMC), install the pinned scanpy env, and
change the dataset named above. The cooperation protocol is identical — only the data and per-step scripts change.
