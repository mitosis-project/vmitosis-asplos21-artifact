#!/usr/bin/python3

import sys
import os
import csv
import shutil

benchmarks = dict()
curr_bench = ""
curr_config = ""
summary = []
avg_summary = []
benchmarks = []
global verbose
# --- directories that contain the data
dirs = ["data"]

# --- all workload configurations
configs = ["LL", "RL", "RLI", "LR", "LRI", "RR", "RRI", "RRIE", "RRIG", "RRIM", "TLL", "TRRI", "TRRIE", "TRRIG", "TRRIM", \
        "TFLL", "TFRRI", "TFRRIE", "TFRRIG", "TFRRIM",
        #"EL", "ELM", "ELA", "ELAM", "EI", "EIM", "ETL", "ETLM", "ETLA", "ETLAM", "ETI", "ETIM", \
        "F", "FM", "FA", "FAM", "I", "IM", "TF", "TFM", "TFA", "TFAM", "TI", "TIM", \
        "OF", "OFMP", "OFMF", "TOF", "TOFMP", "TOFMF"]
pretty_configs = ["LL", "RL", "RLI", "LR", "LRI", "RR", "RRI", "RRIE", "RRIG", "RRIM", "TLL", "TRRI", "TRRIE", "TRRIG", "TRRIM", \
        "TFLL", "TFRRI", "TFRRIE", "TFRRIG", "TFRRIM",
        #"EL", "ELM", "ELA", "ELAM", "EI", "EIM", "ETL", "ETLM", "ETLA", "ETLAM", "ETI", "ETIM", \
        "F", "FM", "FA", "FAM", "I", "IM", "TF", "TFM", "TFA", "TFAM", "TI", "TIM", \
        "OF", "OFMP", "OFMF", "TOF", "TOFMP", "TOFMF" ]
# --- all workloads
workloads = ["gups", "btree", "redis", "xsbench", "canneal", "memcached", "graph500"]
pretty_workloads = ["GUPS", "BTree", "Redis", "XSBench", "Canneal", "Memcached", "Graph500"]

def get_time_from_log(line):
    exec_time = int(line[line.find(":")+2:])
    return exec_time

def open_file(src, op):
    try:
        fd = open(src, op)
        if fd is None:
            raise ("Failed")
        return fd
    except:
        if verbose:
            #print("Unable to open %s in %s mode" %(src, op))
            pass
        return None

def print_workload_config(log):
    global curr_bench, curr_config

    for bench in workloads:
        if bench in log:
            curr_bench = bench
            break

    config = ""
    for tmp in configs:
            search_name = "-" + tmp + "-"
            if search_name in log:
                config =tmp
                break

    curr_config = config
    benchmarks.append(curr_bench)

def process_perf_log(path):
    fd = open_file(path, "r")
    if fd is None:
        print ('error opening log file')
        sys.exit(1)

    exec_time = -1
    while True:
        line = fd.readline()
        if not line:
            break
        if "Execution Time (seconds)" in line:
            exec_time = get_time_from_log(line)
        else:
            continue

    # --- log may be from an incomplete run and if so, ignore
    if exec_time == -1:
        return

    fd.close()
    output = {}
    output["bench"] = curr_bench
    output["config"] = curr_config
    output["time"] = exec_time
    summary.append(output)
 
def traverse_benchmark(path):
    # --- process THP and NON-THP configs separately
    for root,dir,files in os.walk(path):
        for filename in files:
            log = os.path.join(root, filename)
            print_workload_config(log)
            process_perf_log(log)

def pretty(name):
    if name in configs:
        index = configs.index(name)
        return pretty_configs[index]
    if name in workloads:
        index = workloads.index(name)
        return pretty_workloads[index]

    print ("ERROR converting \"%s\" to pretty" %name)
    sys.exit()

def dump_workload_config_average(output, bench, config, fd, fd2, absolute):
    time = 0
    count = 0
    for result in output:
        if result["bench"].lower() == bench.lower() and result["config"] == config:
            time += result["time"]
            line = "%s\t%s\t%d\n" % (pretty(bench), pretty(config), result["time"])
            fd2.write(line)
            count += 1

    if count == 0:
        #print("Data unavailable for %s %s" %(bench, config))
        return

    if absolute:
            time = int (time / count)
            line = "%s\t%s\t%d\n" % (pretty(bench), pretty(config), time)
            fd.write(line)
            output = {}
            output["bench"] = bench
            output["config"] = config
            output["time"] = time
            avg_summary.append(output)
            return

def process_all_runs(fd, fd2, output, absolute):
    global benchmarks, configs, curr_bench
    benchmarks = list(dict.fromkeys(benchmarks))

    if absolute:
        fd.write("Workload\tConfiguration\tTime\n")
        fd2.write("Workload\tConfiguration\tTime\n")
    else:
        fd.write("Workload\tConfiguration\tTime\n")
    for bench in workloads:
        curr_bench = bench
        for config in configs:
            printed = dump_workload_config_average(output, bench, config, fd, fd2, absolute)

