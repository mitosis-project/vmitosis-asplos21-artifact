#!/usr/bin/python3

import sys
import os
import re
import itertools

nr_dumps_processed = 0
efd_pos = 0
gfd_pos = 0
eptmap = dict()
gptmap = dict()
output = None
efd = None
gfd = None

#----remove prefix, if present
# nx, np, x, p, n
# Note that order of checking is imp (check longest prefixes first)
def remove_prefix(entry):
    if entry.startswith("nx"):
        return entry[2:]
    if entry.startswith("np"):
        return entry[2:]
    if entry.startswith("n"):
        return entry[1:]
    if entry.startswith("x"):
        return entry[1:]
    if entry.startswith("p"):
        return entry[1:]
    # ---no prefix, return as is
    return entry

def prepare_ept_hashmap():
    global eptmap
    eptmap = dict()
    while True:
        line = efd.readline()
        if not line:
            print("Unexpected end of dump")
            sys.exit(1)
        elif line.startswith("</ptdump"):
            return
        elif not line.startswith("<level"):
            continue
        else:
            key_end = line.find(">")
            val_end = line.find("</level")
            key = line[1: key_end]
            val = line[key_end + 1 : val_end]
            values = val.split()
            if "level4" in key:
                key = "level4 b="
            eptmap[key] = values
            if len(values) != 512:
                print("Insufficient entries: %d" %len(values))
                print (line)
                sys.exit(1)

def prepare_gpt_hashmap(key_hint1, key_hint2):
    global gptmap
    gptmap = dict()
    while True:
        line = gfd.readline()
        if not line:
            print("Unexpected end of dump")
            sys.exit(1)
        elif line.startswith("</ptdump"):
            return
        elif not line.startswith("<level"):
            continue
        else:
            key_end = line.find(">")
            val_end = line.find("</level")
            key = line[1: key_end]
            val = line[key_end + 1 : val_end]
            values = val.split()
            if len(values) != 512:
                print("Insufficient entries: %d" %len(values))
                print (line)
                sys.exit(1)
            # --- remove zero entries as they aren't useful afterwards
            values[:] = (val for val in values if val != "0")
            if key_hint1 in key or key_hint2 in key:
                gptmap[key] = values

# --- prepapre hasmap from both page table dumps
def prepare_curr_dump(dump_idx):
    global efd_pos, gfd_pos
    # --- start from where we left off last time
    efd.seek(efd_pos)
    while True:
        line = efd.readline()
        if not line:
            #print("Unable to get to dump: %d" %dump_idx)
            sys.exit(1)
        if line.startswith("<ptdump"):
            prepare_ept_hashmap()
            # --- cache the current file pos for next iteration
            efd_pos = efd.tell()
            break
        else:
            continue

    gfd.seek(gfd_pos)
    while True:
        line = gfd.readline()
        if not line:
            #print("Unable to get to dump: %d" %dump_idx)
            sys.exit(1)
        if line.startswith("<ptdump"):
            prepare_gpt_hashmap("level2" , "level1")
            # --- cache the current file pos for next iteration
            gfd_pos = gfd.tell()
            break
        else:
            continue

def get_idx(entries, prefix, idx):
    if idx >= len(entries):
        print("Index out of range")
        print("Max entries: %d" %(len(entries)))
        print(entries)
        print("Queried Index: %d" %idx)
        sys.exit(1)
        return "0"
    return remove_prefix(entries[prefix][idx])

# --- extract 9 index bits for each pgtable level
def guest_pa_to_host_pa(guest_addr, dump_idx, skipLastLevel):
    l4_idx = (guest_addr >> 27) & 0x1ff
    l3_idx = (guest_addr >> 18) & 0x1ff
    l2_idx = (guest_addr >> 9) & 0x1ff
    l1_idx = guest_addr & 0x1ff

    prefix = "level4 b="
    if not prefix in eptmap:
        return "0"
    l4 = get_idx(eptmap, prefix, l4_idx)
    prefix = "level3 b=\"" + l4 + "\""
    if not prefix in eptmap:
        return "0"
    l3 = get_idx(eptmap, prefix, l3_idx)
    prefix = "level2 b=\"" + l3 + "\""
    if not prefix in eptmap:
        return "0"
    l2 = get_idx(eptmap, prefix, l2_idx)
    if skipLastLevel == True:
        return l2
    prefix = "level1 b=\"" + l2 + "\""
    if not prefix in eptmap:
        return "0"
    l1 = get_idx(eptmap, prefix, l1_idx)
    return l1

def open_dumps_fd(gpt_file, ept_file):
    global efd, efd_pos
    global gfd, gfd_pos
    efd = open(ept_file, "r")
    if not efd:
        print("Error opening host dump file")
        sys.exit(1)
    gfd = open(gpt_file, "r")
    if not gfd:
        efd.close()
        print("Error opening guest dump file")
        sys.exit(1)
        
def close_fd():
    global efd, gfd
    efd.close()
    gfd.close()

numanodes = []
maxnode = 0
CurrentTablesTmp = {}

def get_breakdown_table():
    Table = [None] * maxnode
    for i in range(0, maxnode):
        Table[i] = {'LL': 0, 'LR': 0, 'RL': 0, 'RR': 0, 'ERR' : 0}

    return Table

