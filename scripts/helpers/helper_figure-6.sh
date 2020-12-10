#!/bin/bash

HELPERS=$(readlink -f "`dirname $(readlink -f "$0")`")
SCRIPTS=$(dirname "${HELPERS}")
ROOT=$(dirname "${SCRIPTS}")

function process_numa_visible()
{
	TARGET=$1
	# --- pick the first target if multiple are found
	RRI=$(find $ROOT/evaluation/$TARGET/data/memcached0/ -name *-RRI.dat | head -1)
	RRIE=$(find $ROOT/evaluation/$TARGET/data/memcached0/ -name *-RRIE.dat | head -1)
	RRIG=$(find $ROOT/evaluation/$TARGET/data/memcached0/ -name *-RRIG.dat | head -1)
	RRIM=$(find $ROOT/evaluation/$TARGET/data/memcached0/ -name *-RRIM.dat | head -1)
	VR=$(find $ROOT/evaluation/$TARGET/data/memcached0/ -name *-V-IR.dat | head -1)

	mkdir -p $HELPERS/tmp
	HEADER=""
	FILES=""
	# --- file should be non-empty
	if [[ ! -z "$RRI" ]] && [ -s $RRI ]; then
		cat $RRI | grep Through | awk '{print $2}' > $HELPERS/tmp/1
		HEADER="RRI\t"
		FILES="$FILES $HELPERS/tmp/1"
	fi
	if [[ ! -z "$RRIE" ]] && [ -s $RRIE ]; then
		cat $RRIE | grep Through | awk '{print $2}' > $HELPERS/tmp/2
		HEADER=$HEADER"RRI+e\t"
		FILES="$FILES $HELPERS/tmp/2"
	fi
	if [[ ! -z  "$RRIG" ]] && [ -s $RRIG ]; then
		cat $RRIG | grep Through | awk '{print $2}' > $HELPERS/tmp/3
		HEADER=$HEADER"RRI+g\t"
		FILES="$FILES $HELPERS/tmp/3"
	fi
	if [[ ! -z  "$RRIM" ]] && [ -s $RRIM ]; then
		cat $RRIM | grep Through | awk '{print $2}' > $HELPERS/tmp/4
		HEADER=$HEADER"RRI+M\t"
		FILES="$FILES $HELPERS/tmp/4"
	fi
	if [[ ! -z "$VR" ]] && [ -s $VR ]; then
		cat $VR | grep Through | awk '{print $2}' > $HELPERS/tmp/5
		HEADER=$HEADER"Ideal-Replication\t"
		FILES="$FILES $HELPERS/tmp/5"
	fi
	mkdir -p $ROOT/evaluation/$TARGET/processed/
	echo -e "$HEADER" > $ROOT/evaluation/$TARGET/processed/figure-6a.csv
	paste $FILES >> $ROOT/evaluation/$TARGET/processed/figure-6a.csv
	rm -r $HELPERS/tmp > /dev/null 2>&1
}

function process_numa_oblivious()
{
	TARGET=$1
	# --- pick the first target if multiple are found
	RI=$(find $ROOT/evaluation/$TARGET/data/memcached0/ -name *-RI.dat | head -1)
	RIE=$(find $ROOT/evaluation/$TARGET/data/memcached0/ -name *-RIE.dat | head -1)
	OR=$(find $ROOT/evaluation/$TARGET/data/memcached0/ -name *-O-IR.dat | head -1)

	mkdir -p $HELPERS/tmp
	HEADER=""
	FILES=""
	# --- file should be non-empty
	if [[ ! -z "$RI" ]] && [ -s $RI ]; then
		cat $RI | grep Through | awk '{print $2}' > $HELPERS/tmp/1
		HEADER="RI\t"
		FILES="$FILES $HELPERS/tmp/1 "
	fi
	if [[ ! -z "$RIE" ]] && [ -s $RIE ]; then
		cat $RIE | grep Through | awk '{print $2}' > $HELPERS/tmp/2
		HEADER=$HEADER"RI+e\t"
		FILES="$FILES $HELPERS/tmp/2 "
	fi
	if [[ ! -z $OR ]] && [ -s $OR ]; then
		cat $OR | grep Through | awk '{print $2}' > $HELPERS/tmp/3
		HEADER=$HEADER"Ideal-Replication"
		FILES="$FILES $HELPERS/tmp/3 "
	fi
	mkdir -p $ROOT/evaluation/$TARGET/processed/
	echo -e "$HEADER" > $ROOT/evaluation/$TARGET/processed/figure-6b.csv
	paste $FILES >> $ROOT/evaluation/$TARGET/processed/figure-6b.csv

	rm -r $HELPERS/tmp > /dev/null 2>&1
}

for TARGET in "measured reference"; do
	process_numa_visible $TARGET
	process_numa_oblivious $TARGET
done
