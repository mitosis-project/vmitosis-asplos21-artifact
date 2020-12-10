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

ROOT=os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
SRC=sys.argv[1]
OUT=sys.argv[2]
if not os.path.exists(SRC):
    sys.exit(1)

#COLOR_MAP='PRGn'
COLOR_MAP='Dark2'

# the data labels we are interested in...
baseline = "TFLL"
configs = ["TFLL", "TFRRI", "TFRRIE", "TFRRIG", "TFRRIM"]
pretty_configs = ["TFLL", "TFRRI", "TFRRI+e", "TFRRI+g", "TFRRI+M"]
workloads = ["GUPS", "BTree", "Redis", "XSBench", "Memcached", "Canneal"]

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
for w in workloads :
    data[w] = dict()
    for c in configs :
        data[w][c] = 1

with open(SRC, 'r') as datafile :
    csvreader = csv.reader(datafile, delimiter='\t', quotechar='|')
    for row in csvreader :
        if len(row) == 0 or row[0] == "" :
            continue
        
        workload = row[0]
        config = row[1]
        if workload in workloads and config in configs :
            data[workload][config] = float(row[2])#(float(row[2]), float(row[3]), float(row[4]), float(row[5]), float(row[6]))


###############################################################################
# Plot the Graph
###############################################################################

totalbars = (len(workloads) * len(configs)) + len(workloads);

fig, ax = plt.subplots()

datalabels = []

ymin = 0
ymax = 1

colorsmap = cm.get_cmap(COLOR_MAP, 7);
colors = [colorsmap(2), colorsmap(1), colorsmap(3), colorsmap(3), colorsmap(3)]
hs = ['', 'xxxx', '////', '\\\\\\\\', '---']
def get_color_hatch(config):
	idx = configs.index(config)
	return colors[idx], hs[idx]

idx = 0
for w in workloads :
    idx = idx + 1
    datalabels.append("")
    midpoint = float(idx + (idx + len(configs) - 1)) / 2.0
    base_runtime = "(XXX)"
    if data[w][baseline] != 1:
        base_runtime = "(" + str(int(data[w][baseline])) + "s)"
    max_runtime = data[w]["TFRRI"]
    ax.text(midpoint / totalbars, -0.55, w + "\n" + base_runtime,
        horizontalalignment='center', fontsize=12,
        transform=ax.transAxes)

    for c in configs :
        time = data[w][c]
        base = data[w][baseline]
        if time == 1 or base == 1:
            val = 0
        else:
            val = time/base
        tcn = val
        ymax = max(ymax, tcn)
        c_color, c_hs = get_color_hatch(c)
        r = ax.bar(idx, val, barwidth, color=c_color, edgecolor='k', hatch=c_hs)
        if c == "TFRRIM" and val != 0:
            label_text = str(round(max_runtime/time, 2))+"x"
            ax.text(idx-0.40, val + 0.9, label_text, rotation=90, fontsize=12)

        datalabels.append(pretty_configs[configs.index(c)])
        idx = idx + 1

# add the last data label
datalabels.append("")

ax.set_ylabel('Normalized Runtime', fontsize=12)
#ax.yaxis.set_label_coords(-0.062,0.4)
ax.set_ylim([ymin, ymax * 1.10])
ax.set_yticks([0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5])
#ax.set_yticklabels(["0%", "25%", "50%", "75%", "100%"])
ax.set_xlim([0, idx])
ax.set_xticks(numpy.arange(idx)+0.05)
ax.set_xticklabels(datalabels, rotation=90, fontsize=8,
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
