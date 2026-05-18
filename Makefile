# ─── Toolchain ──────────────────────────────────────────────────────────────
CC      = gcc
CXX     = g++
NASM    = nasm
LD      = ld
GRUB    = grub-mkrescue

# ─── Flags ───────────────────────────────────────────────────────────────────
CFLAGS   = -m64 -ffreestanding -c -std=c11  \
           -fno-stack-protector -fno-omit-frame-pointer \
           -mno-red-zone -mno-mmx -mno-sse -mno-sse2 \
           -Wall -Wextra -O2

CXXFLAGS = -m64 -ffreestanding -c -std=c++17 \
           -fno-exceptions -fno-rtti          \
           -fno-stack-protector -fno-omit-frame-pointer \
           -mno-red-zone -mno-mmx -mno-sse -mno-sse2 \
           -Wall -Wextra -O2

NASMFLAGS = -f elf64

LDFLAGS  = -m elf_x86_64 -T linker.ld --nostdlib

# ─── Directories ─────────────────────────────────────────────────────────────
KERNEL_DIR = kernel
BUILD_DIR  = isodir/boot/kernel

# ─── Sources ─────────────────────────────────────────────────────────────────
C_SOURCES   := $(wildcard $(KERNEL_DIR)/*.c)   \
               $(wildcard $(KERNEL_DIR)/func/*.c)

CPP_SOURCES := $(wildcard $(KERNEL_DIR)/*.cpp) \
               $(wildcard $(KERNEL_DIR)/func/*.cpp) \
               $(wildcard $(KERNEL_DIR)/bin/*.cpp)

# ─── Objects ─────────────────────────────────────────────────────────────────
C_OBJS   := $(patsubst $(KERNEL_DIR)/%.c,   $(BUILD_DIR)/%.o, $(C_SOURCES))
CPP_OBJS := $(patsubst $(KERNEL_DIR)/%.cpp, $(BUILD_DIR)/%.o, $(CPP_SOURCES))

# boot.asm handled explicitly — must be first for correct entry point
BOOT_OBJ   := $(BUILD_DIR)/boot.o
OTHER_OBJS := $(C_OBJS) $(CPP_OBJS)
ALL_OBJS   := $(BOOT_OBJ) $(OTHER_OBJS)

TARGET  = $(BUILD_DIR)/kernel.bin
QMS_ISO = qms64.iso

# ─── Top-level targets ───────────────────────────────────────────────────────
.PHONY: all iso kernel run clean dirs check

all: iso

run: iso
	@echo "--- Starting QEMU (64-bit) ---"
	qemu-system-x86_64 -cdrom $(QMS_ISO) -m 128M

iso: kernel
	@echo "--- Creating ISO ---"
	$(GRUB) -o $(QMS_ISO) isodir/

kernel: dirs $(ALL_OBJS)
	@echo "--- Linking kernel.bin ---"
	$(LD) $(LDFLAGS) $(ALL_OBJS) -o $(TARGET)

# ─── Explicit rule for boot.asm ──────────────────────────────────────────────
$(BUILD_DIR)/boot.o: $(KERNEL_DIR)/boot.asm
	@mkdir -p $(dir $@)
	@echo "  NASM  $<"
	$(NASM) $(NASMFLAGS) $< -o $@

# ─── C sources ───────────────────────────────────────────────────────────────
$(BUILD_DIR)/%.o: $(KERNEL_DIR)/%.c
	@mkdir -p $(dir $@)
	@echo "  CC    $<"
	$(CC) $(CFLAGS) $< -o $@

# ─── C++ sources ─────────────────────────────────────────────────────────────
$(BUILD_DIR)/%.o: $(KERNEL_DIR)/%.cpp
	@mkdir -p $(dir $@)
	@echo "  CXX   $<"
	$(CXX) $(CXXFLAGS) $< -o $@

dirs:
	@mkdir -p $(BUILD_DIR)/func $(BUILD_DIR)/bin

check:
	@echo "Checking tools..."
	@which $(NASM) || (echo "ERROR: nasm not found. Run: sudo apt install nasm" && exit 1)
	@which $(GRUB) || (echo "ERROR: grub-mkrescue not found. Run: sudo apt install grub-pc-bin grub-common xorriso" && exit 1)
	@which $(LD)   || (echo "ERROR: ld not found. Run: sudo apt install binutils" && exit 1)
	@echo "All tools OK."

clean:
	@echo "--- Cleaning ---"
	rm -rf $(BUILD_DIR) $(QMS_ISO)
