#!/bin/bash

#################################################################################
# Script to select binaries for artifact evaluation of the paper
#
# Fast Local Page-Tables for Virtualized NUMA Servers with vMitosis [ASPLOS'21]
#
# Authors: Ashish Panwar, Reto Achermann, Abhishek Bhattacharjee, Arkaprava Basu,
#          K. Gopinath and Jayneel Gandhi
#################################################################################


echo "########################################################################"
echo "ASPLOS'21 - Artifact Evaluation - vMitosis"
echo "########################################################################"
echo ""
echo "Binary Selector"

SCRIPTROOT=$(dirname `readlink -f "$0"`)
ROOT=$(dirname `readlink -f "$SCRIPTROOT"`)

BINDIRECTORY=$(readlink $ROOT/bin)
if [ -z "${BINDIRECTORY}" ]; then
	BINDIR="precompiled"
else
	BINDIR=$(basename $BINDIRECTORY)
fi
if [[ "$BINDIR" == "build" ]]; then
	echo "Selected pre-compiled binaries"
	pushd $ROOT > /dev/null
	rm -f $ROOT/bin
	ln -s $ROOT/precompiled $ROOT/bin
	popd > /dev/null
	exit 0
fi

if [[ "$BINDIR" == "precompiled" ]]; then
	echo "Selected locally compiled binaries"
	pushd $ROOT > /dev/null
	rm -f $ROOT/bin
	ln -s $ROOT/build $ROOT/bin
	popd > /dev/null
	exit 0
fi

