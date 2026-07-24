import csv, sys, json, numpy as np
rows = list(csv.reader(open(sys.argv[1], newline='')))
head = rows[0]; ci = head.index('cluster'); num = head[:ci]
data = {}
for r in rows[1:]:
    k = int(r[ci]); data.setdefault(k, []).append([float(x) for x in r[:ci]])
out = {'n_rows': len(rows) - 1, 'n_clusters': len(data), 'features': num, 'clusters': []}
for k in sorted(data):
    arr = np.array(data[k])
    out['clusters'].append({'label': k, 'size': len(arr),
                            'mean': [round(float(m), 6) for m in arr.mean(0)]})
json.dump(out, open(sys.argv[2], 'w'), sort_keys=True, separators=(',', ':'))
open(sys.argv[2], 'a').write('\n')
