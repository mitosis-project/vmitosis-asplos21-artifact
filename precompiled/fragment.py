#!/usr/bin/python

'''
This script creates fragmentation by reading two large files randomly in memory.
This it will keep on doing for a pre-specified time accepted via arguments.
This we will do it with multi threaded.
'''

import sys, time, random, string, os
from multiprocessing import Process, Manager

FILE_NAME1 = sys.argv[1]
FILE_NAME2 = sys.argv[2]
NR_SECONDS = int(sys.argv[3])
NR_THREADS = int(sys.argv[4])

print 'NR_SECONDS', NR_SECONDS
print 'NR_THREADS', NR_THREADS

ns = Manager().Namespace()
ns.ops = 0

def read_file(name):
        f = open(name, 'r')
        f.seek(0, os.SEEK_END)
        FILE_SIZE = f.tell();
        ops = 0
        t_end = time.time() + NR_SECONDS
        while time.time() < t_end:
                r = random.randint(0, FILE_SIZE - 10);
                f.seek(r)
                t = f.read(20);
                ops += 1;
        f.close()
        ns.ops += ops

def fragment_file_1():
        read_file(FILE_NAME1)


def fragment_file_2():
        read_file(FILE_NAME2)

procs = []
for i in range(max(1, NR_THREADS/2)):
        p1 = Process(target = fragment_file_1)
        p2 = Process(target = fragment_file_2)
        procs.append(p1)
        procs.append(p2)
        p1.start()
        p2.start()

print 'Created the threads. Waiting for then to complete'
for p in procs:
        p.join()

print 'All threads joined'
print 'Read operations performed are :', ns.ops
