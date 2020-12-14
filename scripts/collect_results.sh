#!/bin/bash

#################################################################################
# Script to copy results from the test machine for evaluation of the paper
#
# Fast Local Page-Tables for Virtualized NUMA Servers with vMitosis [ASPLOS'21]
#
# Authors: Ashish Panwar, Reto Achermann, Abhishek Bhattacharjee, Arkaprava Basu,
#          K. Gopinath and Jayneel Gandhi
#################################################################################

SCRIPTROOT=$(dirname `readlink -f "$0"`)
ROOT=$(dirname `readlink -f "$SCRIPTROOT"`)

source $ROOT/scripts/configs.sh

echo "########################################################################"
echo "ASPLOS'21 - Artifact Evaluation - vMitosis"
echo "########################################################################"
echo ""
echo "Collecting results form $URL"

REMOTE=$(echo $URL | cut -d ":" -f1)
DIRECTORY=$(echo $URL | cut -d ":" -f2)

rsync -avz $URL/evaluation/measured/* $ROOT/evaluation/measured/
