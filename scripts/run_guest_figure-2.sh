#!/bin/bash

#################################################################################
# Guest script to reproduce Figure-2 of the paper. This script is intended to
# be invoked via run_figure-2.sh (do not execute this directly).
# 
# Fast Local Page-Tables for Virtualized NUMA Servers with vMitosis [ASPLOS'21]
#
# Authors: Ashish Panwar, Reto Achermann, Abhishek Bhattacharjee, Arkaprava Basu,
#          K. Gopinath and Jayneel Gandhi
#################################################################################

#echo "************************************************************************"
#echo "ASPLOS'21 - Artifact Evaluation - vMitosis - Figure-2"
#echo "************************************************************************"


# --- import common functions
SCRIPTS=$(readlink -f "`dirname $(readlink -f "$0")`")
ROOT=$(dirname "${SCRIPTS}")
source $SCRIPTS/configs.sh
source $SCRIPTS/helpers/common.sh

# --- test datasets
#XSBENCH_ARGS="-- -p 45000000 -g 1200000"
#GRAPH500_ARGS="-- -s 29 -e 52"

# --- params used in the paper
XSBENCH_ARGS="-- -p 75000000 -g 2800000"
GRAPH500_ARGS="-- -s 30 -e 52"
CANNEAL_ARGS="-- 192 150000 2000 $ROOT/inputs/canneal/canneal_large 400000"

if [ $# -ne 3 ]; then
    echo "supply benchmark name, config and pgtable dump option"
    exit
fi
BENCHMARK=$1
CONFIG=$2
DUMP_GUEST_PGTABLE=$3

prepare_benchmark_name()
{
        PREFIX="bench_"
	POSTFIX="_mt"
        BIN=$PREFIX
        BIN+=$BENCHMARK
        BIN+=$POSTFIX
}

prepare_basic_config_params()
{
        CURR_CONFIG=$1
        FIRST_CHAR=${CURR_CONFIG:0:1}
        if [ $FIRST_CHAR = "T" ]; then
                echo always | sudo tee /sys/kernel/mm/transparent_hugepage/enabled > /dev/null
                echo always | sudo tee /sys/kernel/mm/transparent_hugepage/defrag > /dev/null
                THP="always"
        else
                echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled > /dev/null
                echo never | sudo tee /sys/kernel/mm/transparent_hugepage/defrag > /dev/null
                THP="never"
        fi
	echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null
        if [ $BENCHMARK = "xsbench" ]; then
                BENCH_ARGS=$XSBENCH_ARGS
        elif [ $BENCHMARK = "graph500" ]; then
                BENCH_ARGS=$GRAPH500_ARGS
        elif [ $BENCHMARK = "canneal" ]; then
                BENCH_ARGS=$CANNEAL_ARGS
        fi
}

prepare_all_pathnames()
{
        BENCHPATH=$ROOT"/bin/$BIN"
        NUMACTL=$ROOT"/bin/numactl"
        if [ ! -e $BENCHPATH ]; then
            log_msg "Benchmark binary is missing: $BENCHPATH"
            exit
        fi
        #if [ ! -e $NUMACTL ]; then
        #    echo "numactl is missing: $NUMACTL"
        #    exit
        #fi
	DATADIR=$ROOT"/evaluation/measured/data/ptdumps/$BENCHMARK"
	RUNDIR=$DATADIR/$(hostname)-config-$BENCHMARK-$CONFIG-$(date +"%Y%m%d-%H%M%S")
	mkdir -p $RUNDIR
	if [ $? -ne 0 ]; then
		log_msg "ERROR creating ptdump directory $RUNDIR. Exiting."
		exit
	fi
        DUMPFILE=$RUNDIR/$BENCHMARK\_gpt_dump_visible.dat
	if [[ $CONFIG == *O* ]]; then
		DUMPFILE=$RUNDIR/$BENCHMARK\_gpt_dump_oblivious.dat
	fi
        OUTFILE=$RUNDIR/run.dat
}

prepare_numactl_prefix()
{
        CURR_CONFIG=$CONFIG
        if [ $FIRST_CHAR = "T" ]; then
            CURR_CONFIG=${CURR_CONFIG:1}
        fi
        CMD_PREFIX=$NUMACTL
        if [ $CURR_CONFIG = "I" ]; then
                CMD_PREFIX+=" --interleave=all"
        fi
}

initiate_pt_dump()
{
	log_msg "initiating pgtable dumps"
	log_msg "gPT dump: $DUMPFILE"
	if [ $DUMP_GUEST_PGTABLE = "YES" ]; then
		# --- dumping 0 = guest pgtable
		$ROOT/bin/dodump $BENCHMARK_PID 0 $DUMPFILE &
		if [ $? -ne 0 ]; then
			log_msg "ERROR dumping guest page table"
		exit
		fi
	fi
	# --- initiate kvmpt dump
	if [[ $CONFIG == *V* ]]; then
		ssh $HOSTUSER@$HOSTADDR "$SCRIPTS/helpers/helper_dump_ept.sh $BENCHMARK $RUNDIR visible"
	else
		ssh $HOSTUSER@$HOSTADDR "$SCRIPTS/helpers/helper_dump_ept.sh $BENCHMARK $RUNDIR oblivious"
	fi
	if [ $? -ne 0 ]; then
		log_msg "error dumping ePT"
		exit
	fi
}

launch_benchmark_config()
{
	# --- clean up exisiting state/processes
	rm /tmp/alloctest-bench.ready &>/dev/null
	rm /tmp/alloctest-bench.done &> /dev/null
        prepare_numactl_prefix
	LAUNCH_CMD="$CMD_PREFIX $BENCHPATH $BENCH_ARGS"
        echo $LAUNCH_CMD
	REDIRECT="/dev/null"
	$LAUNCH_CMD > $REDIRECT 2>&1 &
	BENCHMARK_PID=$!
	SECONDS=0
	echo -e "\e[0mWaiting for benchmark: $BENCHMARK_PID to be ready"
	while [ ! -f /tmp/alloctest-bench.ready ]; do
		sleep 0.1
	done
	INIT_DURATION=$SECONDS
	echo -e "Initialization Time (seconds): $INIT_DURATION"
	SECONDS=0
	sleep 30
	initiate_pt_dump
	# --- wait for ptdump to finish
	while [ ! -f /tmp/ptdump-bench.done ]; do
		sleep 1
	done
	kill -9 $BENCHMARK_PID > /dev/null 2>&1
	wait $BENCHMARK_PID 2>/dev/null
	echo -e "\n$LAUNCH_CMD" >> $OUTFILE
	log_msg "$BENCHMARK : $CONFIG completed."
	log_msg "flushing ptdumps to disk..."
	sync
	sleep 10
}

# --- prepare setup
prepare_benchmark_name $BENCHMARK
prepare_basic_config_params $CONFIG
prepare_all_pathnames
launch_benchmark_config
