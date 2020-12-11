# Instructions
This directory contains various scripts to evaluate and reproduce artifact of the following paper:
"Fast Local Page-Tables for Virtualized NUMA Servers with vMitosis" [ASPLOS'21]

The following instructions describe how to run the experiments, process the logs from experimental data, where to find the output of your experiments and and how to compare your experimental results with reference data presented in the paper.

#### Contents
* run_figure-x.sh -  primary scripts to be invoked for running the experiments.
* run_guest_figure-x.sh  -- Automatically executed in the guest OS by run_figure-x.sh. Do not execute them directly.
* compile_report.sh  - To process the logs into CSV and PDF files, after running full or partial experiments.
* compile_ptdumps.sh - To generate Figure-2 CSV and PDF plots, run after collecting page-tables dumps via run_figure-2.sh.
* delete_ptdumps.sh - To delete row page-table dumps(which can be quite large). Delete after compiling the page-table dumps into CSV and PDF.
* plots/plot_figure-x.py - Automatically executed by compile_report.sh to generate PDF plots.
* helpers/helper_x.[sh|py] - Used in various places. Not to be executed directly.

#### Running the experiments
To run the main experiments of the paper, execute as:
```
$ vmitosis-asplos21-artifact/scripts/run_figure-x.sh  [replace x with figure number from the paper]
```
By default, each script runs all benchmarks and all configurations from the corresponding figure.

If you are interested in partial evaluation, and wish to run a particular benchmark with a particular configuration, execute as:
```
$ vmitosis-asplos21-artifact/scripts/run_figure-x.sh $BENCHMARK $CONFIG
```
For example:
```
$ vmitosis-asplos21-artifact/scripts/run_figure-1.sh memcached RRI
```
Pl. refer to the corresponding "run_figure-x.sh" files to check the names of supported benchmarks and configurations. In some cases, configuration names differ from the paper for simplicity. For example, THP configurations are prefixed with "T" (e.g., TLL, TRRI etc.) and THP + fragmentation configurations are prefixed with "TF" (e.g., TFLL, TFRRI etc.)

Note: Do not execute the "./run_guest_figure-x.sh" scripts directly. They are automatically invoked by the corresponding hypervisor script after configuring parameters that are important for the evaluation (e.g., replication, migration, THP etc.).

#### Compiling the report after collecting experimental data
Once all or partial experiments have completed, you can process the logs as:
```
$ vmitosis-asplos21-artifact/scripts/compile_report.sh
```
Processing the page-table dumps (Figure-2 in the paper) can consume significant time depending on the size of the dumps (about 30 minutes for each plot). Hence, they are not compiled in to the report by default. To compile them separately, run:
```
$ vmitosis-asplos21-artifact/scripts/compile_ptdumps.sh
```
If you want to compile page-table dumps along with the rest of the report, run:
```
$ vmitosis-asplos21-artifact/scripts/compile_report.sh --all
```

If a particular bars has been executed multiple times, the runtime will be averaged in the final report. However, experiments in Figure-2 and Figure-6 are not to be averaged. If case these experiments have been run multiple times, the first experiment based on the output of "find" command will be considered.

#### Finding the raw data from my experiments
Raw experimental logs are redirected to "vmitosis-asplos21-artifact/evaluation/measured/data/" by the run scripts.
Processed logs are redirected to "vmitosis-asplos21-artifact/evaluation/measured/processed/", which will contain CSV files for each figure.


#### Reference logs from the paper
Reference logs can be found in "vmitosis-asplos21-artifact/evaluation/referece/data/".
These logs will also be compiled by "compile_report.sh" along with the "measured" experiments that you run on your platform.


#### Comparing artifact evaluation with reference data
Once all or partial experiments have completed and you have compiled the results, an artifact evaluation report will be generated in "vmitosis-asplos21-artifact/vmitosis-artifact-report/". The report will contain CSV files and PDF plots for each figure. Copy this directory to your local machine and open the "vmitosis-artifact-report/vmitosis.html" page on your favourite web browser to view the graphs side-by-side.
