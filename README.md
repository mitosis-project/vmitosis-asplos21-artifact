vMitosis ASPLOS'21 Artifact Evaluation
=====================================

This repository contains scripts and other supplementary material
for the ASPLOS'21 artifact evaluation of the paper **Fast Local Page-Tables
for Virtualized NUMA Servers** by Ashish Panwar, Reto Achermann,
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
sudo apt-get install build-essential libncurses-dev \
                     bison flex libssl-dev libelf-dev \
                     libnuma-dev python3 python3 python3-pip \
                     python3-matplotlib python3-numpy \
                     git wget kernel-package fakeroot ccache \
                     libncurses5-dev wget pandoc libevent-dev \
                     libreadline-dev python3-setuptools
```                       

In addition the following python libraries, installed with pip

```
pip3 install wheel
pip3 install zenodo-get

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
./scripts/download_binaries.sh
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
git submodule init
git submodule update
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


Evaluation Preparation
----------------------

To run the evaluations of the paper, you need a suitable machine (see Hardware 
Dependencies) and you need to boot your machine with the Mitosis-Linux you
downloaded or compiled yourself. Both, the kernel image and the headers!.

To install the kernel module for page-table dumping you need to execute:
```
make install lkml
```

It's best to compile it on the machine runnig Mitosis-Linux. 
```
make vmitosis-page-table-dump
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
./scripts/deploy.sh
```

Preparing Datasets
------------------

The "canneal" workload requires a dataset to run (small for Figure-1 and Figure-3, large
for Figure-4 and Figure-5). Scripts to download or generate the datasets are placed in
`datasets/`. These datasets require approximately 65GB of disk space. Generate datasets as:

```
datasets/prepare_canneal_datasets.sh [small|large]
```

If dataset is not present, it will be generated automatically while executing the experiment.


Running the Experiments
-----------------------

Before you start running the experiments, make sure you fill in the site
configuration file `site-config.sh`.

To run all experiments, execute (this may take a while...)

```
scripts/run_all.sh
```

To run the experiments for a single figure, do:

 * Figure-1 - `./scripts/run_figure-1.sh`
 * Figure-2 - `./scripts/run_figure-2.sh`
 * Figure-3 - `./scripts/run_figure-3.sh`
 * Figure-4 - `./scripts/run_figure-4.sh`
 * Figure-5 - `./scripts/run_figure-5.sh`
 * Figure-6 - `./scripts/run_figure-6.sh`

You can also execute each bar of the figures separately by supplying the
benchmark and configuration name as follows:

```
./scripts/run_figure-1.sh $BENCHMARK $CONFIG
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
./scripts/compile_report.sh
```

All PDF plots and CSV files from measured and reference data will be redirected to
"vmitosis-artifact-report/".

Copy the report directory to your desktop machine and open "vmitosis-artifact-report/vmitosis.html"
in your browser to view the reference and measured plots side by side.


Collecting Experiment Data
--------------------------

In case you used the deploy script, you can execute
```
./scripts/collect-report.sh
```
To copy the report from the remote machine to your local one.

Paper Citation
--------------

Ashish Panwar, Reto Achermann, Arkaprava Basu, Abhishek Bhattacharjee,
K. Gopinath and Jayneel Gandhi. 2021. Fast Local Page-Tables for Virtualized
NUMA Servers with vMitosis. In Proceedings of the Twenty-Sixth International
Conference on Architectural Support for Programming Languages and Operating Systems
(ASPLOS ’21), Virtual.
