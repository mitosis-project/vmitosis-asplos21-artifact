#!/bin/bash

#################################################################################
# Script to deploy artifact to a test machine for evaluation of the paper
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
echo "Deployment of Binaries and Scripts to $URL"

REMOTE=$(echo $URL | cut -d ":" -f1)
DIRECTORY=$(echo $URL | cut -d ":" -f2)

echo "remote-host: $REMOTE"
echo "remote-directory: $DIRECTORY"

echo "create target directory"
ssh $REMOTE "mkdir -p $DIRECTORY/evaluation/measured"

echo "deploying files"
rsync -avz $ROOT/bin $ROOT/precompiled $ROOT/build $ROOT/datasets \
           $ROOT/scripts $ROOT/vmconfigs $URL
