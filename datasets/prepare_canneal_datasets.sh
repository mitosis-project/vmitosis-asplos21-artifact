#!/bin/bash

###############################################################################
# Script to generate small and large datasets for canneal (from PARSEC suite)
# 
# Mirage: An Illusion of Fast Local Page-Tables for Virtualized NUMA Servers
# Authors: Ashish Panwar, Reto Achermann, Abhishek Bhattacharjee, Arkaprava Basu,
#          K. Gopinath and Jayneel Gandhi
###############################################################################

if [ $# -eq 2 ] && [ $2 != "--no-verbose" ]; then
	echo "************************************************************************"
	echo "ASPLOS'21 - Artifact Evaluation - Mirage - DATASET PREPARATION"
	echo "************************************************************************"
fi

# --- generate both datasets by default
GEN_SMALL=1
GEN_LARGE=1

if [ $# -eq 1 ]; then
	if [ $1 == "small" ]; then
		GEN_LARGE=0
	elif [ $1 == "large" ]; then
		GEN_SMALL=0
	fi
fi

ROOT=$(dirname `readlink -f "$0"`)
SRC_SCRIPT="$ROOT/canneal_netlist.pl"

URL_SCRIPT="https://parsec.cs.princeton.edu/download/other/canneal_netlist.pl"
if [ ! -e $SRC_SCRIPT ]; then
    echo "Canneal gen script is missing. Downloading it now..."
    wget $URL_SCRIPT -P $ROOT/
    if [ $? -ne 0 ]; then
        echo "error in downloading canneal gen script"
        exit
    fi
fi

chmod +x $SRC_SCRIPT
if [ $GEN_SMALL -eq 1 ]; then
	if [ ! -e $ROOT/canneal_small ]; then
		echo "preparing small dataset. This will take a while..."
		$SRC_SCRIPT 10000 11000 100000000 > $ROOT/canneal_small
		echo "dataset is ready now."
	else
		echo "dataset is already present. Reusing the existing one."
	fi
fi
if [ $GEN_LARGE -eq 1 ]; then
	if [ ! -e $ROOT/canneal_large ]; then
		echo "Generating large dataset for canneal. This will take a while..."
		$SRC_SCRIPT 120000 11000 1200000000 > $ROOT/canneal_large
		echo "Dataset is ready now."
	fi
fi
