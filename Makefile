ODIN = odin/odin

SRCS = $(wildcard snake/*.odin)

all: snake.bin

snake.bin: $(SRCS)
	$(ODIN) build snake/
