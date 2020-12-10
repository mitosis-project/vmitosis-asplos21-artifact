#!/bin/bash

if [ "$#" -ne 3 ]; then
	echo "Supply benchmark name and directory for dump file!!!"
	exit
fi

BENCHMARK=$1
RUNDIR=$2
NUMACONFIG=$3

# Make sure we find a running vm first
PID=$(pgrep qemu-system-x86)
if [ -z "$PID" ]; then
	echo "unable to find a running VM..."
	exit
fi

HELPERS=$(readlink -f "`dirname $(readlink -f "$0")`")
SCRIPTS=$(dirname "${HELPERS}")
ROOT=$(dirname "${SCRIPTS}")

DUMPFILE=$RUNDIR/$BENCHMARK\_ept_dump_$NUMACONFIG.dat
echo "ePT dump: $DUMPFILE"
# -- second argument, 1 = extended page-tables, 2 = shadow page-tables
$ROOT/bin/dodump $PID 1 $DUMPFILE &
