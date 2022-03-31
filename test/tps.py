import csv

counter = {}

with open('out.csv') as csv_file:
    csv_reader = csv.reader(csv_file, delimiter=',')
    for row in csv_reader:
        k = int(float(row[1])/60)
        counter[k] = counter.get(k, 0) + 1

print(dict(sorted(counter.items())))