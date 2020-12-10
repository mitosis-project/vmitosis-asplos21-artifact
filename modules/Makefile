
obj-m += ptdump.o

all: ptdump.ko

ptdump.ko: ptdump.c
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules

clean:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean

install: ptdump.ko
	insmod ptdump.ko

uninstall: 
	rmmod ptdump.ko

update: ptdump.ko
	-rmmod ptdump.ko
	insmod ptdump.ko