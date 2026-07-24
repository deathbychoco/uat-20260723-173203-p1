# data/

**Iteration 1 — `penguins.csv`** (Palmer Penguins; Horst, Hill & Gorman). A small, real tabular dataset:
344 rows, species/island/measurements/sex, with a few missing values (a natural cleaning step). Deterministic,
no heavy environment — ideal for testing whether three sessions can cooperate via kton.

**Python environment:** `numpy`, `scikit-learn`, and `scipy` are installed; **`pandas` is NOT**. Use the
stdlib `csv` module plus numpy. See the Determinism checklist in `../CLAUDE.md` for the byte-exactness rules
(LF line endings, fixed float format, `sort_keys`, canonical cluster labels) that make L0 reproduction work.

**Iteration 2 — single-cell (later).** Replace `penguins.csv` with `pbmc5k_filtered.h5` (10x Genomics 5k PBMC
filtered feature-barcode matrix) and install the pinned scanpy stack. The cooperation protocol in
`../CLAUDE.md` is identical; only the dataset and per-step scripts change.
