import csv, sys, numpy as np
rows = list(csv.reader(open(sys.argv[1], newline='')))
head = rows[0]; X = np.array([[float(v) for v in r] for r in rows[1:]])
# deterministic k-means: fixed init (rows 0,111,222), 25 Lloyd iterations
C = X[[0, 111, 222]].copy()
for _ in range(25):
    d = ((X[:, None, :] - C[None, :, :]) ** 2).sum(2)
    lab = d.argmin(1)
    for k in range(3):
        if (lab == k).any(): C[k] = X[lab == k].mean(0)
# canonicalise labels by ascending centroid sum (permutation-invariant)
order = np.argsort(C.sum(1)); remap = {old: new for new, old in enumerate(order)}
lab = np.array([remap[l] for l in lab])
w = csv.writer(open(sys.argv[2], 'w', newline=''), lineterminator='\n')
w.writerow(head + ['cluster'])
for r, l in zip(rows[1:], lab): w.writerow(r + [str(int(l))])
