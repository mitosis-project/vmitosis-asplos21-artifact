#define _GNU_SOURCE
#include <inttypes.h>
#include <sys/types.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sched.h>
#include <pthread.h>
#include <sys/mman.h>
#include <sys/sysinfo.h>
#include <limits.h>
#include <assert.h>
#include <string.h>

#define PROBE_MODE	(0)
#define DIRECT_MODE	(1)

#define MAX_CPUS	(192)
#define GROUP_LOCAL	(0)
#define GROUP_NONLOCAL	(1)
#define GROUP_GLOBAL	(2)

#define NR_SAMPLES      (10)
#define SAMPLE_US       (10000)

#define min(a,b)	(a < b ? a : b)
#define LAST_CPU_ID	(min(nr_cpus, MAX_CPUS))

int nr_numa_groups;
int nr_cpus;
int cpu_group_id[MAX_CPUS];
double comm_latency[MAX_CPUS][MAX_CPUS];

int stop_loops = 0;
static size_t nr_relax = 0;
//static size_t nr_tested_cores = 0;

typedef unsigned atomic_t;
static atomic_t *pingpong_mutex;

typedef struct {
	cpu_set_t cpus;
	atomic_t me;
	atomic_t buddy;
} thread_args_t;

typedef union {
	atomic_t x;
	char pad[1024];
} big_atomic_t __attribute__((aligned(1024)));
static big_atomic_t nr_pingpongs;

static inline uint64_t now_nsec(void)
{
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return ts.tv_sec * ((uint64_t)1000*1000*1000) + ts.tv_nsec;
}

static void common_setup(thread_args_t *args)
{
	if (sched_setaffinity(0, sizeof(cpu_set_t), &args->cpus)) {
		perror("sched_setaffinity");
		exit(1);
	}

	if (args->me == 0) {
		pingpong_mutex = mmap(0, getpagesize(), PROT_READ|PROT_WRITE, MAP_ANON|MAP_PRIVATE, -1, 0);
		if (pingpong_mutex == MAP_FAILED) {
			perror("mmap");
			exit(1);
		}
		*pingpong_mutex = args->me;
	}

	// ensure both threads are ready before we leave -- so that
	// both threads have a copy of pingpong_mutex.
	static pthread_mutex_t wait_mutex = PTHREAD_MUTEX_INITIALIZER;
	static pthread_cond_t wait_cond = PTHREAD_COND_INITIALIZER;
	static int wait_for_buddy = 1;
	pthread_mutex_lock(&wait_mutex);
	if (wait_for_buddy) {
		wait_for_buddy = 0;
		pthread_cond_wait(&wait_cond, &wait_mutex);
	}
	else {
		wait_for_buddy = 1; // for next invocation
		pthread_cond_broadcast(&wait_cond);
	}
	pthread_mutex_unlock(&wait_mutex);
}

static void *thread_fn(void *data)
{
	thread_args_t *args = (thread_args_t *)data;
	common_setup(args);

	atomic_t nr = 0;
	atomic_t me = args->me;
	atomic_t buddy = args->buddy;
	atomic_t *cache_pingpong_mutex = pingpong_mutex;
	while (1) {
		if (stop_loops)
			pthread_exit(0);

		if (__sync_bool_compare_and_swap(cache_pingpong_mutex, me, buddy)) {
			++nr;
			if (nr == 10000 && me == 0) {
				__sync_fetch_and_add(&nr_pingpongs.x, 2 * nr);
				nr = 0;
			}
		}
		for (size_t i = 0; i < nr_relax; ++i)
			asm volatile("rep; nop");
	}
	return NULL;
}

