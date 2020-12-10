#!/usr/bin/python3
import os
import sys
import matplotlib
matplotlib.use('Agg')

from pprint import pprint
import csv
import numpy
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
from matplotlib import cm

ROOT=os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(__file__))))
SRC=sys.argv[1]
OUT=sys.argv[2]
#SRC=os.path.join(ROOT, "avg.csv")
#OUT=os.path.join(ROOT,'fig_local_remote_configs.pdf')

if not os.path.exists(SRC):
    sys.exit(1)

#COLOR_MAP='PRGn'
COLOR_MAP='Dark2'
#COLOR_MAP='Greys'

# the data labels we are interested in...
baseline = "LL"
configs = ["LL", "LR", "RL", "RR", "LRI", "RLI", "RRI"]
workloads = ["GUPS", "BTree", "Redis", "XSBench", "Memcached", "Canneal"] #["XSBench", "Graph500", "Canneal"]

ndataseries = len(configs)
colorsmap = cm.get_cmap(COLOR_MAP, ndataseries)

# the width of the bar (should be < 1)
barwidth = 0.7

#
# Matplotlib Setup
#

matplotlib.rcParams['figure.figsize'] = 8.0, 2.0
plt.rc('legend',**{'fontsize':13, 'frameon': 'false'})
plt.rc('ytick', labelsize=12)


###############################################################################
# load the data
###############################################################################

data = dict()

for w in workloads:
    data[w] = dict()
    for c in configs:
        data[w][c] = 1

with open(SRC, 'r') as datafile :
    csvreader = csv.reader(datafile, delimiter='\t', quotechar='|')
    first = True
    for row in csvreader :
        #if first :
        #    first = False
        #    continue

        if len(row) == 0 or row[0] == "" :
            continue
        
        workload = row[0]
        config = row[1]
        if workload in workloads and config in configs :
            data[workload][config] = float(row[2])


###############################################################################
# Plot the Graph
###############################################################################

totalbars = (len(workloads) * len(configs)) + len(workloads);

fig, ax = plt.subplots()

datalabels = []

ymin = 0
ymax = 1

colorsmap = cm.get_cmap(COLOR_MAP, 9);
#colors = ['white', 'lightblue', 'lightblue', 'lightblue', colorsmap(2), colorsmap(2), colorsmap(2)]
#colors = [colorsmap(6), colorsmap(2), colorsmap(2), colorsmap(2), colorsmap(1), colorsmap(1), colorsmap(1)]
colors = [colorsmap(4), colorsmap(2), colorsmap(2), colorsmap(2), colorsmap(1), colorsmap(1), colorsmap(1)]
hs = ['', '////', '---', '\\\\\\\\', '||||', 'xxxx', '+++']

def get_color_hatch(config):
	idx = configs.index(config)
	return colors[idx], hs[idx]

idx = 0
for w in workloads :
	idx = idx + 1
	datalabels.append("")

	midpoint = float(idx + (idx + len(configs) - 1)) / 2.0

	ax.text(midpoint / totalbars, -0.40, w, 
		horizontalalignment='center', fontsize=12,
		transform=ax.transAxes)

	for c in configs:
                time = data[w][c]
                base = data[w][baseline]
                base = max(1, base)
                if base == 1 or time == 1:
                    val = 0
                else:
                    val = time / base
                ymax = max(ymax, val)
                col, h = get_color_hatch(c)
                r = ax.bar(idx, val, barwidth, color=col, edgecolor='k', hatch=h)

                datalabels.append(c)
                idx = idx + 1

# add the last data label
datalabels.append("")

ax.set_ylabel('Normalized Runtime', fontsize=12)
ax.yaxis.set_label_coords(-0.062,0.45)
ax.set_ylim([ymin, ymax * 1.10])

ax.set_yticks([0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5])
#ax.set_yticklabels(["0%", "25%", "50%", "75%", "100%"])
ax.set_xlim([0, idx])
ax.set_xticks(numpy.arange(idx)+0.05)
ax.set_xticklabels(datalabels, rotation=90, fontsize=10,
    horizontalalignment='center', linespacing=0)


ax.tick_params(axis=u'both', which=u'both',length=0)

ax.set_axisbelow(True)
ax.grid(which='major', axis='y', zorder=999999.0)
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)
ax.spines['left'].set_visible(False)
ax.get_xaxis().tick_bottom()
ax.get_yaxis().tick_left()

plt.savefig(OUT, bbox_inches='tight')
