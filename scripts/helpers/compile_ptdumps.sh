#!/bin/bash

#################################################################################
# Hypervisor script for post-processing Figure-2 of the paper
#
# Fast Local Page-Tables for Virtualized NUMA Servers with vMitosis [ASPLOS'21]
#
# Authors: Ashish Panwar, Reto Achermann, Abhishek Bhattacharjee, Arkaprava Basu,
#          K. Gopinath and Jayneel Gandhi
#################################################################################

if [ $# -eq 0 ]; then
	echo "******************************************************************************"
	echo "ASPLOS'21 - Artifact Evaluation - vMitosis - Figure-2 (post-processing pt dumps)"
	echo "******************************************************************************"
fi

#############################################################################
# BENCHMARKS="memcached xsbench graph500 canneal"
BENCHMARKS="memcached xsbench graph500 canneal dumptest"

# visible or oblivious
NUMACONFIGS="visible oblivious"
#############################################################################

HELPERS=$(readlink -f "`dirname $(readlink -f "$0")`")
SCRIPTS=$(dirname "${HELPERS}")
ROOT=$(dirname "${SCRIPTS}")

for BENCHMARK in $BENCHMARKS; do
	for CONFIG in $NUMACONFIGS; do
		# --- break if ptdumps are not available
		if [ ! -e $ROOT/evaluation/measured/data/ptdumps/ ]; then
			break
		fi
		gPT=$(find $ROOT/evaluation/measured/data/ptdumps/ -name $BENCHMARK\_gpt_dump_$CONFIG.dat | head -1)
		ePT=$(find $ROOT/evaluation/measured/data/ptdumps/ -name $BENCHMARK\_ept_dump_$CONFIG.dat | head -1)
		if [ -z "$gPT" ] || [ -z "$ePT" ]; then
			#echo "NUMA-$CONFIG pgtable dumps not found for $BENCHMARK"
			continue
		else
			OUTDIR=$ROOT/evaluation/measured/processed/ptdumps
			mkdir -p $OUTDIR
			OUTFILE=$OUTDIR/$BENCHMARK\_numa\_$CONFIG\_breakdown.dat
			if [ ! -e $OUTFILE ] || [ ! -s $OUTFILE ]; then 
				echo "*****processing NUMA-$CONFIG ptdumps for $BENCHMARK*****"
				echo "This may take a while..."
				#echo $gPT
				#echo $ePT
				$SCRIPTS/helpers/helper_ptdumps_calc_breakdown.py $gPT $ePT > $OUTFILE
			fi
		fi
		if [ $# = 0 ]; then
			echo "$OUTFILE"
		fi
	done
done

# --- generate CSV to be plotted
$SCRIPTS/helpers/helper_ptdumps_gen_csv.py

TARGETS="measured reference"
if [ $# -eq 1 ]; then
	TARGETS=$1
fi
FIGURES="figure-2a figure-2b"
for TARGET in $TARGETS; do
	for FIGURE in $FIGURES; do
		SRC=$ROOT/evaluation/$TARGET/processed/$FIGURE.csv
		PDF=$ROOT/evaluation/$TARGET/processed/$FIGURE.pdf
		mkdir -p $ROOT/evaluation/$TARGET/processed/
		if [ -e $SRC ]; then
			$SCRIPTS/plots/plot_$FIGURE.py $SRC $PDF
			echo $PDF
		fi
	done
done
