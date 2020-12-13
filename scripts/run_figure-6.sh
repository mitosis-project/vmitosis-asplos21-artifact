#!/bin/bash

#################################################################################
# Hypervisor script to reproduce Figure-6 evaluation of the paper
#
# Fast Local Page-Tables for Virtualized NUMA Servers with vMitosis [ASPLOS'21]
#
# Authors: Ashish Panwar, Reto Achermann, Abhishek Bhattacharjee, Arkaprava Basu,
#          K. Gopinath and Jayneel Gandhi
#################################################################################

echo "************************************************************************"
echo "ASPLOS'21 - Artifact Evaluation - vMitosis - Figure-6"
echo "************************************************************************"

#############################################################################
# --- list of benchmarks (edit this to run a subset of benchmarks)
BENCHMARKS="memcached" # -- This is the only workload for these experiments

# --- list of configurations (edit this to run a subset of configurations)
RUNCONFIGS="RRI RRIE RRIG RRIM V-IR RI RIE O-IR"
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
AUTONUMA=1
VMCONFIG="NUMA-visible"

prepare_host_ept_configs()
{
	CURR_CONFIG=$1
	stop_kvm_vm
	reset_ept_configs
	if [ $CURR_CONFIG = "RRIE" ] || [ $CURR_CONFIG = "RRIM" ] || [ $CURR_CONFIG = "RIE" ] ; then
		set_ept_node 0
		set_ept_migration 1
	elif [ $CURR_CONFIG = "RRI" ] || [ $CURR_CONFIG = "RRIG" ]; then
		set_ept_node 0
	elif [ $CURR_CONFIG = "V-IR" ] || [ $CURR_CONFIG = "O-IR" ]; then
		set_ept_replication $EPT_CACHE
	elif [ $CURR_CONFIG = "RI" ]; then
		log_msg "running with default ePT config"
	else
		log_msg "Unknown config: $CURR_CONFIG"
		exit
	fi
}

prepare_guest_pt_configs()
{
    # --- for this experiement, let the guest run in default mode
    set_guest_replication -1
}

prepare_interference_nodes()
{
	INTERFERENCE_NODES="0"
}

launch_interference()
{
	CURR_CONFIG=$1
	# --- check configuration and launch interference, if specified
	LAST_CHAR=${CURR_CONFIG: -1}
	for INODE in $INTERFERENCE_NODES; do
		if [ $INODE != "X" ]; then
			while [ ! -f /tmp/alloctest-bench.ready ]; do
				sleep 0.1
			done
			# -- VM migration for NUMA-oblivious config (Figure-6b)
			if [ $CONFIG = "RI" ] || [ $CONFIG = "RIE" ] || [ $CONFIG = "O-IR" ]; then
				log_msg "*************VM Migration Initiated************"
				migrate_kvm_vm $POST_MIGRATION_SOCKET
			fi
			log_msg "Launching STREAM on $INODE"
			numactl -c $INODE -m $INODE $ROOT/bin/$INT_BIN > /dev/null 2>&1 &
			PID=$!
			disown $PID
		fi
        done
}

run_benchmark_config()
{
	BENCHMARK=$1
	CONFIG=$2
	SCRIPTS=$(readlink -f "`dirname $(readlink -f "$0")`")
	log_msg "executing command: $SCRIPTS/run_guest_figure-6.sh $BENCHMARK $CONFIG"
	# --- launch the benchmark and wait for completion
	ssh $GUESTUSER@$GUESTADDR "$SCRIPTS/run_guest_figure-6.sh $BENCHMARK $CONFIG" &
	launch_interference $CONFIG
	while [ ! -f /tmp/alloctest-bench.done ]; do
		sleep 1
	done
	killall $INT_BIN >/dev/null
	sleep 5
}

verify_kvm_pgtable_mode_ept
for BENCHMARK in $BENCHMARKS; do
	for CONFIG in $RUNCONFIGS; do
		killall $INT_BIN >/dev/null
		if [[ $CONFIG == *RRI* ]] || [[ $CONFIG == *V* ]]; then
			VMCONFIG="NUMA-visible"
		elif [ $CONFIG = "RI" ] || [ $CONFIG = "RIE" ] || [[ $CONFIG == *O* ]]; then
			VMCONFIG="singlesocket"
		else
			log_msg "unknown VM config...exiting"
			exit
		fi
		rm /tmp/alloctest-bench.ready &>/dev/null
		rm /tmp/alloctest-bench.done &> /dev/null
		log_msg "Next workload: $BENCHMARK config: $CONFIG..."
		prepare_host_ept_configs $CONFIG
		prepare_environment $1
		prepare_guest_pt_configs $CONFIG
		prepare_interference_nodes $CONFIG
		run_benchmark_config $BENCHMARK $CONFIG
		log_msg_exact "workload: $BENCHMARK config: $CONFIG completed.\n\n"
		sleep 5
		echo ""
	done
done
