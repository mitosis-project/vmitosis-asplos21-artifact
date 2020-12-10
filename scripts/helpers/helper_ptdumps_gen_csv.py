#!/usr/bin/python3
import sys
import os
import csv

# --- directories that contain the data
configs = ["visible", "oblivious"]
workloads = ["memcached", "xsbench", "graph500", "canneal"]
pretty_workloads = ["Memcached", "XSBench", "Graph500", "Canneal"]

def process_dump(workload, dump, out_fd):
    in_fd = open(dump, 'r')
    nr_sockets = 4
    nr_configs = 4 # -- LL, LR, RL, RR
    arr = [[0 for i in range(nr_configs)] for j in range(nr_sockets)]
    count = [0 for i in range(nr_sockets)]
    for line in in_fd:
        if not line.startswith("Socket"):
            continue
        sock = int(line[6:7])
        count[sock] += 1
        line = line[line.index("(") + 1 : line.index(")")].split()
        idx = 0
        for elem in line:
            arr[sock][idx] += int(elem)
            idx += 1
    in_fd.close()
    # -- AVERAGE OVER ALL CONFIGS
    writer = csv.writer(out_fd, delimiter='\t', quoting=csv.QUOTE_MINIMAL)
    for i in range(nr_sockets):
        for j in range(nr_configs):
            if count[i] > 0:
                arr[i][j] /= count[i]
            else:
                arr[i][j] = 0
        total = 0
        for j in range(nr_configs):
            total += arr[i][j]

        # --- adjust sum to 100 for simplification
        arr[i][arr[i].index(max(arr[i]))] += 100-total
        row = [pretty_workloads[workloads.index(workload)]]
        row.append("Socket"+str(i))
        for j in range(nr_configs):
            # --- print as a function of total
            row.append(str(float(arr[i][j])/100))
        writer.writerow(row)

if __name__=="__main__":
    for target in ["reference", "measured"]:
        root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(__file__))))
        inputdir = os.path.join(root, ("evaluation/%s/processed/ptdumps/" %(target)))
        outfile=os.path.join(root, ("evaluation/%s/processed/figure-2a.csv" %(target)))
        for config in configs:
            if config == "oblivious":
                outfile = os.path.join(root, ("evaluation/%s/processed/figure-2b.csv" %(target)))

            fd = open(outfile, "w")
            for workload in workloads:
                path = os.path.join(inputdir, workload+"_numa_"+config+"_breakdown.dat")
                if os.path.exists(path):
                    process_dump(workload, path, fd)

    #print("Figure-2 csv file prepared.")
    fd.close()
