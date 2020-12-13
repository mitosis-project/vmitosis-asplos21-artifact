#!/bin/bash

#################################################################################
# A common helper script for the vMitosis artifact (do not execute this directly).
# 
# Fast Local Page-Tables for Virtualized NUMA Servers with vMitosis [ASPLOS'21]
#
# Authors: Ashish Panwar, Reto Achermann, Abhishek Bhattacharjee, Arkaprava Basu,
#          K. Gopinath and Jayneel Gandhi
#################################################################################

#############################################################################
#                        DON'T EDIT BELOW THIS LINE                         #
#############################################################################

#HELPERS=$(readlink -f "`dirname $(readlink -f "$0")`")
#SCRIPTS=$(dirname "${HELPERS}")
#ROOT=$(dirname "${SCRIPTS}")

log_msg()
{
	echo $1 | tee -a $SCRIPTS/log
}

log_msg_exact()
{
	echo -e $1 | tee -a $SCRIPTS/log
}

stop_kvm_vm()
{
	PID=$(pgrep qemu-system-x86)
	if [ "$PID" ]; then
		log_msg "VM is running. Shutting down."
		ssh $GUESTUSER@$GUESTADDR "sudo shutdown now" &> /dev/null
		wait $PID 2>/dev/null
		sleep $WAIT_SECS_SHORT
		#log_msg "VM stopped. Preparing to launch next config"
	fi
	virsh destroy $VMIMAGE > /dev/null 2>&1
}

copy_vm_config()
{
	STATUS=0
	sudo service libvirtd stop
	if [ $VMCONFIG = "NUMA-visible" ]; then
		#echo "configuring NUMA-visible VM..."
		sudo cp $ROOT/vmconfigs/numa-visible.xml /etc/libvirt/qemu/$VMIMAGE.xml
		STATUS=$?
	elif [ $VMCONFIG = "NUMA-oblivious" ]; then
		echo "configuring NUMA-oblivious VM..."
		sudo cp $ROOT/vmconfigs/numa-oblivious.xml /etc/libvirt/qemu/$VMIMAGE.xml
		STATUS=$?
	elif [ $VMCONFIG = "singlesocket" ]; then
		#echo "configuring a small single socket VM..."
		sudo cp $ROOT/vmconfigs/small-singlesocket.xml /etc/libvirt/qemu/$VMIMAGE.xml
		STATUS=$?
	fi
	sudo service libvirtd start
	if [ $STATUS -ne 0 ]; then
		echo "error copying VM config file."
		exit
	fi
}

boot_prepare_kvm_vm()
{
	stop_kvm_vm
	sleep 5
	copy_vm_config
	virsh start $VMIMAGE > /dev/null
	if [ $? -ne 0 ]; then
		log_msg "error starting vm. Exiting."
		exit
	fi
	log_msg "started vm"
	sleep $WAIT_SECS_LONG
	# --- better to hardcode it in each VM config file
	#MAXVCPU=$(virsh vcpuinfo $VMIMAGE | grep VCPU | tail -1 | awk '{print $2}')
	#for (( i=0; i<=$MAXVCPU; i++ )); do
	#	virsh vcpupin $VMIMAGE $i $i > /dev/null
	#	if [ $? -ne 0 ]; then
	#		log_msg "error binding vcpu: $i. Exiting."
	#		exit
	#	fi
	#done
	#log_msg "vcpu binding done. waiting 30 seconds"
	#sleep $WAIT_SECS_SHORT
}

print_pt_error()
{
	log_msg "$1 table configuration failed for config $2...Exiting."
}

set_ept_replication()
{
	EPT_REPLICATION=$1
	log_msg "setting ePT replication to: $EPT_REPLICATION"
	echo $EPT_REPLICATION | sudo tee /sys/kernel/mm/mitosis/ept_replication_cache > /dev/null
	if [ $? -ne 0 ]; then
		print_pt_error "host" $EPT_REPLICATION
		exit
	fi
}

set_ept_node()
{
	EPT_NODE=$1
	log_msg "setting current ePT node: $EPT_NODE"
	echo $1 | sudo tee /sys/kernel/mm/mitosis/current_ept_node > /dev/null
	if [ $? -ne 0 ]; then
		print_pt_error "host" $EPT_NODE
		exit
	fi
}

set_ept_migration()
{
	log_msg "setting ePT migration to: $1"
	echo $1 | sudo tee /sys/kernel/mm/mitosis/ept_migration > /dev/null
	return;
	if [ $? -ne 0 ]; then
		echo "error setting EPT Migration to: $1"
		exit
	fi
}

reset_ept_configs()
{
	#set_ept_node 0
	log_msg "resetting ePT configs"
	set_ept_node -1
	set_ept_replication 0
	set_ept_migration 0
}

set_spt_replication()
{
	set_ept_replication $1
}

set_spt_node()
{
	set_ept_node $1
}