static int measure_latency_pair(int i, int j)
{
	thread_args_t even, odd;

	CPU_ZERO(&even.cpus);
	CPU_SET(i, &even.cpus);
	even.me = 0;
	even.buddy = 1;
	CPU_ZERO(&odd.cpus);
	CPU_SET(j, &odd.cpus);
	odd.me = 1;
	odd.buddy = 0;

	__sync_lock_test_and_set(&nr_pingpongs.x, 0);

	pthread_t t_odd, t_even;
	if (pthread_create(&t_odd, NULL, thread_fn, &odd)) {
		printf("ERROR creating odd thread\n");
		exit(1);
	}
	if (pthread_create(&t_even, NULL, thread_fn, &even)) {
		printf("ERROR creating even thread\n");
		exit(1);
	}

	uint64_t last_stamp = now_nsec();
	double best_sample = 1./0.;
	for (size_t sample_no = 0; sample_no < NR_SAMPLES; ++sample_no) {
		usleep(SAMPLE_US);
		atomic_t s = __sync_lock_test_and_set(&nr_pingpongs.x, 0);
		uint64_t time_stamp = now_nsec();
		double sample = (time_stamp - last_stamp) / (double)s;
		last_stamp = time_stamp;
		if (sample < best_sample)
			best_sample = sample;
	}
	comm_latency[i][j] = best_sample;
	comm_latency[j][i] = best_sample;
	stop_loops = 1;
	pthread_join(t_odd, NULL);
	pthread_join(t_even, NULL);
	stop_loops = 0;
	munmap(pingpong_mutex, getpagesize());
	pingpong_mutex = NULL;
	odd.buddy = 0;
	return (int)best_sample;
}

static void populate_latency_matrix(void)
{
	int i, j;

	nr_cpus = get_nprocs();

	for (i = 0; i < LAST_CPU_ID; i++) {
		thread_args_t even;

		CPU_ZERO(&even.cpus);
		CPU_SET(i, &even.cpus);
		even.me = 0;
		even.buddy = 1;
		
		for (j = i + 1; j < LAST_CPU_ID; j++) {
			thread_args_t odd;
			CPU_ZERO(&odd.cpus);
			CPU_SET(j, &odd.cpus);
			odd.me = 1;
			odd.buddy = 0;

			__sync_lock_test_and_set(&nr_pingpongs.x, 0);

			pthread_t t_odd, t_even;
			if (pthread_create(&t_odd, NULL, thread_fn, &odd)) {
				printf("ERROR creating odd thread\n");
				exit(1);
			}
			if (pthread_create(&t_even, NULL, thread_fn, &even)) {
				printf("ERROR creating even thread\n");
				exit(1);
			}

			uint64_t last_stamp = now_nsec();
			double best_sample = 1./0.;
			for (size_t sample_no = 0; sample_no < NR_SAMPLES; ++sample_no) {
				usleep(SAMPLE_US);
				atomic_t s = __sync_lock_test_and_set(&nr_pingpongs.x, 0);
				uint64_t time_stamp = now_nsec();
				double sample = (time_stamp - last_stamp) / (double)s;
				last_stamp = time_stamp;
				if (sample < best_sample)
					best_sample = sample;
			}
			//printf("pair: %d %d Latency: %*.1f", i, j, 8, best_sample);
			comm_latency[i][j] = best_sample;
			comm_latency[j][i] = best_sample;
			stop_loops = 1;
			pthread_join(t_odd, NULL);
			pthread_join(t_even, NULL);
			stop_loops = 0;
			munmap(pingpong_mutex, getpagesize());
			pingpong_mutex = NULL;
		}
	}
}

static void print_population_matrix(void)
{
	int i, j;

	for (i = 0; i < LAST_CPU_ID; i++) {
		for (j = 0; j < LAST_CPU_ID; j++)
			printf("%7d", (int)(comm_latency[i][j]));
		printf("\n");
	}
}

static double get_min_latency(int cpu, int group)
{
	int j;
	double min = INT_MAX;

	for (j = 0; j < LAST_CPU_ID; j++) {
		if (comm_latency[cpu][j] == 0)
			continue;

		/* global check */
		if (group == GROUP_GLOBAL && comm_latency[cpu][j] < min)
			min = comm_latency[cpu][j];

		/* local check */
		if (group == GROUP_LOCAL && cpu_group_id[cpu] == cpu_group_id[j]
			&& comm_latency[cpu][j] < min)
			min = comm_latency[cpu][j];

		/* non-local check */
		if (group == GROUP_NONLOCAL && cpu_group_id[cpu] != cpu_group_id[j]
			&& comm_latency[cpu][j] < min)
			min = comm_latency[cpu][j];
	}

	return min == INT_MAX ? 0 : min;
}


