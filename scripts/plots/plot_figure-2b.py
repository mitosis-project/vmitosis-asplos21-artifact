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

ROOT=os.path.dirname(os.path.realpath(__file__))
SRC=sys.argv[1]
OUT=sys.argv[2]
#SRC=os.path.join(ROOT, "ept-oblivious.csv")
#OUT=os.path.join(ROOT,'ptdump_ept_oblivious.pdf')
if not os.path.exists(SRC):
    sys.exit(1)

COLOR_MAP="Dark2"

# the data labels we are interested in...
configs = ["Socket0", "Socket1", "Socket2", "Socket3"]
pretty_configs = ["Node-0", "Node-1", "Node-2", "Node-3"]
workloads = ["Memcached", "XSBench", "Graph500", "Canneal"]

# this is the number of bars per workload
ndataseries = len(configs)
# get the color map per workload
barwidth = 0.6

#
# Matplotlib Setup
#

matplotlib.rcParams['figure.figsize'] = 8.0, 2.5
plt.rc('legend',**{'fontsize':13, 'frameon': 'false'})
#plt.rc('ylabels', fontsize=12)


###############################################################################
# load the data
###############################################################################

data = dict()
for w in workloads :
    data[w] = dict()
    for c in configs :
        data[w][c] = (0,0,0,0)

with open(SRC, 'r') as datafile :
    csvreader = csv.reader(datafile, delimiter='\t', quotechar='|')
    for row in csvreader :
        if len(row) == 0 or row[0] == "" :
            continue
        
        workload = row[0]
        config = row[1]
        if workload in workloads and config in configs :
            data[workload][config] = (float(row[2]), float(row[3]), float(row[4]), float(row[5]))

###############################################################################
# Plot the Graph
###############################################################################

totalbars = (len(workloads) * len(configs)) + len(workloads);

fig, ax = plt.subplots()

datalabels = []

ymin = 0
ymax = 1

colorsmap = cm.get_cmap(COLOR_MAP, 9)
hs = ['|||', '////', '\\\\\\\\', '---']

idx = 0
for w in workloads :
    idx = idx + 1
    datalabels.append("")
    
    midpoint = float(idx + (idx + len(configs) - 1)) / 2.0

    ax.text(midpoint / totalbars, -0.30, w, 
            horizontalalignment='center', fontsize=14, transform=ax.transAxes)

    for c in configs :
        (ll,lr,rl,rr) = data[w][c]
        ymax = 1

        r = ax.bar(idx, ll, barwidth, color=colorsmap(0), hatch=hs[0], edgecolor='k')
        r = ax.bar(idx, lr, barwidth, color=colorsmap(8), hatch=hs[1], edgecolor='k', bottom=ll)
        r = ax.bar(idx, rl, barwidth, color=colorsmap(2), hatch=hs[2], edgecolor='k', bottom=ll+lr)
        r = ax.bar(idx, rr, barwidth, color=colorsmap(1), hatch=hs[3], edgecolor='k', bottom=ll+lr+rl)

        #datalabels.append(pretty_configs[configs.index(c)])
        datalabels.append(c)
        idx = idx + 1

#plt.legend(('LL', 'LR', 'RL', 'RR'), fontsize=12, ncol=4, framealpha=0, fancybox=True)
plt.legend(('Local-Local', 'Local-Remote', 'Remote-Local', 'Remote-Remote'),
             fontsize=10.5, ncol=4, framealpha=0, fancybox=True, loc='upper center')

ax.yaxis.set_label_coords(-0.05, 0.4)
ax.set_ylabel('Distribution of leaf PTEs\nin 2D page-tables', fontsize=12)
ax.set_yticks([0, 0.2, 0.4, 0.6, 0.8, 1])
ax.set_ylim([0, 1.2])
ax.set_xlim([0, idx])
ax.set_xticks(numpy.arange(idx)+0.04)
ax.set_xticklabels(datalabels, rotation=25, fontsize=10, horizontalalignment='center',linespacing=0)
ax.tick_params(axis=u'both', which=u'both', length=0)
ax.set_axisbelow(True)
ax.grid(which='major', axis='y', zorder=999999.0)
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)
ax.spines['left'].set_visible(False)
ax.get_xaxis().tick_bottom()
ax.get_yaxis().tick_left()
plt.savefig(OUT, bbox_inches='tight')
