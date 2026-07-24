import csv, sys, numpy as np
NUM = ['bill_length_mm','bill_depth_mm','flipper_length_mm','body_mass_g']
rows = list(csv.reader(open(sys.argv[1], newline='')))
head = rows[0]; idx = [head.index(c) for c in NUM]
X = np.array([[float(r[i]) for i in idx] for r in rows[1:]])
Z = (X - X.mean(0)) / X.std(0, ddof=0)
w = csv.writer(open(sys.argv[2], 'w', newline=''), lineterminator='\n')
w.writerow(NUM)
for z in Z: w.writerow([f'{v:.6f}' for v in z])
