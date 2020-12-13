#! /usr/bin/python3

import sys
import os
import re
import itertools
from pprint import pprint
import copy
import matplotlib
matplotlib.use('Agg')


import matplotlib.pyplot as plt
import numpy as np




data = dict()

data['meta'] = dict()
data['data'] = []


def nextline() :
    line = sys.stdin.readline()
    if (not line):
        print("Parse error: unexpected eof. delete ")
        sys.exit(1);
    
    return line.strip()


numanodes = []
maxnode = 0
CurrentTablesTmp = {}


def get_new_current_tables() :
    return {
        'PTablesLevel1' : {'addrs' : [[] for x in range(maxnode+1)],  'diff' : [(0,0) for x in range(maxnode+1)], 'ptrs' : [[0 for y in range(maxnode+1)] for x in range(maxnode+1)]},
        'PTablesLevel2' : {'addrs' : [[] for x in range(maxnode+1)],  'diff' : [(0,0) for x in range(maxnode+1)], 'ptrs' : [[0 for y in range(maxnode+1)] for x in range(maxnode+1)]},
        'PTablesLevel3' : {'addrs' : [[] for x in range(maxnode+1)],  'diff' : [(0,0) for x in range(maxnode+1)], 'ptrs' :  [[0 for y in range(maxnode+1)] for x in range(maxnode+1)]},
        'PTablesLevel4' : {'addrs' : [[] for x in range(maxnode+1)],  'diff' : [(0,0) for x in range(maxnode+1)], 'ptrs' : [[0 for y in range(maxnode+1)] for x in range(maxnode+1)]},
        'Code2M' : {'addrs' : [[] for x in range(maxnode+1)],  'diff' : [(0,0) for x in range(maxnode+1)], 'ptrs' : [[0 for y in range(maxnode+1)] for x in range(maxnode+1)]},
        'Data2M' : {'addrs' : [[] for x in range(maxnode+1)],  'diff' : [(0,0) for x in range(maxnode+1)], 'ptrs' : [[0 for y in range(maxnode+1)] for x in range(maxnode+1)]},
        'Data4k' : {'addrs' : [[] for x in range(maxnode+1)],  'diff' : [(0,0) for x in range(maxnode+1)], 'ptrs' : [[0 for y in range(maxnode+1)] for x in range(maxnode+1)]},
        'Code4k' : {'addrs' : [[] for x in range(maxnode+1)],  'diff' : [(0,0) for x in range(maxnode+1)], 'ptrs' : [[0 for y in range(maxnode+1)] for x in range(maxnode+1)]},
        'NUMACode2M' : {'addrs' : [[] for x in range(maxnode+1)],  'diff' : [(0,0) for x in range(maxnode+1)], 'ptrs' : [[0 for y in range(maxnode+1)] for x in range(maxnode+1)]},
        'NUMAData2M' : {'addrs' : [[] for x in range(maxnode+1)],  'diff' : [(0,0) for x in range(maxnode+1)], 'ptrs' : [[0 for y in range(maxnode+1)] for x in range(maxnode+1)]},
        'NUMAData4k' : {'addrs' : [[] for x in range(maxnode+1)],  'diff' : [(0,0) for x in range(maxnode+1)], 'ptrs' : [[0 for y in range(maxnode+1)] for x in range(maxnode+1)]},
        'NUMACode4k' : {'addrs' : [[] for x in range(maxnode+1)],  'diff' : [(0,0) for x in range(maxnode+1)], 'ptrs' : [[0 for y in range(maxnode+1)] for x in range(maxnode+1)]},        
        'migrations' : 0,
        'migrationsdiff' : 0,
        }

def get_numa_info(line):
    global CurrentTablesTmp
    global maxnode
    global numanodes
    line = nextline()
    maxnode = 0
    while not line.startswith("</numa") :
        if not line.startswith("#") and line != '':
            node,base,limit = line.split(' ')
            numanodes.append((int(node), int(base), int(limit)))
            maxnode = max(maxnode, int(node))
        line = nextline()



def numa_node_for_address(a) :
    global numanodes
    for node,base,limit in numanodes :
        if base <= a and a < limit :
            return node
#    for node,base,limit in numanodes :
#        print("Address: %x, Node: %d, Base:%x, Limit %x, Within: %d" % (a, node, base, limit, base <= a and base < limit ))
    return 0

datarows = {}

