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
baseline = "F"
configs = ["F", "FM", "FA", "FAM", "I", "IM"] 
pretty_configs = ["F", "F+M", "FA", "FA+M", "I", "I+M"] 
workloads = ["Memcached", "XSBench", "Graph500", "Canneal"]

ndataseries = len(configs)
barwidth = 0.7

#
# Matplotlib Setup
#

matplotlib.rcParams['figure.figsize'] = 8,2
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
    for row in csvreader :
        if len(row) == 0 or row[0] == "" :
            continue
        
        workload = row[0]
        config = row[1]
        if workload in workloads and config in configs :
            data[workload][config] = int(row[2])


###############################################################################
# Plot the Graph
###############################################################################

totalbars = (len(workloads) * len(configs)) + len(workloads);

fig, ax = plt.subplots()

datalabels = []

ymin = 0
ymax = 1
colorsmap = cm.get_cmap(COLOR_MAP, 7);
def get_color_hatch(config):
	if "M" in config:
		return colorsmap(3), '---'
	else:
		return colorsmap(2), ''

idx = 0

def get_speedup(w, c):
	baseline = 1
	if c == "FM":
		baseline = int(data[w]["F"])
	elif c == "FAM":
		baseline = int(data[w]["FA"])
	elif c == "IM":
		baseline = int(data[w]["I"])
	else:
		pass

	runtime = int(data[w][c])
	return round(baseline/runtime, 2)

for w in workloads :
    idx = idx + 1
    datalabels.append("")
    midpoint = float(idx + (idx + len(configs) - 1)) / 2.0
    base_runtime = data[w][baseline]
    if base_runtime == 1:
        label_text = w + "\n(XXX)"
    else:
        label_text = w + "\n(" + str(base_runtime) + "s)"
    ax.text(midpoint / totalbars, -0.55, label_text, 
            horizontalalignment='center', fontsize=12,
            transform=ax.transAxes)

    for c in configs:
        time = int(data[w][c])
        base = int(data[w][baseline])
        base = max(1, base)
        if time == 1 or base == 1:
            val = 0
        else:
            val = (float(time)/float(base))
        tcn = val
        ymax = max(ymax, tcn)
        col, hs = get_color_hatch(c)
        r = ax.bar(idx, val, barwidth, color=col, edgecolor='k', hatch=hs)
        if "M" in c and val != 0:
            label_text = str(get_speedup(w,c)) + "x"
            ax.text(idx-0.35, val + 0.4, label_text, rotation=90, fontsize=12)
        datalabels.append(pretty_configs[configs.index(c)])
        idx = idx + 1

# add the last data label
datalabels.append("")

ax.set_ylabel('Normalized Runtime', fontsize=12)
ax.set_ylim([ymin, ymax * 1.10])

ax.set_yticks([0, 0.2, 0.4, 0.6, 0.8, 1, 1.2, 1.4])
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
