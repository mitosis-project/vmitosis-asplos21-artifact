all: dodump mini-probe

dodump: dodump.c
	gcc -static -O3 $^ -o $@ -I../modules

mini-probe: mini-probe.c
	gcc -static -O3 $^ -o $@ -pthread
clean:
	@rm -f dodump
	@rm -f mini-probe
