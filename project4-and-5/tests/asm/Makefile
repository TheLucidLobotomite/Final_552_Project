.ONESHELL:
PROGRAM ?= add0

assemble:
	docker run --rm -v $(CURDIR):/src coderkalyan/ece552-tools:latest bash -c "\
		cd /src && \
		riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 $(PROGRAM).asm -o $(PROGRAM).o && \
		riscv64-unknown-elf-objcopy -O binary -j .text --pad-to=0x400 $(PROGRAM).o $(PROGRAM).hex && \
		python3 -c \"data = open('$(PROGRAM).hex', 'rb').read(); print('\\n'.join(' '.join('{:02x}'.format(b) for b in data[i:i+4]) for i in range(0, len(data), 4)))\" > program.mem \
	"
	@if exist ..\..\tb (move /y program.mem ..\..\tb\program.mem) else (echo Testbench directory not found!)

clean:
	-del /f /q *.o *.hex program.mem ..\..\tb\program.mem 2>nul