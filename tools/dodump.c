#include <stdio.h>
#include <fcntl.h>      /* open */ 
#include <unistd.h>     /* exit */
#include <sys/ioctl.h>  /* ioctl */
#include <sys/mman.h>  /* mlock */
#include <stdlib.h>
#include <limits.h>
#include <numa.h>
#include <signal.h>
#include <errno.h>

#include <ptdump.h>


#define BUF_SIZE_BITS 24
#define PARAM(ptr, sz) ((unsigned long) sz << 48 | (unsigned long)ptr)
#define PARAM_GET_PTR(p) (void *)(p & 0xffffffffffff)
#define PARAM_GET_BITS(p) (p >> 48)

#define PTABLE_BASE_MASK(x) ((x) & 0xfffffffff000UL)

void dump_numa_info(struct nodemap *map, FILE *opt_file_out)
{
    int i;

    fprintf(opt_file_out, "<numamap>\n");
    for (i = 0; i < map->nr_nodes; i++) {
        fprintf(opt_file_out, "%d %ld %ld\n", map->node[i].id,
            map->node[i].node_start_pfn, map->node[i].node_end_pfn);
    }
    fprintf(opt_file_out, "</numamap>\n");
}


int main(int argc, char *argv[])
{
    long c;

    if (argc < 3) {
        printf("Usage: dodump <pid> <0|1> [outfile]\n");
        return -1;
    }
    
    long pid = strtol(argv[1], NULL, 10);

    if (pid == 0) {
        pid = getpid();
    }

    long pgtables_type = strtol(argv[2], NULL, 10);
    if (!(pgtables_type == PTDUMP_REGULAR || pgtables_type == PTDUMP_ePT)) {
        printf("Please enter a valid ptables identifier (argument #2). Valid values:\n");
        printf("0\tHOST_PTABLES\n1\tEPT_PTABLES\n");
        exit(0);
    }

    FILE *opt_file_out = NULL;
    if (argc == 4) {
        opt_file_out = fopen(argv[3], "a");
    }

    if (opt_file_out == NULL) {
        opt_file_out = stdout;
    }
    
    int f = open("/proc/ptdump", 0);
    if (f < 0) {
        printf ("Can't open device file: %s\n", "/proc/ptdump");
        return -1;
    }

    c = ioctl(f, PTDUMP_IOCTL_PGTABLES_TYPE, pgtables_type);
    if (c < 0) {
        printf("Error while setting pgtables_type\n");
        return -1;

    }

    struct nodemap *numa_map = calloc(1, sizeof(*numa_map));
    if (!numa_map)
        return -ENOMEM;

    c = ioctl(f, PTDUMP_IOCTL_MKCMD(PTDUMP_IOCTL_NUMA_NODEMAP, 0, 256),
            PTDUMP_IOCTL_MKARGBUF(numa_map, 0));
    if (c < 0) {
        printf("Error while fetching numa node map\n");
        free(numa_map);
        return -1;
    }
    dump_numa_info(numa_map, opt_file_out);
    free(numa_map);

    struct ptdump *result = calloc(1, sizeof(*result));
    if (!result) {
        return -1;
    }
    
    mlockall(MCL_CURRENT | MCL_FUTURE | MCL_ONFAULT); 

    while(1) {
        /* check if the pid still exists before collecting dump.
         * This is racy as a new process may acquire the same pid
         * but the chances of that happenning for us is really really low .
         */
        if (kill(pid, 0) && errno == ESRCH)
            break;

        result->processid = pid;

        c = ioctl(f, PTDUMP_IOCTL_MKCMD(PTDUMP_IOCTL_CMD_DUMP, 0, 256), 
                     PTDUMP_IOCTL_MKARGBUF(result, 0));
        if (c < 0) {
            fprintf(opt_file_out,"<ptdump process=\"%ld\" error=\"%ld\"></ptdump>\n", pid, c);
            goto wait_and_dump_next;
        }
        fprintf(opt_file_out,"<ptdump process=\"%ld\" count=\"%zu\">\n", pid, result->num_tables);
        fprintf(opt_file_out,"<numamigrations>%zu</numamigrations>\n", result->num_migrations);
        for (int level = 5; level > 0; level--) {
            for (unsigned long i = 0; i < result->num_tables; i++) {
                if (PTDUMP_TABLE_EXLEVEL(result->table[i].base) != level) {
                    continue;
                }
                fprintf(opt_file_out, "<level%d b=\"%lx\">", level, PTABLE_BASE_MASK(result->table[i].base) >> 12);
                
                for (int j = 0; j < 512; j++) {
                    char *prefix = "";

                    /* check if the entry is valid */
                    if (!(result->table[i].entries[j] & 0x1)) {
                        /* entry is not valid, check if the global bit is set */
                        if (!(result->table[i].entries[j] & (0x1 << 8))) {
                            /* global bit is not set, continue */
                            fprintf(opt_file_out, "0 ");
                            continue;
                        }
                        /* set the prefix to a NUMA entry */
                        prefix = "n";
                    }

                    /* case distinction on the level */
                    switch(level) {
                        case 1:
                            if (!(result->table[i].entries[j] & (0x1UL << 63))) {
                                fprintf(opt_file_out, "%sx%lx ", prefix, PTABLE_BASE_MASK(result->table[i].entries[j]) >> 12);
                            } else {
                                fprintf(opt_file_out, "%s%lx ", prefix, PTABLE_BASE_MASK(result->table[i].entries[j]) >> 12);
                            }
                            break;
                        case 2:
                            if (!(result->table[i].entries[j] & (0x1 << 7))) {
                                fprintf(opt_file_out, "%sp%lx ", prefix, PTABLE_BASE_MASK(result->table[i].entries[j]) >> 12);
                            } else if (!(result->table[i].entries[j] & (0x1UL << 63))) {
                                fprintf(opt_file_out, "%sx%lx ", prefix, PTABLE_BASE_MASK(result->table[i].entries[j]) >> 21);
                            } else {
                                fprintf(opt_file_out, "%s%lx ", prefix, PTABLE_BASE_MASK(result->table[i].entries[j]) >> 21);
                            }
                           
                            break;
                        case 3:
                            if (!(result->table[i].entries[j] & 0x1)) {
                                fprintf(opt_file_out, "0 ");
                                continue;
                            }
                            /* we're not using 1G pages, just print the  */
                            fprintf(opt_file_out, "%lx ", PTABLE_BASE_MASK(result->table[i].entries[j]) >> 12);
                            break;
                        case 4:
                            if (!(result->table[i].entries[j] & 0x1)) {
                                fprintf(opt_file_out, "0 ");
                                continue;
                            }
                            if (i < 256) {
                                /* just print out the entry, if it belongs to the user space */
                                fprintf(opt_file_out, "%lx ", PTABLE_BASE_MASK(result->table[i].entries[j]) >> 12);
                            }
                            
                            break;
                        default:
                            continue;
                    }
                }
                fprintf(opt_file_out, "</level%d>\n", level);
            }
        }
        fprintf(opt_file_out,"</ptdump>\n");
        fflush(opt_file_out);
        wait_and_dump_next:
        //usleep(30000000);
	//exit(0);
	break;
    }
    
    free(result);
    close(f);
    #define CONFIG_SHM_FILE_NAME "/tmp/ptdump-bench"
    FILE *fd = fopen(CONFIG_SHM_FILE_NAME ".done", "w");
    if (!fd) {
	fprintf (stderr, "ERROR: ptdump could not create the shared file descriptor\n");
    }
    return 0;
}