def gen_csv_common(dst, src, fig_workloads, fig_configs):
    #print(dst)
    out_fd = open(dst, mode = 'w')
    writer = csv.writer(out_fd, delimiter='\t', quoting=csv.QUOTE_MINIMAL)
    for workload in fig_workloads:
        for config in fig_configs:
            for exp in avg_summary:
                if exp["bench"] == workload.lower() and exp["config"] == config:
                    writer.writerow([workload, pretty_configs[configs.index(config)], exp["time"]])

def gen_fig1_csv(root, src, target, plots):
    out_csv = os.path.join(root, ("evaluation/%s/processed/figure-1.csv" %(target)))
    workloads = ["GUPS", "BTree", "Redis", "XSBench", "Memcached", "Canneal"]
    configs = ["LL", "LR", "RL", "RR", "LRI", "RLI", "RRI"]
    gen_csv_common(out_csv, src, workloads, configs)
    if os.path.exists(out_csv):
        out_pdf = os.path.join(root, ("evaluation/%s/processed/figure-1.pdf" %(target)))
        plotgen = os.path.join(plots, "plot_figure-1.py")
        os.system("%s %s %s" %(plotgen, out_csv, out_pdf))
        print(out_pdf)

def gen_fig3_csv(root, src, target, plots):
    # --- Figure-3a
    out_csv = os.path.join(root, ("evaluation/%s/processed/figure-3a.csv" %(target)))
    workloads = ["GUPS", "BTree", "Redis", "XSBench", "Memcached", "Canneal"]
    configs = ["LL", "RRI", "RRIE", "RRIG", "RRIM"]
    gen_csv_common(out_csv, src, workloads, configs)
    if os.path.exists(out_csv):
        out_pdf = os.path.join(root, ("evaluation/%s/processed/figure-3a.pdf" %(target)))
        plotgen = os.path.join(plots, "plot_figure-3a.py")
        os.system("%s %s %s" %(plotgen, out_csv, out_pdf))
        print(out_pdf)
    # --- Figure-3b
    out_csv = os.path.join(root, ("evaluation/%s/processed/figure-3b.csv" %(target)))
    workloads = ["GUPS", "BTree", "Redis", "XSBench", "Memcached", "Canneal"]
    configs = ["TLL", "TRRI", "TRRIE", "TRRIG", "TRRIM"]
    gen_csv_common(out_csv, src, workloads, configs)
    if os.path.exists(out_csv):
        out_pdf = os.path.join(root, ("evaluation/%s/processed/figure-3b.pdf" %(target)))
        plotgen = os.path.join(plots, "plot_figure-3b.py")
        os.system("%s %s %s" %(plotgen, out_csv, out_pdf))
        print(out_pdf)
    # --- Figure-3c
    out_csv = os.path.join(root, ("evaluation/%s/processed/figure-3c.csv" %(target)))
    workloads = ["GUPS", "BTree", "Redis", "XSBench", "Memcached", "Canneal"]
    configs = ["TFLL", "TFRRI", "TFRRIE", "TFRRIG", "TFRRIM"]
    gen_csv_common(out_csv, src, workloads, configs)
    if os.path.exists(out_csv):
        out_pdf = os.path.join(root, ("evaluation/%s/processed/figure-3c.pdf" %(target)))
        plotgen = os.path.join(plots, "plot_figure-3c.py")
        os.system("%s %s %s" %(plotgen, out_csv, out_pdf))
        print(out_pdf)

def gen_fig4_csv(root, src, target, plots):
    # --- Figure-4a
    out_csv = os.path.join(root, ("evaluation/%s/processed/figure-4a.csv" %(target)))
    workloads = ["Memcached", "XSBench", "Graph500", "Canneal"]
    configs = ["F", "FM", "FA", "FAM", "I", "IM"]
    gen_csv_common(out_csv, src, workloads, configs)
    if os.path.exists(out_csv):
        out_pdf = os.path.join(root, ("evaluation/%s/processed/figure-4a.pdf" %(target)))
        plotgen = os.path.join(plots, "plot_figure-4a.py")
        os.system("%s %s %s" %(plotgen, out_csv, out_pdf))
        print(out_pdf)
    # --- Figure-4b
    out_csv = os.path.join(root, ("evaluation/%s/processed/figure-4b.csv" %(target)))
    workloads = ["Memcached", "XSBench", "Graph500", "Canneal"]
    configs = ["TF", "TFM", "TFA", "TFAM", "TI", "TIM"]
    gen_csv_common(out_csv, src, workloads, configs)
    if os.path.exists(out_csv):
        out_pdf = os.path.join(root, ("evaluation/%s/processed/figure-4b.pdf" %(target)))
        plotgen = os.path.join(plots, "plot_figure-4b.py")
        os.system("%s %s %s" %(plotgen, out_csv, out_pdf))
        print(out_pdf)

