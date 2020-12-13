#!/bin/bash

#################################################################################
# Hypervisor script to reproduce Figure-2 evaluation of the paper
#
# Fast Local Page-Tables for Virtualized NUMA Servers with vMitosis [ASPLOS'21]
#
# Authors: Ashish Panwar, Reto Achermann, Abhishek Bhattacharjee, Arkaprava Basu,
#          K. Gopinath and Jayneel Gandhi
#################################################################################

echo "************************************************************************"
echo "ASPLOS'21 - Artifact Evaluation - vMitosis - Figure-2"
echo "************************************************************************"

#############################################################################
BENCHMARKS="xsbench graph500 memcached canneal"
BENCHMARKS="xsbench graph500"
RUNCONFIGS="V"
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
THP="never"
AUTONUMA=0
VMCONFIG=""

# --- helper for setting up the environment and bringing up the VM
prepare_ptdump_environment()
{
    sudo rmmod ptdump.ko > /dev/null 2>&1
    (cd $ROOT/modules/ && make clean > /dev/null 2>&1 && make > /dev/null 2>&1)
    sudo insmod $ROOT/modules/ptdump.ko > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        log_msg "error inserting HOST module. Exiting"
        exit
    fi
    echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null
    echo $AUTONUMA | sudo tee /proc/sys/kernel/numa_balancing > /dev/null
    echo $THP | sudo tee /sys/kernel/mm/transparent_hugepage/enabled >/dev/null
    echo $THP | sudo tee /sys/kernel/mm/transparent_hugepage/defrag > /dev/null
    log_msg "dropped page cache, autoNUMA: $AUTONUMA, THP: $THP"

    # ---- boot-up the VM
    boot_prepare_kvm_vm
    ssh $GUESTUSER@$GUESTADDR "sudo insmod $ROOT/modules/ptdump.ko" > /dev/null
    if [ $? -ne 0 ]; then
        log_msg "error inserting GUEST module. Exiting."
        exit
    fi
    log_msg "inserted ptdump kernel module in the guest..."
}

prepare_host_ept_configs()
{
	stop_kvm_vm
	copy_vm_config
	reset_ept_configs
}

run_workload()
{
	BENCH=$1
	CONFIG=$2
	log_msg "executing command: $SCRIPTS/run_guest_figure-2.sh $1 $CONFIG"
	# --- launch the benchmark and wait for completion
	ssh $GUESTUSER@$GUESTADDR "$SCRIPTS/run_guest_figure-2.sh $BENCH $CONFIG YES"
	# --- wait for dodump user app to cleanup
	sleep 120
}

verify_kvm_pgtable_mode_ept
for BENCHMARK in $BENCHMARKS; do
    for CONFIG in $RUNCONFIGS; do
	if [[ $CONFIG == *V* ]]; then
		VMCONFIG="NUMA-visible"
	elif [[ $CONFIG == *O* ]]; then
		VMCONFIG="NUMA-oblivious"
	fi
	log_msg "dumping $VMCONFIG pgtables for $BENCHMARK "
	if [ $BENCHMARK = "canneal" ]; then
		prepare_canneal_dataset large
	fi
        rm /tmp/alloctest-bench.ready &>/dev/null
        rm /tmp/alloctest-bench.done &> /dev/null
	prepare_autonuma $CONFIG
        prepare_host_ept_configs $CONFIG
        prepare_ptdump_environment $1 $CONFIG
        run_workload $BENCHMARK $CONFIG
        log_msg_exact "workload: $BENCHMARK config: $CONFIG completed.\n\n"
        echo ""
    done
done
