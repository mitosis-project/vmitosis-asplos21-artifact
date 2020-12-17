#!/usr/bin/python3
#
# Copyright (C) 2018-2019 VMware, Inc.
# SPDX-License-Identifier: GPL-2.0
#

import os
import sys
import threading
import subprocess
import multiprocessing

# --- this is crucial since we decide whether or not 2 CPUS belong to the same socket
NUMA_THRESHOLD = 100
# --- number of pages per socket
gPT_cache = 1000

metric = []
vnuma_groups = []
root = os.path.dirname(os.path.realpath(__file__))
n = multiprocessing.cpu_count()

class executeProcess(threading.Thread):
    def __init__(self, src, dst):
        self.stdout = None
        self.stderr = None
        self.src = src
        self.dst = dst
        threading.Thread.__init__(self)

    def run(self):
        exe = os.path.join(root, "mini-probe")
        cmd = "%s -s %d -d %d" %(exe, self.src, self.dst)
        p = subprocess.Popen(cmd.split(), shell=False,
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE)

        self.stdout, self.stderr = p.communicate()

def run_pairs(src, dst):
    pairs =  []
    for i in range(len(src)):
        s = src[i]
        d = dst[i]
        obj = executeProcess(s, d)
        obj.start()
        pairs.append(obj)

    for obj in pairs:
        entry = []
        obj.join()
        output = str(obj.stdout[:-1])
        pair = output[output.index("[") + 1 : output.index("]")].split()
        latency = output[output.index("{") + 1 : output.index("}")]
        entry.append(pair[0])
        entry.append(pair[1])
        entry.append(latency)
        #print ("Pair: %s %s Latency: %s" %(pair[0], pair[1], latency))
        metric.append(entry)

def do_measurements():
    pairs = [[0 for i in range(n)]for j in range(n)]
    for i in range(n):
        pairs[i][i] = 1

    while True:
        complete = True
        curr = [0 for i in range(n)]
        src = []
        dst = []
        for i in range(n):
            for j in range(n):
                if pairs[i][j] == 0 and curr[i] == 0 and curr[j] == 0:
                    pairs[i][j] = 1
                    pairs[j][i] = 1
                    curr[i] = 1
                    curr[j] = 1
                    src.append(i)
                    dst.append(j)

        if len(src) > 0:
            run_pairs(src, dst)

        for i in range(n):
            for j in range(n):
                if pairs[i][j] == 0:
                    complete = False

        if complete == True:
            break

    #print(pairs)

def is_similar(src, dst):
    for i in src:
        if i not in dst:
            return False

    for i in dst:
        if i not in src:
            return False

    return True

# --- add low latency pairs to same groups and remove
# redundant groups at the end
def construct_numa_groups(verbose):
    global vnuma_groups
    for entry in metric:
        src = int(entry[0])
        dst = int(entry[1])
        latency = int(entry[2])
        if latency < NUMA_THRESHOLD:
            if len(vnuma_groups) == 0:
                    group = []
                    group.append(src)
                    group.append(dst)
                    vnuma_groups.append(group)
                    continue

            else:
                found = False
                for i in range(len(vnuma_groups)):
                    if src in vnuma_groups[i] or dst in vnuma_groups[i]:
                        found = True
                        if dst not in vnuma_groups[i]:
                            vnuma_groups[i].append(dst)
                        if src not in vnuma_groups[i]:
                            vnuma_groups[i].append(src)
                if not found:
                    group = []
                    group.append(src)
                    group.append(dst)
                    vnuma_groups.append(group)

    # --- remove duplicates
    vnuma_groups = list(set(tuple(sorted(sub)) for sub in vnuma_groups))
    if not verbose:
        return

    id = 0
    for group in vnuma_groups:
        print("NUMA-group-%d: %s" %(id, str(group)))
        id = id + 1

# --- the sequence is important
# 1. configure CPU's NUMA affinity
# 2. reserve pgtable cache
# 3. warmup the cache
def reserve_os_pgtable_cache(verbose):
    global vnuma_groups, gPT_cache

    if len(vnuma_groups) == 0:
        return

    for i in range(len(vnuma_groups)):
        for cpu in vnuma_groups[i]:
            val = 1 << 24
            val = val | (i << 12)
            val = val | cpu
            cmd = "echo %d | sudo tee /proc/sys/kernel/pgtable_replication_misc > /dev/null" %(val)
            os.system(cmd)
            
    os.system("echo 2 | sudo tee /proc/sys/kernel/pgtable_replication_mode > /dev/null");
    cmd = "echo %d | sudo tee /proc/sys/kernel/pgtable_replication_cache > /dev/null" %(gPT_cache)
    # --- select 1 cpu from each group, get scheduled on that socket and then reserve
    for i in range(len(vnuma_groups)):
        for j in range(n):
            if j in vnuma_groups[i]:
                mask = {j}
                os.sched_setaffinity(0, mask)
                os.system(cmd)
                cmd2 = "echo %d | sudo tee /proc/sys/kernel/pgtable_replication_misc > /dev/null" %(i)
                os.system(cmd2)
                # --- go to the next group
                break

    # --- query the location to verify the placement of gPT replicas
    cmd2 = "echo %d | sudo tee /proc/sys/kernel/pgtable_replication_misc > /dev/null" %(len(vnuma_groups))
    os.system(cmd2)

if __name__ == "__main__":
    verbose = False
    do_measurements()
    if len(sys.argv) > 1:
        gPT_cache = int(sys.argv[1])

    if len(sys.argv) == 3 and sys.argv[2] == "--verbose":
        verbose = True
        for entry in metric:
            print (entry)

    construct_numa_groups(verbose)
    reserve_os_pgtable_cache(verbose)
