vMitosis ASPLOS'21 Artifact Evaluation
=====================================

This repository contains scripts and other supplementary material
for the ASPLOS'21 artifact evaluation of the paper **Fast Local Page-Tables
for Virtualized NUMA Servers with vMitosis** by Ashish Panwar, Reto Achermann,
Arkaprava Basu, Abhishek Bhattacharjee, K. Gopinath and Jayneel Gandhi.

The scripts can be used to reproduce the figures in the paper.


Authors
-------
 
 * Ashish Panwar (Indian Institute of Science)
 * Reto Achermann (ETH Zurich and University of British Columbia)
 * Arkaprava Basu (Indian Institute of Science)
 * Abhishek Bhattacharjee (Yale University)
 * K. Gopinath (Indian Institute of Science)
 * Jayneel Gandhi (VMware Research)


License
-------

See LICENSE file.


Directory Structure
-------------------

 * `precompiled` contains the downloaded binaries
 * `build` contains the locally compiled binaries
 * `sources` contains the source code of the binaries
 * `datasets` contains the datasets required for the binaries
 * `scripts` contains scripts to run the experiments
 * `bin` points to the used binaries for the evaluation (you can use 
   `scripts/toggle_build.sh` to switch between precompiled and locally 
   compined binaries)


Hardware Dependencies
---------------------

Some of the workingset sizes of the workloads are hardcoded in the binaries.
To run them, you need to have a multi-socket machine with at least 384GB of 
memory *per* NUMA node. e.g. 4 socket Intel Xeon Gold 6252 with 24 cores (48
hardware threads) and 384GB memory per-socket (1.5TB total memory).


Software Dependencies
---------------------

The scripts, compilation and binaries are tested on Ubuntu 18.04 LTS. Other 
Linux distributions may work, but are not tested.

In addition to the packages shipped with Ubuntu 18.04 LTS the following 
packets are required:

```
$ sudo apt-get install build-essential libncurses-dev \
                     bison flex libssl-dev libelf-dev \
                     libnuma-dev python3 python3 python3-pip \
                     python3-matplotlib python3-numpy \
                     git wget kernel-package fakeroot ccache \
                     libncurses5-dev wget pandoc libevent-dev \
                     libreadline-dev python3-setuptools \
		     qemu-kvm libvirt-bin bridge-utils virtinst virt-manager
```                       

In addition the following python libraries, installed with pip

```
$ pip3 install wheel
$ pip3 install zenodo-get

```

**Docker** There is a docker image which you can use to compile. You can do
`make docker-shell` to obtain a shell in the docker container, or just to 
compile everything type `make docker-compile`.


Obtaining Pre-Compiled Binaries
-------------------------------

This repository does not contain any source code or binaries. There are scripts
which download the pre-compiled binaries, or source code for compilation.

**Obtaining Pre-Compiled Binaries**

To obtain the pre-compiled binaries execute:

