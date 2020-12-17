#################################################################################
# Makefile to generate binaries for the paper
#
# Fast Local Page-Tables for Virtualized NUMA Servers with vMitosis [ASPLOS'21]
#
# Authors: Ashish Panwar, Reto Achermann, Abhishek Bhattacharjee, Arkaprava Basu,
#          K. Gopinath and Jayneel Gandhi
#################################################################################

all: vmitosis-numactl vmitosis-page-table-dump vmitosis-numa-discovery \
	btree gups canneal xsbench graph500 redis stream


###############################################################################
# mitosis-numactl
###############################################################################

sources/vmitosis-numactl/README.md :
	echo "initialized git submodules"
	git submodule init 
	git submodule update

sources/vmitosis-numactl/configure:
	(cd sources/vmitosis-numactl && ./autogen.sh)

sources/vmitosis-numactl/Makefile: sources/vmitosis-numactl/configure
	(cd sources/vmitosis-numactl && ./configure)

vmitosis-numactl: $(NDEPS) sources/vmitosis-numactl/Makefile
	+$(MAKE) -C sources/vmitosis-numactl 
	cp sources/vmitosis-numactl/numactl build
	cp -r sources/vmitosis-numactl/.libs build


###############################################################################
# Page Table Dumping tool
###############################################################################

vmitosis-page-table-dump:
	+$(MAKE) -C sources/vmitosis-page-table-dump
	cp sources/vmitosis-page-table-dump/bin/* build

install-lkml:
	insmod bin/page-table-dump.ko

uninstall-lkml:
	rmmod bin/page-table-dump.ko

update-lkml:
	rmmod bin/page-table-dump.ko
	insmod bin/page-table-dump.ko


###############################################################################
# NUMA topology discovery tool
###############################################################################

vmitosis-numa-discovery:
	+$(MAKE) -C sources/vmitosis-numa-discovery
	cp sources/vmitosis-numa-discovery/mini-probe build
	cp sources/vmitosis-numa-discovery/micro-probe.py build

###############################################################################
# Workloads
###############################################################################

WORKLOADS=sources/vmitosis-workloads
WDEPS=sources/vmitosis-workloads/README.md

sources/vmitosis-workloads/README.md:
	echo "initialized git submodules"
	git submodule init
	git submodule update


###############################################################################
# BTree
###############################################################################

btree : $(WDEPS)
	+$(MAKE) -C $(WORKLOADS) btree
	cp $(WORKLOADS)/bin/bench_btree_st build


###############################################################################
# Canneal
###############################################################################

canneal : $(WDEPS)
	+$(MAKE) -C $(WORKLOADS) canneal
	cp $(WORKLOADS)/bin/bench_canneal_st build
	cp $(WORKLOADS)/bin/bench_canneal_mt build


###############################################################################
# Graph500
###############################################################################

graph500 : $(WDEPS)
	+$(MAKE) -C $(WORKLOADS) graph500
	cp $(WORKLOADS)/bin/bench_graph500_mt build


###############################################################################
# Gups
###############################################################################

gups : $(WDEPS)
	+$(MAKE) -C $(WORKLOADS) gups
	cp $(WORKLOADS)/bin/bench_gups_st build
	cp $(WORKLOADS)/bin/bench_gups_toy build/bench_test_st


###############################################################################
# XSBench
###############################################################################

xsbench : $(WDEPS)
	+$(MAKE) -C $(WORKLOADS) xsbench
	cp $(WORKLOADS)/bin/bench_xsbench_mt build
	cp $(WORKLOADS)/bin/bench_xsbench_mt build/bench_test_mt


###############################################################################
# Redis
###############################################################################

redis : $(WDEPS)
	+$(MAKE) -C $(WORKLOADS) redis
	cp $(WORKLOADS)/bin/bench_redis_st build


###############################################################################
# STREAM
###############################################################################

stream : $(WDEPS)
	+$(MAKE) -C $(WORKLOADS) stream
	cp $(WORKLOADS)/bin/bench_stream build

clean:
	rm build/*