def parse_experiment(line, cols) :
    
    expdata = {
        "cycles" : 0,
        "dtlb_misses" : 0,
        "walk_duration" : 0,
        "llc_misses" : 0,
        "llc_accesses" : 0,
        "l1d_misses" :  0,
        "l1d_accesses" : 0,
        "label" : "",
        'data' : -1 , 
        'ptables': -1,
        'run' : -1,
        'autonuma' : -1 ,
        'interference' : -1
    }

    # @ numactl -m 0 -N 0 -- ./bench_gups_no_openmp -p 0 -r 0 -d 0 -m 1 -c -n 0
    cmd = nextline()
    line = nextline()

    config = line[0:-1].split(',')
    for i in range(len(config)) :
        expdata[cols[i]] = config[i]

    expdata["label"] = line[0:-1]

    line = nextline()
    while line.startswith("#") or line[0:-1] == "" :
        line = nextline()
    
    while not line.startswith("@</exp>") :
        cols = line[0:-1].split(',')
        key = cols[2]

        if key.startswith('task-clock') :
            # TODO something with the time in ms
            line = nextline()
            continue

        if key not in [ 'cycles', 
                        'dtlb_store_misses.walk_duration', 
                        'dtlb_load_misses.walk_duration',
                        'resource_stalls.any',
                        'resource_stalls.rob', 
                        'resource_stalls.rs',
                        'resource_stalls.sb'] :
            line = nextline()
            continue

        if cols[0] == '<not counted>' or cols[0] == '<not supported>' :
            val = 0
        else :
            val = int(cols[0])

        if key.endswith("walk_duration") :
            expdata["walk_duration"] += val
            datarows['walk_duration'] = []    
        elif key.endswith("walk_completed") :
            expdata["dtlb_misses"] += val
            datarows['dtlb_misses'] = []
        elif key.startswith('LLC-') :
            if key.endswith('misses') :
                expdata["llc_misses"] += val
                datarows['llc_misses'] = []
            else :
                expdata["llc_accesses"] += val
                datarows['llc_accesses'] = []
        elif key.startswith("L1-dcache") :
            if key.endswith('misses') :
                expdata["l1d_misses"] += val
                datarows['l1d_misses'] = []
            else :
                expdata["l1d_accesses"] += val
                datarows['l1d_accesses'] = []
        else :
            expdata[key] =  val
            datarows[key] = []
        
        line = nextline()
    pprint(expdata)
    return expdata;

def parse_meta(line) :
    meta = line[1:-2]
    line = nextline()
    if meta == 'columns' :
        data['meta'][meta] = line[0:-1].split(',')
    else :
        data['meta'][meta] = line[0:-1]

def parse(lbl, CurrentTables, Curr) :
    tablebases = [[] for x in range(maxnode+1)]
    for t in Curr :
        if not t == '' :
            pgsize = 4096
            if lbl.endswith("2M") :
                pgsize = 2*1024*1024
            base = int(t, 16) * pgsize
            node = numa_node_for_address(base)
            tablebases[node].append(int(t, 16) * pgsize)
    CurrentTables[lbl] = tablebases
    return CurrentTables
        
        

def dodiff(Prev, Curr) :
    j = 0

    Curr['migrationsdiff'] = Curr['migrations'] - Prev['migrations']

    for k in Prev :
        if k.startswith('migration'):
            continue
        for n in range(maxnode + 1) :
            CountDiffAdd = 0
            CountDiffSub = 0
            CountSame = 0
            j = 0
            Curr[k]['addrs'][n] = sorted(Curr[k]['addrs'][n])
            lenprev = len(Prev[k]['addrs'][n])

            for tb in Curr[k]['addrs'][n]:
                if j == lenprev :
                    CountDiffAdd += 1
                    continue
                if tb == Prev[k]['addrs'][n][j] :
                    j+= 1
                    CountSame += 1
                elif tb < Prev[k]['addrs'][n][j] :
                    CountDiffAdd += 1
                else :
                    while j < lenprev and tb > Prev[k]['addrs'][n][j]:
                        CountDiffSub += 1
                        j += 1
                    if j < lenprev and tb == Prev[k]['addrs'][n][j] :
                        CountSame += 1
                        j += 1
            while j < lenprev :
                CountDiffSub += 1
                j += 1

            Curr[k]['diff'][n] = (CountDiffAdd, CountDiffSub)
            
            #if CountDiffAdd + CountDiffSub > 10000:
            #    print("# Node %d %s Equal: %d  Changed: +%d/-%d  total: %d/%d" % (n, k, CountSame, CountDiffAdd, CountDiffSub, len(Prev[k]['addrs'][n]),  len(Curr[k]['addrs'][n]) ))            
            #    print(Prev[k]['addrs'][n][0:10])
            #    print(Curr[k]['addrs'][n][0:10])
            
    
    return Curr

prog = re.compile("<ptdump process=\"([0-9]+)\" count=\"([0-9]+)\">")



CurrentTables = get_new_current_tables()
PreviousTables = get_new_current_tables()

def human_readable(x) :
    if (x > 1000000000000) :
        return "%dT" % int(x / 1000000000000)
    if (x > 1000000000) :
        return "%dG" % int(x / 1000000000)
    elif (x > 1000000) :
        return "%dM" % int(x / 1000000)
    elif (x > 1000) :
        return "%dk" % int(x / 1000)
    else : 
        return "%d" % x  


