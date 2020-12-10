#!/bin/bash

#################################################################################
# Guest script to reproduce Figure-6 of the paper. This script is intended to
# be invoked via run_figure-6.sh (do not execute this directly).
#
# Fast Local Page-Tables for Virtualized NUMA Servers with vMitosis [ASPLOS'21]
#
# Authors: Ashish Panwar, Reto Achermann, Abhishek Bhattacharjee, Arkaprava Basu,
#          K. Gopinath and Jayneel Gandhi
#################################################################################

#echo "************************************************************************"
#echo "ASPLOS'21 - Artifact Evaluation - vMitosis - Figure-6"
#echo "************************************************************************"

PERF_EVENTS=cycles,dtlb_load_misses.walk_pending,dtlb_store_misses.walk_pending,ept.walk_pending

# --- import common functions
SCRIPTS=$(readlink -f "`dirname $(readlink -f "$0")`")
ROOT=$(dirname "${SCRIPTS}")
source $SCRIPTS/configs.sh
source $SCRIPTS/helpers/common.sh

if [ $# -ne 2 ]; then
    echo "Supply benchmark name and config."
    exit
fi
BENCHMARK=$1
if [ $BENCHMARK = "memcached" ]; then
	BENCHMARK="memcached0"
fi
CONFIG=$2

prepare_benchmark_name()
{
        NAME=$1
	POSTFIX="_mt"
        PREFIX="bench_"
        BIN=$PREFIX
        BIN+=$BENCHMARK
        BIN+=$POSTFIX
}

reset_configs()
{
	log_msg "disabling gPT Replication and Migration"
	echo 0 | sudo tee /proc/sys/kernel/numa_pgtable_migration > /dev/null
	echo 0 | sudo tee /proc/sys/kernel/pgtable_replication > /dev/null
}

prepare_basic_config_params()
{
        CONFIG=$1
	echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled > /dev/null
	echo never | sudo tee /sys/kernel/mm/transparent_hugepage/defrag > /dev/null
	if [ $CONFIG = "RRIG" ] || [ $CONFIG = "RRIM" ]; then
		log_msg "enabling gPT migration"
		echo 1 | sudo tee /proc/sys/kernel/numa_pgtable_migration > /dev/null
	fi
        PT_NODE=0
        # --- setup data node
        DATA_NODE=0
        # --- setup cpu node
        CPU_NODE=$DATA_NODE
}

prepare_all_pathnames()
{
        BENCHPATH=$ROOT"/bin/$BIN"
        PERF=$ROOT"/bin/perf"
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

launch_benchmark_config()
{
	# --- clean up exisiting state/processes
	rm /tmp/alloctest-bench.ready &>/dev/null
	rm /tmp/alloctest-bench.done &> /dev/null
	rm /tmp/alloctest-bench.migrate &> /dev/null
	killall bench_stream &>/dev/null

        CMD_PREFIX=$NUMACTL
        CMD_PREFIX+=" -c $CPU_NODE "
        # obtain the number of available nodes
        NODESTR=$(numactl --hardware | grep available)
        NODE_MAX=$(echo ${NODESTR##*: } | cut -d " " -f 1)
        NODE_MAX=`expr $NODE_MAX - 1`
        FIRST_CHAR=${CONFIG:0:1}
        if [ $CONFIG = "V-IR" ]; then
                CMD_PREFIX+=" --pgtablerepl=$NODE_MAX"
        fi
	LAUNCH_CMD="$CMD_PREFIX $BENCHPATH $BENCH_ARGS"
	REDIRECT=$OUTFILE
	REDIRECT=$OUTFILE
	$LAUNCH_CMD > $REDIRECT 2>&1 &
	BENCHMARK_PID=$!
	SECONDS=0
	log_msg_exact "\e[0mWaiting for benchmark: $BENCHMARK_PID to be ready"
	while [ ! -f /tmp/alloctest-bench.ready ]; do
		sleep 0.1
	done
	INIT_DURATION=$SECONDS
	echo "Init time: $INIT_DURATION"
	SECONDS=0
	log_msg_exact "\e[0mWaiting for benchmark to be ready for migration"
	while [ ! -f /tmp/alloctest-bench.migrate ]; do
		sleep 0.1
	done
	# --- process migration inside guest for the NUMA-visible case (Figure-6a)
	if [[ $CONFIG ==  *RRI* ]] || [ $CONFIG = "V-IR" ]; then
		TARGET=1
		TARGET_CPUS=$(numactl -H | grep "node $TARGET cpu" | cut -d " " -f 4- | tr ' ' ',')
		taskset -a -p -c $TARGET_CPUS $BENCHMARK_PID > /dev/null 2>&1
	fi
        log_msg "signalling readyness for migration to the host"
        ssh $HOSTUSER@$HOSTADDR 'touch /tmp/alloctest-bench.ready'
	log_msg_exact "\e[0mWaiting for benchmark to be done"
	while [ ! -f /tmp/alloctest-bench.done ]; do
		sleep 0.1
	done
	DURATION=$SECONDS
	echo "****success****" >> $OUTFILE
	echo -e "Runtime: $DURATION" >> $OUTFILE
	echo -e "Runtime: $DURATION"
	echo -e "Init time: $INIT_DURATION\n" >> $OUTFILE
	kill -INT $PERF_PID &> /dev/null
	Wait $BENCHMARK_PID 2>/dev/null
	echo -e "\n$LAUNCH_CMD" >> $OUTFILE
	log_msg "$BENCHMARK : $CONFIG completed."
        echo ""
        ssh $HOSTUSER@$HOSTADDR 'touch /tmp/alloctest-bench.done'
}

#--- prepare setup
prepare_benchmark_name $BENCHMARK
reset_configs
prepare_basic_config_params $CONFIG
prepare_all_pathnames
launch_benchmark_config
