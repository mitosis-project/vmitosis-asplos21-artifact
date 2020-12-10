#!/usr/bin/python3

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import sys
import csv
import os

SRC = sys.argv[1]
OUT = sys.argv[2]

if not os.path.exists(SRC):
        sys.exit(1)

matplotlib.rcParams['figure.figsize'] = 8.0,4.5

data = []
legends = []

with open(SRC, 'r') as csvfile:
    plots = csv.reader(csvfile, delimiter='\t')
    header = True
    nr_configs = 0
    for row in plots:
        # --- remove whitespace
        row = list(filter(None, row))
        index = 0
        if header:
            nr_configs = len(row)
            for i in range(nr_configs):
                legends.append(row[i])
                config = []
                data.append(config)
            header = False
            continue

        if len(row) == nr_configs:
            for i in range(nr_configs):
                try:
                    data[index].append(int(row[i]) / 1000000)
                    index = index + 1
                except:
                    pass

for i in range(len(data)):
    plt.plot(data[i], label = legends[i])

plt.xlabel('Time')
plt.ylabel('Throughput (million)')
plt.title('Live virtual machine migration')
plt.legend(loc="lower right")
plt.savefig(OUT, bbox_inches='tight')
