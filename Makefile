#################################################################################
# Makefile to generate binaries for the paper
#
# Fast Local Page-Tables for Virtualized NUMA Servers with vMitosis [ASPLOS'21]
#
# Authors: Ashish Panwar, Reto Achermann, Abhishek Bhattacharjee, Arkaprava Basu,
#          K. Gopinath and Jayneel Gandhi
#################################################################################

all: vmitosis-numactl vmitosis-page-table-dump vmitosis-numa-discovery


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
	cp sources/vmitosis-numactl/.libs/libnuma.la build
	cp sources/vmitosis-numactl/.libs/libnuma.so* build
	cp sources/vmitosis-numactl/.libs/numactl build


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