static double get_min2_latency(int cpu, int group, double val)
{
	int j;
	double min = INT_MAX;

	for (j = 0; j < LAST_CPU_ID; j++) {
		if (comm_latency[cpu][j] == 0)
			continue;

		/* global check */
		if (group == GROUP_GLOBAL && comm_latency[cpu][j] < min && comm_latency[cpu][j] > val)
			min = comm_latency[cpu][j];

		/* local check */
		if (group == GROUP_LOCAL && cpu_group_id[cpu] == cpu_group_id[j]
			&& comm_latency[cpu][j] < min && comm_latency[cpu][j] > val)
			min = comm_latency[cpu][j];

		/* non-local check */
		if (group == GROUP_NONLOCAL && cpu_group_id[cpu] != cpu_group_id[j]
			&& comm_latency[cpu][j] < min && comm_latency[cpu][j] > val)
			min = comm_latency[cpu][j];
	}

	return min == INT_MAX ? 0 : min;
}

static double get_max_latency(int cpu, int group)
{
	int j;
	double max = -1;

	for (j = 0; j < LAST_CPU_ID; j++) {
		if (comm_latency[cpu][j] == 0)
			continue;

		/* global check */
		if (group == GROUP_GLOBAL && comm_latency[cpu][j] > max)
			max = comm_latency[cpu][j];

		/* local check */
		if (group == GROUP_LOCAL && cpu_group_id[cpu] == cpu_group_id[j]
			&& comm_latency[cpu][j] > max)
			max = comm_latency[cpu][j];

		/* non-local check */
		if (group == GROUP_NONLOCAL && cpu_group_id[cpu] != cpu_group_id[j]
			&& comm_latency[cpu][j] > max)
			max = comm_latency[cpu][j];
	}

	return max == -1 ? INT_MAX : max;
}

/*
 * For proper assignment, the following invariant must hold:
 * The maximum latency between two CPUs in the same group (any group)
 * should be less than the minimum latency between any two CPUs from
 * different groups.
 */
static void validate_group_assignment()
{
	int i;
	double local_max = 0, nonlocal_min = INT_MAX;

	for (i = 0; i < LAST_CPU_ID; i++) {
		local_max = get_max_latency(i, GROUP_LOCAL);
		nonlocal_min = get_min_latency(i, GROUP_NONLOCAL);
		if (local_max == INT_MAX || nonlocal_min == 0)
			continue;

		if(local_max > 1.10 * nonlocal_min) {
			printf("FAIL!!!\n");
			printf("local max is bigger than NonLocal min for CPU: %d %d %d\n",
							i, (int)local_max, (int)nonlocal_min);
			exit(1);
		}
	}
	printf("PASS!!!\n");
}

static void construct_vnuma_groups(void)
{
	int i, j, count, nr_numa_groups = 0;
	double min, min_2;

	/* Invalidate group IDs */
	for (i = 0; i < LAST_CPU_ID; i++)
		cpu_group_id[i] = -1;

	for (i = 0; i < LAST_CPU_ID; i++) {
		/* If already assigned to a vNUMA group, then skip */
		if (cpu_group_id[i] != -1)
			continue;

	 	/* Else, add CPU to the next group and generate a new group id */
		cpu_group_id[i] = nr_numa_groups;
		nr_numa_groups++;

		/* Get min latency */	
		min = get_min_latency(i, GROUP_GLOBAL);
		min_2 = get_min2_latency(i, GROUP_GLOBAL, min);
#if 0
		if (min_2 > 2 * min)
			min = min_2;
#endif
		/* Add all CPUS that are within 40% of min latency to the same group as i */
		for (j = i + 1 ; j < LAST_CPU_ID; j++) {
			//printf("checking %d %d Min: %f pair: %f\n", i, j, min, comm_latency[i][j]);
			if (min >= 100 && comm_latency[i][j] < min * 1.40)
				cpu_group_id[j] = cpu_group_id[i];

			/* allow higher tolerance for small values */
			if (min < 100 && comm_latency[i][j] < min * 1.60)
				cpu_group_id[j] = cpu_group_id[i]; 
		}
	}
#if 0
	for (i = 0; i < LAST_CPU_ID; i++)
		printf("CPUID: %d GroupID: %d\n", i, cpu_group_id[i]);
#endif
	for (i = 0; i < nr_numa_groups; i++) {
		printf("vNUMA-Group-%d", i);
		count = 0;
		for (j = 0; j < LAST_CPU_ID; j++)
			if (cpu_group_id[j] == i) {
				printf("%5d", j);
				count++;
			}
		printf("\t(%d CPUS)\n", count);
	}
}