def printstats(CurrentTables) :
    print("---------------------------------------------------")
    for T in CurrentTables :
        if T.startswith('migration') :
            continue
        print("%-13s " % T, end='')
        i = 0
        tot = 0
        for t in CurrentTables[T]['addrs'] :
            cadd,csub = CurrentTables[T]['diff'][i]
            
            cadd =human_readable(cadd) 
            csub =human_readable(csub) 
            diff = "(+%s,-%s)" % (cadd, csub)
            num = human_readable(len(t))

            print("   % 5s [" % (num), end='')   

            for p in CurrentTables[T]['ptrs'][i] :
                if T.startswith('PTables') :
                    print("% 5s" % human_readable(p), end='')   
                else :
                    print("% 5s" % '--', end='')   
                       
            print("] % 10s   |" % (diff), end='')   

            tot += len(t)
                            
            i += 1
        print("| % 5s " % (human_readable(tot)))
    print("%-13s %s    %s " % ("Total Migrations",human_readable(CurrentTables['migrationsdiff']), human_readable(CurrentTables['migrations'])))

def parse_stuff() :
    global PreviousTables
    global CurrentTables

    pat = re.compile("<level([0-9]+) b=\"([0-9a-f]+)\">")
    

    while True:
        line = nextline()

        if line.startswith("<numamigrations>") :
            CurrentTables['migrations'] = int(line[16:-17])
            continue


        if line.startswith("</ptdump>") :
            CurrentTables = dodiff(PreviousTables, CurrentTables)
            printstats(CurrentTables)
            PreviousTables = CurrentTables
            CurrentTables = get_new_current_tables()
            return
        result = pat.match(line)
        if not result:
            print("UNKNOWN TAG!", line)
            return
        

        level = int(result.group(1))
        base = int(result.group(2), 16) << 12

        numatable = numa_node_for_address(base)
        entries = line[0:-10].split(">") 
        if len(entries) == 1:
            entries = []
        else :
            entries = entries[1].split(' ') 

    #CurrentTablesTmp = {
    #    'PTableslevel1' : {'addrs' : [[] for x in range(maxnode+1)],  'diff' : '', 'local' : 0, 'remote' : 0},
    #    'PTableslevel2' : {'addrs' : [[] for x in range(maxnode+1)],  'diff' : '', 'local' : 0, 'remote' : 0},
    #    'PTableslevel3' : {'addrs' : [[] for x in range(maxnode+1)],  'diff' : '', 'local' : 0, 'remote' : 0},
    #    'PTableslevel4' : {'addrs' : [[] for x in range(maxnode+1)],  'diff' : '', 'local' : 0, 'remote' : 0},
    #    'Code2M' : {'addrs' : [[] for x in range(maxnode+1)],  'diff' : ''},
    #    'Data2M' : {'addrs' : [[] for x in range(maxnode+1)],  'diff' : ''},
    #    'Data4k' : {'addrs' : [[] for x in range(maxnode+1)],  'diff' : ''},
    #    'Code4k' : {'addrs' : [[] for x in range(maxnode+1)],  'diff' : ''},
    #    }

        numremote = 0
        numlocal = 0
        if level >= 3:
            for e in entries :
                e = int(e, 16) << 12
                enode = numa_node_for_address(e)
                if e != 0:
                    CurrentTables['PTablesLevel%d' % level]['ptrs'][numatable][enode] += 1
        elif level == 2 :
            for e in entries :
                if e[0] == 'n' :
                    prefix = 'NUMA'
                    e = e[1:]
                else :
                    prefix = ''
                if e[0] == 'x' :
                    e = int(e[1:], 16) << 21
                    CurrentTables[prefix + 'Code2M']['addrs'][numa_node_for_address(e)].append(e)
                elif e[0] == 'p' :
                    e = int(e[1:], 16) << 12
                else :
                    e = int(e, 16) << 21
                    CurrentTables[prefix + 'Data2M']['addrs'][numa_node_for_address(e)].append(e)
                enode = numa_node_for_address(e)
                if e != 0:
                    CurrentTables['PTablesLevel%d' % level]['ptrs'][numatable][enode] += 1
        elif level == 1 :
            for e in entries :
                if e[0] == 'n' :
                    prefix = 'NUMA'
                    e = e[1:]
                else :
                    prefix = ''                
                if e[0] == 'x' :
                    e = int(e[1:], 16) << 12
                    CurrentTables[prefix + 'Code4k']['addrs'][numa_node_for_address(e)].append(e)
                else :
                    e = int(e, 16) << 12
                    CurrentTables[prefix+'Data4k']['addrs'][numa_node_for_address(e)].append(e)
                enode = numa_node_for_address(e)
                if e != 0:
                    CurrentTables['PTablesLevel%d' % level]['ptrs'][numatable][enode] += 1
        else :
            print("UNKNOWN LEVEL!")

        CurrentTables['PTablesLevel%d' % level]['addrs'][numatable].append(base)


nr_processed = 0

while True:
    line = sys.stdin.readline()
    if not line:
        break
    if line.startswith("<numa") :
        get_numa_info(line)
        CurrentTables = get_new_current_tables()
        PreviousTables = get_new_current_tables()

    if line.startswith("<config>") :
        print(line)

    if line.startswith("<ptdump") :
        nr_processed += 1
        result = prog.match(line)
        if result:
            count = int(result.group(1))
            pid = int(result.group(2))
        parse_stuff()
        if nr_processed > 30:
            break
        

