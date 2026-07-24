import csv, sys
# drop rows with ANY missing field; keep header; LF line endings; preserve column order
rows = list(csv.reader(open('data/penguins.csv', newline='')))
head, body = rows[0], rows[1:]
kept = [r for r in body if all(c.strip() != '' and c.strip().upper() != 'NA' for c in r)]
w = csv.writer(open(sys.argv[1], 'w', newline=''), lineterminator='\n')
w.writerow(head); w.writerows(kept)