set_guest_replication()
{
	GPT_NODE=$1
	log_msg "setting current gPT node: $GPT_NODE"
	ssh $GUESTUSER@$GUESTADDR "echo $GPT_NODE | sudo tee /proc/sys/kernel/pgtable_replication" > /dev/null
	if [ $? -ne 0 ]; then
		print_pt_error "guest" $GPT_NODE
		exit
	fi
}

prepare_environment()
{
	# --- host configurations
	echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null
	echo $AUTONUMA | sudo tee /proc/sys/kernel/numa_balancing > /dev/null
	echo $THP | sudo tee /sys/kernel/mm/transparent_hugepage/enabled >/dev/null
	echo $THP | sudo tee /sys/kernel/mm/transparent_hugepage/defrag > /dev/null
	echo $REMOTE_THP_ALLOC | sudo tee /sys/kernel/mm/transparent_hugepage/remote_thp_alloc > /dev/null
	log_msg "dropped page cache, autoNUMA: $AUTONUMA, THP: $THP"

	# ---- boot-up the VM
	boot_prepare_kvm_vm
	# --- guest configurations
	ssh $GUESTUSER@$GUESTADDR "echo $AUTONUMA | sudo tee /proc/sys/kernel/numa_balancing" &> /dev/null
	STATUS1=$?
	ssh $GUESTUSER@$GUESTADDR "echo $THP | sudo tee /sys/kernel/mm/transparent_hugepage/enabled" &> /dev/null
	STATUS2=$?
	ssh $GUESTUSER@$GUESTADDR "echo $REMOTE_THP_ALLOC | sudo tee /sys/kernel/mm/transparent_hugepage/remote_thp_alloc" &> /dev/null
	STATUS3=$?
	if [ $STATUS1 -ne 0 ] || [ $STATUS2 -ne 0 ] || [ $STATUS3 -ne 0 ]; then
		log_msg "error configuring AutoNUMA or THP in the guest"
		exit
	else
		log_msg "configured AutoNUMA and THP in the Guest: $AUTONUMA & $THP"
		#log_msg "ready to execute $1...."
	fi
}

verify_kvm_pgtable_mode_ept()
{
	mode=$(sudo systool -vm kvm_intel | grep "ept " | awk '{print $3}')
	if [ $mode = "\"N\"" ]; then
		echo "error. KVM not running with 2D page tables."
		exit
	fi
}

verify_kvm_pgtable_mode_spt()
{
	mode=$(sudo systool -vm kvm_intel | grep "ept " | awk '{print $3}')
	if [ $mode = "\"Y\"" ]; then
		echo "error. KVM not running with shadow page tables."
		exit
	fi
}

disable_turboboost()
{
	#log_msg "disabling TurboBoost"
	if [ -e /sys/devices/system/cpu/intel_pstate/no_turbo ]; then
		echo 1 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo > /dev/null
		if [ $? -ne 0 ]; then
			echo "error disabling TurboBoost"
			exit
		fi
	fi
}

prepare_autonuma()
{
	CONFIG=$1
	if [[ $CONFIG == *A* ]]; then
		AUTONUMA=1
	else
		AUTONUMA=0
	fi
}

migrate_kvm_vm()
{
	TARGET=$1
	if [ $TARGET = "0" ] || [ $TARGET = "1" ]; then
		CPUS=$(numactl -H | grep "node $TARGET cpu" | cut -d " " -f 4- | tr ' ' ',')
	else
		echo "unknown target node - $TARGET"
		exit
	fi
	MAXVCPU=$(virsh vcpuinfo $VMIMAGE | grep VCPU | tail -1 | awk '{print $2}')
	for (( i=0; i<=$MAXVCPU; i++ )); do
		virsh vcpupin $VMIMAGE $i $CPUS > /dev/null
		if [ $? -ne 0 ]; then
			log_msg "error binding vcpu: $i. Exiting."
			exit
		fi
	done
	log_msg "migrated VM to target node: $TARGET"
}

fragment_memory_full()
{
	NR_THREADS=`grep '^processor' /proc/cpuinfo | sort -u | wc -l`
	NR_SECONDS=1800
	log_msg "fetching fragmentation files in memory. This will take a while..."
	cat $FRAGMENT_FILE1 > /dev/null &
	PID_1=$!
	cat $FRAGMENT_FILE2 > /dev/null &
	PID_2=$!
	wait $PID_1
	wait $PID_2
	log_msg "initiating random reads. This will take a while..."
	$TOOLS/bin/fragment.py $FRAGMENT_FILE1 $FRAGMENT_FILE2 $NR_SECONDS $NR_THREADS > /dev/null
}

prepare_canneal_dataset()
{
	SIZE=$1
	# --- check for non-empty dataset
	if [ ! -e $ROOT/datasets/canneal_$SIZE ] || [ ! -s $ROOT/datasets/canneal_$SIZE ]; then
		echo "$SIZE dataset not found for canneal. Preparing now..."
		$ROOT/datasets/prepare_canneal_datasets.sh $SIZE --no-verbose
		sync
		echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null
	fi
}

# --- mandatory system configs
disable_turboboost
