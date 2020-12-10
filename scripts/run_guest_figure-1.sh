#!/bin/bash

#################################################################################
# Guest script to reproduce Figure-1 of the paper. This script is intended to
# be invoked via run_figure-1.sh (do not execute this directly).
# 
# Fast Local Page-Tables for Virtualized NUMA Servers with vMitosis [ASPLOS'21]
#
# Authors: Ashish Panwar, Reto Achermann, Abhishek Bhattacharjee, Arkaprava Basu,
#          K. Gopinath and Jayneel Gandhi
#################################################################################

#echo "************************************************************************"
#echo "ASPLOS'21 - Artifact Evaluation - vMitosis - Figure-1"
#echo "************************************************************************"

PERF_EVENTS=cycles,dtlb_load_misses.walk_pending,dtlb_store_misses.walk_pending,ept.walk_pending

# --- import common functions
SCRIPTS=$(readlink -f "`dirname $(readlink -f "$0")`")
ROOT=$(dirname "${SCRIPTS}")
source $SCRIPTS/configs.sh
source $SCRIPTS/helpers/common.sh

XSBENCH_ARGS=" -- -t 48 -g 680000 -p 15000000"
CANNEAL_ARGS=" 1 150000 2000 $ROOT/datasets/canneal_small 600"
GRAPH500_ARGS=" -- -s 28 -e 46"

if [ $# -ne 2 ]; then
    echo "Supply benchmark name and config."
    exit
fi

BENCHMARK=$1
CONFIG=$2

prepare_benchmark_name()
{
        NAME=$1
        if [ $NAME = "gups" ] || [ $NAME = "btree" ] || [ $NAME = "redis" ] ||
            [ $NAME = "canneal" ] || [ $NAME = "memcached" ] || [ $NAME = "graph500" ]; then
                POSTFIX="_st"
        else
                POSTFIX="_mt"
        fi
        PREFIX="bench_"
        BIN=$PREFIX
        BIN+=$BENCHMARK
        BIN+=$POSTFIX
}

prepare_basic_config_params()
{
        CURR_CONFIG=$1
        if [[ $CURR_CONFIG == *T* ]]; then
                CURR_CONFIG=${CURR_CONFIG:1} # -- delete T
                echo always | sudo tee /sys/kernel/mm/transparent_hugepage/enabled > /dev/null
                echo always | sudo tee /sys/kernel/mm/transparent_hugepage/defrag > /dev/null
        else
                echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled > /dev/null
                echo never | sudo tee /sys/kernel/mm/transparent_hugepage/defrag > /dev/null
        fi
        PT_NODE=0
        # --- setup data node
        DATA_NODE=1
        if [ $CURR_CONFIG = "LL" ] || [ $CURR_CONFIG = "LR" ] || [ $CURR_CONFIG = "LRI" ]; then
                DATA_NODE=0
        fi

        # --- setup cpu node
        CPU_NODE=$DATA_NODE

        if [ $BENCHMARK = "xsbench" ]; then
                BENCH_ARGS=$XSBENCH_ARGS
        elif [ $BENCHMARK = "canneal" ]; then
                BENCH_ARGS=$CANNEAL_ARGS
        elif [ $BENCHMARK = "graph500" ]; then
                BENCH_ARGS=$GRAPH500_ARGS
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
        RUNDIR=$DATADIR/$(hostname)-config-$BENCHMARK-$CONFIG-$(date +"%Y%m%d-%H%M%S")
        mkdir -p $RUNDIR
        if [ $? -ne 0 ]; then
                log_msg "Error creating output directory: $RUNDIR"
        fi
        OUTFILE=$RUNDIR/perflog-$BENCHMARK-$(hostname)-$CONFIG.dat
}

fragment_memory()
{
	NR_THREADS=192
	NR_SECONDS=1200
	FILE_1=$HOME/disk3/fragmentation/frag-1
	FILE_2=$HOME/disk4/fragmentation/frag-2
	log_msg "Fetching fragmentation files in memory. This will take a while..."
	$NUMACTL -c $DATA_NODE -m $DATA_NODE cat $FILE_1 > /dev/null &
	PID_1=$!
	$NUMACTL -c $DATA_NODE -m $DATA_NODE cat $FILE_2 > /dev/null &
	PID_2=$!
	wait $PID_1
	wait $PID_2
	log_msg "Initiating random reads. This will take a while..."
	$ROOT/bin/fragment.py $FILE_1 $FILE_2 $NR_SECONDS $NR_THREADS > /dev/null
	log_msg "Fragmentation completed."
}

launch_benchmark_config()
{
	# --- clean up exisiting state/processes
	rm /tmp/alloctest-bench.ready &>/dev/null
	rm /tmp/alloctest-bench.done &> /dev/null
	killall bench_stream &>/dev/null

        CMD_PREFIX=$NUMACTL
        CMD_PREFIX+=" -m $DATA_NODE -c $CPU_NODE "
        # obtain the number of available nodes
        NODESTR=$(numactl --hardware | grep available)
        NODE_MAX=$(echo ${NODESTR##*: } | cut -d " " -f 1)
        NODE_MAX=`expr $NODE_MAX - 1`
        FIRST_CHAR=${CONFIG:0:1}
        if [ $FIRST_CHAR = "T" ]; then
                CONFIG=${CONFIG:1}
        fi
        if [ $CONFIG = "RRG" ] || [ $CONFIG = "RRM" ] || [ $CONFIG = "RRIG" ] || [ $CONFIG = "RRIM" ]; then
                CMD_PREFIX+=" --pgtablerepl=$NODE_MAX"
        fi
	LAUNCH_CMD="$CMD_PREFIX $BENCHPATH $BENCH_ARGS"
	if [[ $BENCHMARK == *memcached* ]]; then
                REDIRECT=$OUTFILE
        else
                REDIRECT="/dev/null"
        fi
	echo $LAUNCH_CMD
	$LAUNCH_CMD > $REDIRECT 2>&1 &
	BENCHMARK_PID=$!
	SECONDS=0
	log_msg_exact "\e[0mwaiting for benchmark: $BENCHMARK_PID to be ready"
	while [ ! -f /tmp/alloctest-bench.ready ]; do
		sleep 0.1
	done
	INIT_DURATION=$SECONDS
        log_msg "signalling readyness to the host"
        ssh $HOSTUSER@$HOSTADDR 'touch /tmp/alloctest-bench.ready'
	log_msg_exact "Initialization Time (seconds): $INIT_DURATION"
	SECONDS=0
	#$PERF stat -x, -o $OUTFILE --append -e $PERF_EVENTS -p $BENCHMARK_PID &
	#PERF_PID=$!
	log_msg_exact "\e[0mwaiting for benchmark to be done"
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
        if [ $FIRST_CHAR = "T" ]; then
                CONFIG=T$CONFIG
        fi
	log_msg "$BENCHMARK : $CONFIG completed."
        echo ""
	killall bench_stream &>/dev/null
        sleep 5
        ssh $HOSTUSER@$HOSTADDR 'touch /tmp/alloctest-bench.done'
}

# --- prepare setup
prepare_benchmark_name $BENCHMARK
prepare_basic_config_params $CONFIG
prepare_all_pathnames
#fragment_memory
launch_benchmark_config
