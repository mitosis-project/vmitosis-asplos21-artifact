#!/bin/bash

#################################################################################
# Hypervisor script to reproduce Figure-1 evaluation of the paper
#
# Fast Local Page-Tables for Virtualized NUMA Servers with vMitosis [ASPLOS'21]
#
# Authors: Ashish Panwar, Reto Achermann, Abhishek Bhattacharjee, Arkaprava Basu,
#          K. Gopinath and Jayneel Gandhi
#################################################################################

echo "************************************************************************"
echo "ASPLOS'21 - Artifact Evaluation - vMitosis - Figure-1"
echo "************************************************************************"


#############################################################################
# BENCHMARKS="gups btree redis xsbench memcached canneal"
BENCHMARKS="canneal"

# gPT/ePT (Local/Remote)
RUNCONFIGS="LL LR RL RR LRI RLI RRI" #TLL TLR TRL TRR TLRI TRLI TRRI
RUNCONFIGS="LL RR RRI"
#############################################################################


# --- run a particular config, if supplied
if [ $# -eq 2 ]; then
        BENCHMARKS=$1
        RUNCONFIGS=$2
fi

# --- import common functions
SCRIPTS=$(readlink -f "`dirname $(readlink -f "$0")`")
ROOT=$(dirname "${SCRIPTS}")
source $SCRIPTS/configs.sh
source $SCRIPTS/helpers/common.sh

#############################################################################
#                        DON'T EDIT BELOW THIS LINE                         #
#############################################################################
THP=""
AUTONUMA=0
VMCONFIG="NUMA-visible"

prepare_host_ept_configs()
{
	CURR_CONFIG=$1
	stop_kvm_vm
	reset_ept_configs
	if [[ $CURR_CONFIG == *LR* ]] || [[ $CURR_CONFIG == *RL* ]]; then
		set_ept_node 1
	else
		set_ept_node 0
	fi
}

prepare_guest_pt_configs()
{
    # --- fix guest PT on node 0 and move other things around
    set_guest_replication 0
}

prepare_interference_nodes()
{
    CURR_CONFIG=$1
    if [ $CURR_CONFIG = "LRI" ]; then
        INTERFERENCE_NODES="1"
    elif [[ $CURR_CONFIG == *I* ]]; then
        INTERFERENCE_NODES="0"
    else
        INTERFERENCE_NODES="X"
    fi
}

launch_interference()
{
    CURR_CONFIG=$1
    # --- check configuration and launch interference, if specified
    LAST_CHAR=${CURR_CONFIG: -1}
    if [ $LAST_CHAR = "I" ] || [[ $CURR_CONFIG = RRI* ]]; then
        for INODE in $INTERFERENCE_NODES; do
            if [ $INODE != "X" ]; then
                while [ ! -f /tmp/alloctest-bench.ready ]; do
                    sleep 0.1
                done
                log_msg "launching STREAM on node: $INODE"
                numactl -c $INODE -m $INODE $ROOT/bin/$INT_BIN > /dev/null 2>&1 &
                PID=$!
                disown $PID
            fi
        done
    fi
}

run_benchmark_config()
{
	BENCHMARK=$1
	CONFIG=$2
	SCRIPTS=$(readlink -f "`dirname $(readlink -f "$0")`")
	log_msg "executing command: $SCRIPTS/run_guest_figure-1.sh $BENCHMARK $CONFIG"
	# --- launch the benchmark and wait for completion
	ssh $GUESTUSER@$GUESTADDR "$SCRIPTS/run_guest_figure-1.sh $BENCHMARK $CONFIG" &
	launch_interference $2 # --- send without T
	while [ ! -f /tmp/alloctest-bench.done ]; do
		sleep 1
	done
	killall $INT_BIN >/dev/null
}

verify_kvm_pgtable_mode_ept
for BENCHMARK in $BENCHMARKS; do
	for CONFIG in $RUNCONFIGS; do
		THP="never"
		if [[ $CONFIG == *T* ]]; then
			THP="always"
		fi
		rm /tmp/alloctest-bench.ready &>/dev/null
		rm /tmp/alloctest-bench.done &> /dev/null
		log_msg "next workload: $BENCHMARK config: $CONFIG..."
		if [ $BENCHMARK = "canneal" ]; then
			prepare_canneal_dataset small
		fi
		prepare_host_ept_configs $CONFIG
		prepare_environment $BENCHMARK 
		prepare_guest_pt_configs $CONFIG
		prepare_interference_nodes $CONFIG
		run_benchmark_config $BENCHMARK $CONFIG
		log_msg_exact "workload: $BENCHMARK config: $CONFIG completed.\n\n"
		echo ""
	done
done
