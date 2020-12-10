#!/bin/bash

#################################################################################
# Guest script to reproduce Figure-4 of the paper. This script is intended to
# be invoked via run_figure-4.sh (do not execute this directly).
# 
# Fast Local Page-Tables for Virtualized NUMA Servers with vMitosis [ASPLOS'21]
#
# Authors: Ashish Panwar, Reto Achermann, Abhishek Bhattacharjee, Arkaprava Basu,
#          K. Gopinath and Jayneel Gandhi
#################################################################################

#echo "************************************************************************"
#echo "ASPLOS'21 - Artifact Evaluation - vMitosis - Figure-4"
#echo "************************************************************************"


PERF_EVENTS=cycles,dtlb_load_misses.walk_pending,dtlb_store_misses.walk_pending,ept.walk_pending

# --- page table cache size
GPT_CACHE=1000000

# --- import common functions
SCRIPTS=$(readlink -f "`dirname $(readlink -f "$0")`")
ROOT=$(dirname "${SCRIPTS}")
source $SCRIPTS/configs.sh
source $SCRIPTS/helpers/common.sh


XSBENCH_ARGS="-- -p 75000000 -g 2800000"
GRAPH500_ARGS="-- -s 30 -e 52"
CANNEAL_ARGS="-- 192 150000 2000 $ROOT/datasets/canneal_large 400000"

if [ $# -ne 2 ]; then
    echo "supply benchmark name and config."
    exit
fi

BENCHMARK=$1
CONFIG=$2

if [[ $BENCHMARK = *memcached* ]]; then
	GPT_CACHE=2000000
fi

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
        if [[ $CURR_CONFIG == *T* ]]; then
                echo always | sudo tee /sys/kernel/mm/transparent_hugepage/enabled > /dev/null
                echo always | sudo tee /sys/kernel/mm/transparent_hugepage/defrag > /dev/null
                THP="always"
        else
                echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled > /dev/null
                echo never | sudo tee /sys/kernel/mm/transparent_hugepage/defrag > /dev/null
                THP="never"
        fi

        if [ $BENCHMARK = "xsbench" ]; then
                BENCH_ARGS=$XSBENCH_ARGS
        elif [ $BENCHMARK = "graph500" ]; then
                BENCH_ARGS=$GRAPH500_ARGS
        elif [ $BENCHMARK = "canneal" ]; then
                BENCH_ARGS=$CANNEAL_ARGS
        elif [ $BENCHMARK = "liblinear" ]; then
		BENCH_ARGS=$LIBLINEAR_ARGS
        elif [ $BENCHMARK = "pagerank" ]; then
		BENCH_ARGS=$PAGERANK_ARGS
        elif [ $BENCHMARK = "snap" ]; then
		BENCH_ARGS=$SNAP_ARGS
        fi
}

prepare_all_pathnames()
{
        BENCHPATH=$ROOT"/bin/$BIN"
        #PERF=$ROOT"/bin/perf"
        NUMACTL=$ROOT"/bin/numactl"
        if [ ! -e $BENCHPATH ]; then
            log_msg "Benchmark binary is missing: $BENCHPATH"
            exit
        fi
        #if [ ! -e $PERF ]; then
        #    echo "Perf binary is missing: $PERF "
        #    exit
        #fi
        if [ ! -e $NUMACTL ]; then
            log_msg "numactl is missing: $NUMACTL"
            exit
        fi
	DATADIR=$ROOT"/evaluation/measured/data/$BENCHMARK"
        OUTCONFIG=$CONFIG
        RUNDIR=$DATADIR/$(hostname)-config-$BENCHMARK-$OUTCONFIG-$(date +"%Y%m%d-%H%M%S")
        mkdir -p $RUNDIR
        if [ $? -ne 0 ]; then
                log_msg "Error creating output directory: $RUNDIR"
        fi
        OUTFILE=$RUNDIR/perflog-$BENCHMARK-$(hostname)-$OUTCONFIG.dat
}

prepare_numactl_prefix()
{
        CURR_CONFIG=$CONFIG
        CMD_PREFIX=$NUMACTL
        if [[ $CURR_CONFIG == *I* ]]; then
                CMD_PREFIX+=" --interleave=all"
        fi
        # obtain the number of available nodes
        NODESTR=$(numactl --hardware | grep available)
        NODE_MAX=$(echo ${NODESTR##*: } | cut -d " " -f 1)
        NODE_MAX=`expr $NODE_MAX - 1`
	if [[ $CURR_CONFIG == *G* ]] || [[ $CURR_CONFIG == *M* ]]; then
                echo $GPT_CACHE | sudo tee /proc/sys/kernel/pgtable_replication_cache >/dev/null
                if [ $? -ne 0 ]; then
                        log_msg "Error reserving PT Replication Cache..."
                        exit
                fi
                CMD_PREFIX+=" --pgtablerepl=$NODE_MAX"
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
	if [[ $BENCHMARK = *memcached* ]]; then
                REDIRECT=$OUTFILE
        else
                REDIRECT="/dev/null"
        fi
	$LAUNCH_CMD > $REDIRECT 2>&1 &
	BENCHMARK_PID=$!
	SECONDS=0
	log_msg_exact "\e[0mwaiting for benchmark: $BENCHMARK_PID to be ready"
	while [ ! -f /tmp/alloctest-bench.ready ]; do
		sleep 0.1
	done
	INIT_DURATION=$SECONDS
	log_msg_exact "Initialization Time (seconds): $INIT_DURATION"
	SECONDS=0
	#$PERF stat -x, -o $OUTFILE --append -e $PERF_EVENTS -p $BENCHMARK_PID &
	#PERF_PID=$!
	echo -e "\e[0mwaiting for benchmark to be done"
	while [ ! -f /tmp/alloctest-bench.done ]; do
		sleep 0.1
	done
	DURATION=$SECONDS
	echo "****success****" >> $OUTFILE
	echo -e "Execution Time (seconds): $DURATION" >> $OUTFILE
	echo -e "Execution Time (seconds): $DURATION"
	echo -e "Initialization Time (seconds): $INIT_DURATION\n" >> $OUTFILE
	#kill -INT $PERF_PID &> /dev/null
	#wait $PERF_PID
	if [ $BENCHMARK = "canneal" ]; then
		kill -9 $BENCHMARK_PID > /dev/null 2>&1
	fi
	wait $BENCHMARK_PID 2>/dev/null
	echo -e "\n$LAUNCH_CMD" >> $OUTFILE
	echo "$BENCHMARK : $CONFIG completed."
        echo ""
}

# --- prepare setup
prepare_benchmark_name $BENCHMARK
prepare_basic_config_params $CONFIG
prepare_all_pathnames
launch_benchmark_config
