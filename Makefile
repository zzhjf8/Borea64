AS = nasm

SRC_DIR = src
BUILD_DIR = build

all: $(BUILD_DIR)/floppy.img

$(BUILD_DIR)/floppy.img: $(BUILD_DIR)/boot.bin
	cp $< $@ 
	truncate -s 1440k $@

$(BUILD_DIR)/boot.bin: $(SRC_DIR)/boot.asm
	$(AS) $< -f bin -o $@