def gen_fig5_csv(root, src, target, plots):
    # --- Figure-5a
    out_csv = os.path.join(root, ("evaluation/%s/processed/figure-5a.csv" %(target)))
    workloads = ["Memcached", "XSBench", "Graph500", "Canneal"]
    configs = ["OF", "OFMP", "OFMF"]
    gen_csv_common(out_csv, src, workloads, configs)
    if os.path.exists(out_csv):
        out_pdf = os.path.join(root, ("evaluation/%s/processed/figure-5a.pdf" %(target)))
        plotgen = os.path.join(plots, "plot_figure-5a.py")
        os.system("%s %s %s" %(plotgen, out_csv, out_pdf))
        print(out_pdf)
    # --- Figure-5b
    out_csv = os.path.join(root, ("evaluation/%s/processed/figure-5b.csv" %(target)))
    workloads = ["Memcached", "XSBench", "Graph500", "Canneal"]
    configs = ["TOF", "TOFMP", "TOFMF"]
    gen_csv_common(out_csv, src, workloads, configs)
    if os.path.exists(out_csv):
        out_pdf = os.path.join(root, ("evaluation/%s/processed/figure-5b.pdf" %(target)))
        plotgen = os.path.join(plots, "plot_figure-5b.py")
        os.system("%s %s %s" %(plotgen, out_csv, out_pdf))
        print(out_pdf)

def gen_fig6_csv(root, src, target, plots):
    script = os.path.join(root, "scripts/helpers/helper_figure-6.sh")
    os.system(script)
    out_csv = os.path.join(root, ("evaluation/%s/processed/figure-6a.csv" %(target)))
    if os.path.exists(out_csv):
        out_pdf = os.path.join(root, ("evaluation/%s/processed/figure-6a.pdf" %(target)))
        plotgen = os.path.join(plots, "plot_figure-6a.py")
        os.system("%s %s %s" %(plotgen, out_csv, out_pdf))
        print(out_pdf)
    out_csv = os.path.join(root, ("evaluation/%s/processed/figure-6b.csv" %(target)))
    if os.path.exists(out_csv):
        out_pdf = os.path.join(root, ("evaluation/%s/processed/figure-6b.pdf" %(target)))
        plotgen = os.path.join(plots, "plot_figure-6b.py")
        print(out_pdf)
        os.system("%s %s %s" %(plotgen, out_csv, out_pdf))

def gen_fig2_csv(root, target):
    src = os.path.join(root, "scripts/compile_ptdumps.sh %s" %(target))
    os.system(src)

def copy_final_graphs(root, target):
    dst = os.path.join(root, ("vmitosis-artifact-report/%s/" %(target)))
    if os.path.exists(dst):
        shutil.rmtree(dst)
    src = os.path.join(root, ("evaluation/%s/processed/" %(target)))
    if os.path.exists(src):
        shutil.copytree(src, dst)

if __name__=="__main__":
    process_ptdumps = False
    if len(sys.argv) == 2 and sys.argv[1] == "--all":
        process_ptdumps = True
    for target in ["measured", "reference"]:
        # --- reset
        summary = []
        avg_summary = []
        root = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
        plots = os.path.join(root, "scripts/plots")
        datadir = os.path.join(root, ("evaluation/%s/data" %(target)))
        out_dir = os.path.join(root, ("evaluation/%s/processed/" %(target)))
        if not os.path.exists(out_dir):
            os.makedirs(out_dir)

        for benchmark in workloads:
                path = os.path.join(datadir, benchmark)
                traverse_benchmark(path)

        avg_src = os.path.join(out_dir, "avg.csv")
        all_src = os.path.join(out_dir, "all.csv")
        #print(avg_src)
        #print(all_src)
        fd_avg = open_file(avg_src, "w")
        fd_all = open_file(all_src, "w")
        if fd_avg is None or fd_all is None:
                print("ERROR creating output files")
                sys.exit()

        # --- process normalized data
        process_all_runs(fd_avg, fd_all, summary, True)
        fd_avg.close()
        fd_all.close()
        gen_fig1_csv(root, avg_summary, target, plots)
        if process_ptdumps:
            gen_fig2_csv(root, target)
        gen_fig3_csv(root, avg_summary, target, plots)
        gen_fig4_csv(root, avg_summary, target, plots)
        gen_fig5_csv(root, avg_summary, target, plots)
        gen_fig6_csv(root, avg_summary, target, plots)
        copy_final_graphs(root, target)