def print_output(outTable):
    print ('----------------------------------------------------------------------------------------------------------')
    print('Socket0: ' + str(outTable['Socket0'])[1:-1])
    print('Socket1: ' + str(outTable['Socket1'])[1:-1])
    print('Socket2: ' + str(outTable['Socket2'])[1:-1])
    print('Socket3: ' + str(outTable['Socket3'])[1:-1])

def get_numa_info(ept_src):
    global maxnode
    fd = open(ept_src, "r")
    if not fd:
        print("Unable to open ept dump for fetching numamap")
        sys.exit(1)

    line = fd.readline()
    while not line.startswith("<numa"):
        line = fd.readline()
    line = fd.readline()
    while not line.startswith("</numa"):
        if not line.startswith("#") and line != "":
            node,base,limit = line.split()
            numanodes.append((int(node), int(base), int(limit)))
            maxnode = max(maxnode, int(node))
        line = fd.readline()
    maxnode = maxnode  + 1
    fd.close()

def numa_node_for_address(addr, shift, skipLastLevel):
    global numanodes
    if addr == 0:
        return maxode
    a = int(guest_pa_to_host_pa(addr >> shift, nr_dumps_processed, skipLastLevel),16) << shift
#    if skipLastLevel:
#        print("addr = %x a = %x %d" %(addr, a, a))
    if a == 0:
        return maxnode
    for node,base,limit in numanodes :
        if base <= a and a < limit :
            return node
    return maxnode


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

def get_addr_shift(entry, level):
    # --- process levels separately
    if level == 2:
        if entry[0] == 'n':
            entry = entry[1:]
        shift = 21
        if entry[0] == 'x':
            entry = int(entry[1:], 16) << 21
        elif entry[0] == 'p':
            shift = 12
            entry = int(entry[1:], 16) << 12
        else:
            entry = int(entry, 16) << 21

        return entry, shift

    if level == 1:
        if entry[0] == 'n':
            entry = entry[1:]
        shift = 12
        if entry[0] == 'x':
            entry = int(entry[1:], 16) << 12
        else:
            entry = int(entry, 16) << 12
        return entry, shift

def update_stats(gLeafNode, hLeafNode):
    global output
    
    if gLeafNode >= maxnode or hLeafNode >= maxnode:
        index = "ERR"
        for i in range(0, len(output)):
            output[i][index] += 1;
        return

    #print(gLeafNode)
    #print(hLeafNode)
    for i in range(0, len(output)):
        index = ""
        if i == gLeafNode:
            index = "L"
        else:
            index = "R"

        if i == hLeafNode:
            index += "L"
        else:
            index += "R"
        output[i][index] += 1;

    #output_reset_stats()
    #sys.exit(1)

def output_reset_stats():
    global output
    print ('-----------------------------------------------------------------------------------------')
    for i in range(0, len(output)):
        print("Socket%d:\t LL: %6d\tLR:%6d\tRL:%6d\tRR:%6d\tERR:%6d\t" %(i, output[i]['LL'],output[i]['LR'],\
            output[i]['RL'], output[i]['RR'], output[i]['ERR']), end=' ')
        total = output[i]['LL'] + output[i]['LR'] + output[i]['RL'] + output[i]['RR']
        frac1 = frac2 = frac3 = frac4 = 0
        if total > 0:
            frac1 = int((output[i]['LL'] * 100) / float(total))
            frac2 = int((output[i]['LR'] * 100) / float(total))
            frac3 = int((output[i]['RL'] * 100) / float(total))
            frac4 = int((output[i]['RR'] * 100) / float(total))
        print("(%d %d %d %d)" %(frac1,frac2,frac3,frac4))

    output = get_breakdown_table()

def process_guest_leaf(gLeafNode, entry):
    if entry.startswith('p') or entry.startswith('x') or entry.startswith('n'):
        entry = entry[1:]
    key = "level1 b=\"" + entry + "\""
    if not key in gptmap:
        #print("L1 entry not found in gPT!")
        return
        #sys.exit(1)

    for e in gptmap[key]:
        addr, shift = get_addr_shift(e, 1)
        hLeafNode = numa_node_for_address(addr, shift, True)
        update_stats(gLeafNode, hLeafNode)
    
def process_curr_dump():
    total = len(gptmap.keys())
    for key in gptmap.keys():
        #processed += 1
        #print("Done: %d Total: %d" %(processed, total))
        # --- check for l2 keys (they point to guest PT leafs)
        if "level2" in key:
            # --- each entry is a guest page table leaf page
            for entry in gptmap[key]:
                addr, shift = get_addr_shift(entry, 2)
                gLeafNode = numa_node_for_address(addr, shift, False)
                process_guest_leaf(gLeafNode, entry)
    output_reset_stats()


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: helper_ptdumps_1.py gPT_dump ePT_dump");
        sys.exit(1)

    gpt_src = sys.argv[1]
    ept_src = sys.argv[2]
    open_dumps_fd(gpt_src, ept_src)
    get_numa_info(ept_src)
    output = get_breakdown_table()
    # --- parse the entire log, one by one
    while True:
        nr_dumps_processed += 1
        prepare_curr_dump(nr_dumps_processed)
        process_curr_dump()

    close_fd()
