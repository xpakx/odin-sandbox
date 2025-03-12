ODIN = ../odin/odin

SRCS = $(wildcard tower/*.odin)

all: tower.bin

tower.bin: $(SRCS)
	$(ODIN) build tower/

clean:
	rm tower.bin

.PHONY: clean
