ODIN = ../odin/odin

SRCS = $(wildcard tower/*.odin)
EDITOR_SRCS = $(wildcard level-editor/*.odin)

all: tower.bin

tower.bin: $(SRCS)
	$(ODIN) build tower/

clean:
	rm tower.bin
	rm level-editor.bin

.PHONY: clean all editor test run edit

level-editor.bin: $(EDITOR_SRCS)
	$(ODIN) build level-editor/

editor: level-editor.bin

test:
	$(ODIN) test tests

run:
	./tower.bin

edit:
	./level-editor.bin
