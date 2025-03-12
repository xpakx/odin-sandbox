ODIN = ../odin/odin

SRCS = $(wildcard tower/*.odin)
EDITOR_SRCS = $(wildcard level-editor/*.odin)

all: tower.bin

tower.bin: $(SRCS)
	$(ODIN) build tower/

clean:
	rm tower.bin

.PHONY: clean all editor

level-editor.bin: $(EDITOR_SRCS)
	$(ODIN) build level-editor/

editor: level-editor.bin
