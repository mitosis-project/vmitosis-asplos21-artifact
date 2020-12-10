#!/bin/bash

#################################################################################
# A simple bash script to configure parameters.
# 
# Fast Local Page-Tables for Virtualized NUMA Servers with vMitosis [ASPLOS'21]
#
# Authors: Ashish Panwar, Reto Achermann, Abhishek Bhattacharjee, Arkaprava Basu,
#          K. Gopinath and Jayneel Gandhi
#################################################################################

# --- required for host to guest commands
GUESTUSER=ashish
GUESTADDR="192.168.122.112"
HOSTUSER=ashish
HOSTADDR="10.202.4.119"

# --- libvirt's VM image id
VMIMAGE=mirage

# --- required for Figure-3c
FRAGMENT_FILE1=$HOME/disk3/fragmentation/frag-1
FRAGMENT_FILE2=$HOME/disk4/fragmentation/frag-2

#############################################################################
#                        DON'T EDIT BELOW THIS LINE                         #
#############################################################################
# -- memory pages per socket (4GB by default)
EPT_CACHE=1000000
# -- will be adjusted when required
INTERFERENCE_NODES="0"
# -- binary to add memory contention
INT_BIN=bench_stream

# --- required for VM migration in Figure-6b
PRE_MIGRATION_SOCKET=0
POST_MIGRATION_SOCKET=1

# --- time in seconds
WAIT_SECS_SHORT=30
WAIT_SECS_LONG=100

# --- allocate THP from a remote node
REMOTE_THP_ALLOC=0
