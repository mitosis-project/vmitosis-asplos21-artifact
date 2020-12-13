all: mini-probe

mini-probe: mini-probe.c
	gcc -static -O3 $^ -o $@ -pthread
clean:
	@rm -f mini-probe
