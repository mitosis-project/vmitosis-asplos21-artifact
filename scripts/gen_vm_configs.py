#!/usr/bin/python3

import xml.etree.ElementTree as ET
import os
import sys
import multiprocessing
import subprocess
import psutil

KERNEL_MITOSIS='/boot/vmlinuz-4.17.0-mitosis+'
INITRD_MITOSIS='/boot/initrd.img-4.17.0-mitosis+'
CMDLINE_MITOSIS='console=ttyS0 root=/dev/sda1'

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


nr_cpus = multiprocessing.cpu_count()
nr_sockets =  int(subprocess.check_output('cat /proc/cpuinfo | grep "physical id" \
                | sort -u | wc -l', shell=True))
# --- XML helper
def remove_tag(parent, child):
    for element in list(parent):
        if element.tag == child:
            parent.remove(element)

# --- XML helper
def new_element(parent, tag, text):
    attrib = {}
    element = parent.makeelement(tag, attrib)
    parent.append(element)
    element.text = text
    return element


# For thin VMs, return the number of CPUs from a single socket
# For wide VMs, return the number of total CPUs present inthe system
def get_vcpu_count(config):
    if config == 'thin':
        return int(nr_cpus/nr_sockets)

    return int(nr_cpus)


# For thin VM, return memory size of a single socket
# For wide VM, return total system memory size
def get_memory_size(config):
    mem = int(psutil.virtual_memory().total)/1024 # --- converted to KB
    if config == 'thin':
        paper = 53092096 # --- used in the paper
        system = int(mem * 0.90) / nr_sockets
        return int(min(system, paper))

    return int(mem * 0.95) # --- 95% of total memory


# -- host physical bits need to be set for VMs greate than 1TB.
# Add them anyway for simplicity.
def test_and_set_hpb(tag):
    machine = tag.get('machine')
    if '-hpb' not in machine:
        tag.set('machine', machine+'-hpb')


# Rewrite to boot with mitosis kernel image
def rewrite_os(tag):
    #new = new_element(tag_os, 'kernel', '/boot/vmlinuz-4.17.0-mitosis+')
    addKernel = True
    addInitrd = True
    addCmdline = True
    for child in tag:
        if child.tag == 'kernel':
            child.text = KERNEL_MITOSIS
            addKernel = False
        if child.tag == 'initrd':
            child.text = INITRD_MITOSIS
            addInitrd = False
        if child.tag == 'cmdline':
            child.text = CMDLINE_MITOSIS
            addCmdline = False
        if child.tag == 'type':
            test_and_set_hpb(child)

    if addKernel:
        newtag = new_element(tag, 'kernel', KERNEL_MITOSIS)
    if addInitrd:
        newtag = new_element(tag, 'initrd', INITRD_MITOSIS)
    if addCmdline:
        newtag = new_element(tag, 'cmdline', CMDLINE_MITOSIS)

# Bind vCPUs 1:1: to pCPUs
def add_vcpu_numa_tune(config, main, child):
    nr_cpus = int(child.text)
    pos = list(main).index(child)
    remove_tag(main, 'cputune')
    new = ET.Element('cputune')
    main.insert(pos + 1, new)
    cpus = [i for i in range(nr_cpus)]
    if config == 'thin':
            out = subprocess.check_output('numactl -H | grep "node 0 cpus" | cut -d " " -f4-', shell  = True)
            out = str(out, 'utf-8')
            cpus = out.split()

    for i in range(nr_cpus):
        newtag = ET.SubElement(new, 'vcpupin')
        newtag.set('cpuset', str(cpus[i]))
        newtag.set('vcpu', str(i))

    if config != 'numa-visible':
        return

    new = ET.Element('numatune')
    remove_tag(main, 'numatune')
    main.insert(pos + 2, new)
    cpus = [i for i in range(nr_sockets)]
    for i in range(nr_sockets):
        newtag = ET.SubElement(new, 'memnode')
        newtag.set('cellid' , str(i))
        newtag.set('nodeset', str(i))
        newtag.set('mode', 'preferred')

# NUMA cells are required only for a NUMA-visible VM.
# Remove from other configs, if present
def add_numa_cells(config, main, child):
    remove_tag(child, 'numa')
    if config != 'numa-visible':
        return

    numa = ET.SubElement(child, 'numa')
    for i in range(nr_sockets):
        # --- get the list of cpus for the current socket
        cmd = 'numactl -H | grep "node %d cpus" | cut -d " " -f4-' %(i)
        cpus = subprocess.check_output(cmd, shell = True)
        # --- replace space by commas
        cpus = str(cpus, 'utf-8').strip().replace(' ', ',')
        # -- add a cell tag with 4 attributes
        cell = ET.SubElement(numa, 'cell')
        cell.set('id', str(i))
        cell.set('memory', str(int(get_memory_size(config)/nr_sockets)))
        cell.set('cpus', cpus)
        cell.set('unit', 'KiB')

# -- the following tags are important
# 1. os: update to booth VM with mitosis kernel
# 2. vcpu: number of vcpus for the VM
# 3. memory: amount of memory for the VM -- in KiB
# 4. vcputune: add after the vcpu tag, bind with a 1:1 mapping
# 5. numa: add inside cpu tag to mirror host NUMA topology inside guest
def rewrite_config(config):
    vmconfigs = os.path.join(root, 'vmconfigs')
    src = os.path.join(vmconfigs, config + '.xml')
    tree = ET.parse(src)
    main = tree.getroot()
    for child in main:
        if child.tag == 'os':
            rewrite_os(child)
        if child.tag == 'vcpu':
            child.text = str(get_vcpu_count(config))
            add_vcpu_numa_tune(config, main, child)
        if child.tag == 'memory' or child.tag == 'currentMemory':
            child.text = str(get_memory_size(config))
        if child.tag == 'cpu':
            add_numa_cells(config, main, child)

    tree.write(src)

def dump_vm_config_template(vm, configs):
    print('dumping template XML from %s\'s current config...' %vm)
    cmd = 'virsh dumpxml %s' %vm
    dst = os.path.join(root, 'vmconfigs/')
    if not os.path.exists(dst):
        os.makedirs(dst)
    dst = os.path.join(dst, 'template.xml')
    cmd += '> %s' %dst
    os.system(cmd)
    # -- copy into three files
    src = dst
    for config in configs:
        dst = os.path.join(root, 'vmconfigs')
        dst = os.path.join(dst, config + '.xml')
        cmd = 'cp %s %s '%(src, dst)
        os.system(cmd)
        #print(cmd)

if __name__ == '__main__':
    parent_vm = 'mirage'
    if len(sys.argv) == 2:
        parent_vm = sys.argv[1]

    configs = ['thin', 'numa-visible', 'numa-oblivious']
    dump_vm_config_template(parent_vm, configs)
    for config in configs:
        print('re-writing: ' + config+'.xml')
        rewrite_config(config)

    # --- prettify XML files
    for config in configs:
        vmconfigs = os.path.join(root, 'vmconfigs')
        src = os.path.join(vmconfigs, config + '.xml')
        cmd = 'xmllint --format %s' %src
        tmp = 'tmp.xml'
        cmd += ' > %s' %tmp
        os.system(cmd)
        os.rename(tmp, src)