#define CPU_ID_SHIFT		(16)
/*
 * %4 is specific to our platform.
 */
#define CPU_NUMA_GROUP(mode, i)	(mode == PROBE_MODE ? cpu_group_id[i] : i % 4)
static void configure_os_numa_groups(int mode)
{
	int i;
	unsigned long val;

	/*
	 * pass vcpu & numa group id in a single word using a simple encoding:
	 * first 16 bits store the cpu identifier
	 * next 16 bits store the numa group identifier
	 * */
	for(i = 0; i < LAST_CPU_ID; i++) {
		/* store cpu identifier and left shift */
		val = i;
		val = val << CPU_ID_SHIFT;
		/* store the numa group identifier*/
		val |= CPU_NUMA_GROUP(mode, i);
	}
}

static void reserve_os_pgtable_cache(int mode, int nr_pages)
{
	int i, j;
	cpu_set_t mask;
	char command[200];

	printf("setting pgtable replication mode\n");
	system("echo 2 | sudo tee /proc/sys/kernel/pgtable_replication_mode > /dev/null");
	printf("reserving PGTABLE replicas...\n");
	for (i = 0; i < nr_numa_groups; i++) {
		for (j = 0; j < LAST_CPU_ID; j++) {
			if (CPU_NUMA_GROUP(mode, j) == i) {
				CPU_ZERO(&mask);
				CPU_SET(i, &mask);
				/*
				 * bind current thread to this cpu (j) so that pgtable allocation in the
				 * kernel is requested by this particular numa group in the kernel.
				 */
				sched_setaffinity(0, sizeof(mask), &mask);
				snprintf(command, 200, "numactl -C %d echo %d | sudo tee /proc/sys/kernel/pgtable_replication_cache > /dev/null", j, i);
				system(command);
				break;
			}
		}
	}
}
#if 0
int main(int argc, char **argv)
{
	int c, verbose, mode = PROBE_MODE;
	int nr_pages = 0;

	while ((c = getopt (argc, argv, "dvn:")) != -1) {
		switch (c) {
			case 'd':
				printf("skipping measurements in direct mode...\n");
				mode = DIRECT_MODE;
				break;
			case 'v':
				verbose = 1;
				break;
			case 'n':
				nr_pages = atoi(optarg);
				printf("pages per page-table pool = %d\n", nr_pages);
			default:
				break;
		}
	}
#if 0
	if (argc == 2 && (!strcmp(argv[1], "--verbose") || !strcmp(argv[1], "-v")))
		verbose = 1;
#endif
	printf("populating latency matrix...\n");
	populate_latency_matrix();
	if (verbose)
		print_population_matrix();
	printf("constructing NUMA groups...\n");
	construct_vnuma_groups();
	printf("validating group assignment...");
	validate_group_assignment();

	configure_os_numa_groups(mode);
	//reserve_os_pgtable_cache(mode, nr_pages);
	printf("Done...\n");
}
#endif

int main(int argc, char **argv)
{
	int src, dst, c, latency;

	while ((c = getopt (argc, argv, "s:d:")) != -1) {
		switch (c) {
			case 's':
				src = atoi(optarg);
				break;
			case 'd':
				dst = atoi(optarg);
				break;
			default:
				break;
		}
	}
	latency = measure_latency_pair(src, dst);
	printf("[%d %d] latency = {%d}\n", src, dst, latency);
}