```
$ vmitosis-asplos21-artifact/scripts/download_binaries.sh
```
The pre-compiled binaries are available on [Zenodo.org](https://zenodo.org/record/3558908). 
You can download them manually and place them in the `precompiled` directory.

There are several binaries available on Zenodo:

 * `bench_*` are the benchmarks used in the paper
 * `page_table_dump/numactl/` are helper utilities.
 * `linux-*.deb` are the linux kernel image and headers with vMitosis modifications.


Obtaining Source Code and Compile
---------------------------------

If you don't want to compile from scratch, you can skip this section.

The source code for the Linux kernel and evaluated worloads are available on 
GitHub. To obtain the source code you can initialize the corresponding git 
submodules. **Note: the repositories are private at this moment, as they are not
ready for public release.**

```
$ git submodule init
$ git submodule update
```

To compile everything just type `make`

To compile the different binaries individually, type:

 * vMitosis Linux Kernel:  `make vmitosis-linux`
 * vMitosis numactl: `make vmitosis-numactl`
 * BTree: `make btree`
 * Canneal: `make canneal`
 * Graph500: `make graph500`
 * GUPS: `make gups`
 * Redis: `make redis`
 * XSBench: `make xsbench`
 * memcached: `make memcached`


Install and Configure a Virtual Machine
---------------------------------------

Install a virtual machine using command line (choose ssh-server when prompted for package installation):

```
virt-install --name vmitosis --ram 4096 --disk path=/home/ashish/vmitosis.qcow2,size=50 --vcpus 4 --os-type linux --os-variant generic --network bridge=virbr0 --graphics none --console pty,target_type=serial --location 'http://archive.ubuntu.com/ubuntu/dists/bionic/main/installer-amd64/' --extra-args 'console=ttyS0,115200n8 serial'
```

Dump the VM configuration file somewhere as follows:
```
$ virsh dumpxml vmitosis > $HOME/config.xml
```

**TODO-1:** Use config.xml to create three VM configurations and place all XML files in "vmitosis-asplos21-artifact/vmconfigs":
1. NUMA-visible wide VM, using all CPUs and memory (XML file name: "numa-visible.xml")
2. NUMA-oblivious wide VM, using all CPUs and memory( XML file name:  "numa-oblivious.xml")
3. NUMA-oblivious thin VM , using CPUs and memory from NUMA socket 0 (XML file name: "small-singlesocket.xml")

The following tags need to be updated while configuring the VM:
```
1. <vcpu> </vcpu> -- to update the number of CPUs to be allocated to the VM
2. <memory> </memory> -- to update the amount of memory to be allocated to the VM
3. <cputune> <cputune> -- to bind vCPUs to pCPUs
4. <numatune> </numatune> -- to setup the number of guest NUMA nodes
5. <cpu><numa> </numa></cpu> -- to bind vCPUs to guest NUMA nodes
```

The guest OS needs to be booted with vmitosis kernel image. The same can also be configured with "os" tag
in the XML files as follows:
```
  <os>
    <type arch='x86_64' machine='pc-i440fx-eoan-hpb'>hvm</type>
    <kernel>/boot/vmlinuz-4.17.0-lptr+</kernel>
    <initrd>/boot/initrd.img-4.17.0-lptr+</initrd>
    <cmdline>console=ttyS0 root=/dev/sda1</cmdline>
    <boot dev='hd'/>
  </os>
```
Refer to "vmitosis-asplos21-artifact/vmconfigs/samples/" for VM configurations used in the paper.

Once all three configuration files are ready, setup passwordless authentication between the host and VM (both ways).
This can be done, for example, by adding the RSA key of the host user to "$HOME/.ssh/authorized_keys"
in the guest and vice-versa.

**TODO-2:** Update the ip address and user names of the host machine and VM in "vmitosis-asplos21-artifact/scripts/configs.sh"
in the following fields:
```
GUESTUSER
GUESTADDR
HOSTUSER
HOSTADDR
```

**TODO-3:** Configure the guest OS to auto mount the "vmitosis-asplos21-artifact" repository on every boot in the same path as it is in the host using a network file system. An example '/etc/fstab' entry that uses SSHFS is shown below (assuming that the artifact is placed in the home directory of the user):
```
ashish@10.202.4.119:/home/ashish/vmitosis-asplos21-artifact /home/ashish/vmitosis-asplos21-artifact fuse.sshfs identityfile=/home/ashish/.ssh/id_rsa,allow_other,default_permissions 0 0
```

Evaluation Preparation
----------------------

To run the evaluations of the paper, you need a suitable machine (see Hardware 
Dependencies) and you need to boot your machine with the vMitosis-Linux you
downloaded or compiled yourself. Both, the kernel image and the headers!.

To install the kernel module for page-table dumping you need to execute:
```
$ make install lkml
```

It's best to compile it on the machine runnig vMitosis-Linux. 
```
$ make vmitosis-page-table-dump
```


Deploying
---------

Just clone the artifact on the machine you want to run it on. 

**For deploying on a remote machine only.**

To deploy the binaries and scripts on a remote machine, just clone the 
repository locally, and specify the target host-name you want to run the
artifact on in `./scripts/site_config.sh`. Then run the following script 
locally. 

```
$ vmitosis-asplos21-artifact/scripts/deploy.sh
```

Preparing Datasets
------------------

The "canneal" workload requires a dataset to run (small for Figure-1 and Figure-3, large
for Figure-4 and Figure-5). Scripts to download or generate the datasets are placed in
`datasets/`. These datasets require approximately 65GB of disk space. Generate datasets as:

```
$ vmitosis-asplos21-artifact/datasets/prepare_canneal_datasets.sh [small|large]
```

If dataset is not present, it will be generated automatically while executing the experiment.


Running the Experiments
-----------------------

Before you start running the experiments, make sure you fill in the site
configuration file `site-config.sh`.

To run all experiments, execute (this may take a while...)

```
$ vmitosis-asplos21-artifact/scripts/run_all.sh
```

To run the experiments for a single figure, do:

 * Figure-1 - `vmitosis-asplos21-artifact/scripts/run_figure-1.sh`
 * Figure-2 - `vmitosis-asplos21-artifact/scripts/run_figure-2.sh`
 * Figure-3 - `vmitosis-asplos21-artifact/scripts/run_figure-3.sh`
 * Figure-4 - `vmitosis-asplos21-artifact/scripts/run_figure-4.sh`
 * Figure-5 - `vmitosis-asplos21-artifact/scripts/run_figure-5.sh`
 * Figure-6 - `vmitosis-asplos21-artifact/scripts/run_figure-6.sh`

You can also execute each bar of the figures separately by supplying the
benchmark and configuration name as follows:

```
$ vmitosis-asplos21-artifact/scripts/run_figure-1.sh $BENCHMARK $CONFIG
```
Naming conventions for arguments:

 * Use "small letters" for benchmark name (e.g., btree, xsbench).
 * Use "CAPITAL LETTERS" for configuration name (e.g., LL, RRI).

Refer to the corresponding scripts for the list of supported benchmarks
and configurations.

All output logs will be redirected to "evaluation/measured/data/".


Prepare the Report
-----------------------

When you collected all or partial experimental data, you can compile them
to compare against the reference data shown in the paper:

```
$ vmitosis-asplos21-artifact/scripts/compile_report.sh
```

All PDF plots and CSV files from measured and reference data will be redirected to
"vmitosis-artifact-report/".

Copy the report directory to your desktop machine and open "vmitosis-artifact-report/vmitosis.html"
in your browser to view the reference and measured plots side by side.


Collecting Experiment Data
--------------------------

In case you used the deploy script, you can execute
```
$ vmitosis-asplos21-artifact/scripts/collect-report.sh
```
To copy the report from the remote machine to your local one.

Paper Citation
--------------

Ashish Panwar, Reto Achermann, Arkaprava Basu, Abhishek Bhattacharjee,
K. Gopinath and Jayneel Gandhi. 2021. Fast Local Page-Tables for Virtualized
NUMA Servers with vMitosis. In Proceedings of the Twenty-Sixth International
Conference on Architectural Support for Programming Languages and Operating Systems
(ASPLOS ’21), Virtual.
