#!/bin/bash

#################################################################################
# Hypervisor script to run Figure-4 evaluation of the paper
#
# Fast Local Page-Tables for Virtualized NUMA Servers with vMitosis [ASPLOS'21]
#
# Authors: Ashish Panwar, Reto Achermann, Abhishek Bhattacharjee, Arkaprava Basu,
#          K. Gopinath and Jayneel Gandhi
#################################################################################

echo "************************************************************************"
echo "ASPLOS'21 - Artifact Evaluation - vMitosis - Figure-4"
echo "************************************************************************"

#############################################################################
# BENCHMARKS="memcached xsbench graph500 canneal"
BENCHMARKS="graph500"

# --- ePT/gPT replication enabled/disabled
RUNCONFIGS="F FM FA FAM I IM TF TFM TFA TFAM TI TIM"
RUNCONFIGS="TFE TFAE TIE TFG TFAG TIG"
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
AUTONUMA="0"
THP=""
VMCONFIG="NUMA-visible"

prepare_host_ept_configs()
{
    CURR_CONFIG=$1
    stop_kvm_vm
    reset_ept_configs
    if [[ $CURR_CONFIG == *E* ]] || [[ $CURR_CONFIG == *M* ]]; then
        set_ept_replication $EPT_CACHE
    fi
}

run_benchmark_config()
{
    BENCHMARK=$1
    CONFIG=$2
    SCRIPTS=$(readlink -f "`dirname $(readlink -f "$0")`")
    log_msg "executing command: $SCRIPTS/run_guest_figure-4.sh $BENCHMARK $CONFIG"
    # --- launch the benchmark and wait for completion
    ssh $GUESTUSER@$GUESTADDR "$SCRIPTS/run_guest_figure-4.sh $BENCHMARK $CONFIG"
    sleep 10
}

verify_kvm_pgtable_mode_ept
for BENCHMARK in $BENCHMARKS; do
	for CONFIG in $RUNCONFIGS; do
		THP="never"
		REMOTE_THP_ALLOC=1
		if [[ $CONFIG == *T* ]]; then
			THP="always"
		fi
		rm /tmp/alloctest-bench.ready &>/dev/null
		rm /tmp/alloctest-bench.done &> /dev/null
		log_msg "next workload: $BENCHMARK config: $CONFIG..."
                if [ $BENCHMARK = "canneal" ]; then
			prepare_canneal_dataset large
		fi
		prepare_autonuma $CONFIG
		prepare_host_ept_configs $CONFIG
		prepare_environment $BENCHMARK $CONFIG
		run_benchmark_config $BENCHMARK $CONFIG
		log_msg_exact "workload: $BENCHMARK config: $CONFIG completed.\n\n"
		echo ""
	done
done
