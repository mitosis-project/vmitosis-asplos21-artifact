#!/bin/bash

#################################################################################
# Script to delete raw page-table dumps for the paper
#
# Fast Local Page-Tables for Virtualized NUMA Servers with vMitosis [ASPLOS'21]
#
# Authors: Ashish Panwar, Reto Achermann, Abhishek Bhattacharjee, Arkaprava Basu,
#          K. Gopinath and Jayneel Gandhi
#################################################################################

echo "************************************************************************"
echo "ASPLOS'21 - Artifact Evaluation - vMitosis - Delete page-table dumps"
echo "************************************************************************"

HELPERS=$(readlink -f "`dirname $(readlink -f "$0")`")
SCRIPTS=$(dirname "${HELPERS}")
ROOT=$(dirname "${SCRIPTS}")

del_raw_ptdumps()
{
	rm -r $ROOT/evaluation/$TARGET/data/ptdumps/ >/dev/null 2>&1
}

TARGETS="measured reference"
for TARGET in $TARGETS; do
	del_raw_ptdumps $TARGET
done

echo "> Page-table dumps removed."
