########################################
## bare metal makefile for ARM Cortex ##
########################################

NAME      = hello_world
#DEBUG	  = 1


FREERTOS_DIR = contrib/FreeRTOS/Source
FREERTOS_SRCS = \
		$(FREERTOS_DIR)/tasks.c \
		$(FREERTOS_DIR)/queue.c \
		$(FREERTOS_DIR)/list.c \
		$(FREERTOS_DIR)/portable/GCC/ARM_CM4F/port.c \
		$(FREERTOS_DIR)/portable/MemMang/heap_4.c \
		$(FREERTOS_DIR)/timers.c

# $(FREERTOS_DIR)/event_groups.c
# $(FREERTOS_DIR)/stream_buffer.c
# $(FREERTOS_DIR)/croutine.c

FREERTOS_INCDIRS = \
		$(FREERTOS_DIR)/include \
		$(FREERTOS_DIR)/portable/GCC/ARM_CM4F


SRCS      = $(wildcard contrib/CMSIS/*.c)
SRCS  	 += $(wildcard src/*.c)
SRCS  	 += $(FREERTOS_SRCS)
SRCS 	 += contrib/xprintf/xprintf.c

INCDIRS   = contrib/CMSIS
INCDIRS  += contrib/xprintf
INCDIRS  += $(FREERTOS_INCDIRS)

LSCRIPT   = gcc_arm.ld

DEFINES   = $(EXDEFINES)
DEFINES  += -DF_CPU=16000000


BUILDDIR  = .build/

CFLAGS    = -ffunction-sections \
			-mlittle-endian \
			-mthumb \
			-mcpu=cortex-m4 \
			-mfloat-abi=hard \
			-mfpu=fpv4-sp-d16 \
			-std=gnu11 \
			-ggdb

ifdef DEBUG
    CFLAGS   += -Og
    CFLAGS   += -g3
else
    CFLAGS   += -Os -flto
endif

LFLAGS    = --specs=nano.specs \
			--specs=nosys.specs \
			-nostartfiles \
			-Wl,--gc-sections \
			-T$(LSCRIPT) \
			-lm

WFLAGS    = -Wall \
			-Wextra \
			-Wstrict-prototypes \
			-Werror -Wno-error=unused-function -Wno-error=unused-variable \
			-Wfatal-errors \
			-Warray-bounds \
			-Wno-unused-parameter

GCCPREFIX = arm-none-eabi-
CC        = $(GCCPREFIX)gcc
OBJCOPY   = $(GCCPREFIX)objcopy
OBJDUMP   = $(GCCPREFIX)objdump
SIZE      = $(GCCPREFIX)size

INCLUDE   = $(addprefix -I,$(INCDIRS))

OBJS      = $(addprefix $(BUILDDIR), $(addsuffix .o, $(basename $(SRCS))))
OBJDIR    = $(sort $(dir $(OBJS)))
BIN_NAME  = $(addprefix $(BUILDDIR), $(NAME))


###########
## rules ##
###########

.PHONY: all
all: $(BIN_NAME).elf
all: $(BIN_NAME).bin
all: $(BIN_NAME).s19
all: $(BIN_NAME).hex
all: $(BIN_NAME).lst
all: print_size


.PHONY: clean
clean:
	$(RM) -r $(wildcard $(BUILDDIR)*)


.PHONY: install
install: $(BIN_NAME).hex
	@echo;
	@echo [OpenOCD] program $<:
	openocd -d0 \
	-f interface/cmsis-dap.cfg \
	-c "transport select swd" \
	-f target/stm32f4x.cfg \
 	-c "program $<" \
 	-c "reset run" \
 	-c "shutdown"

###########################################
# Internal Rules                          #
###########################################

# create directories
$(OBJS): | $(OBJDIR)
$(OBJDIR):
	mkdir -p $@

# compiler
$(BUILDDIR)%.o: %.c
	$(CC) -MMD -c -o $@ $(INCLUDE) $(DEFINES) $(CFLAGS) $(WFLAGS) $<

# assembler
$(BUILDDIR)%.o: %.s
	$(CC) -c -x assembler-with-cpp -o $@ $(INCLUDE) $(DEFINES) $(CFLAGS) $(WFLAGS) $<

# linker
$(BUILDDIR)%.elf: $(OBJS)
	$(CC) -o $@ $^ $(CFLAGS) $(LFLAGS) -Wl,-Map=$(addsuffix .map, $(basename $@))

%.bin: %.elf
	$(OBJCOPY) -O binary -S $< $@

%.s19: %.elf
	$(OBJCOPY) -O srec -S $< $@

%.hex: %.elf
	$(OBJCOPY) -O ihex -S $< $@

%.lst: %.elf
	$(OBJDUMP) -d $< > $@

.PHONY: print_size
print_size: $(BIN_NAME).elf
	$(SIZE) $<


#####################
## Advanced Voodoo ##
#####################

# Force a rebuild of affected .c files when a header file is changed.
#
# The compiler can generate small files containing Makefile rules that
# make every c file dependent on all its included header files. 
# Including these auto-generated rules will ensure that any change in 
# a header file will also invalidate all c files that depend on it and
# force a rebuild. The following commands will try to include any such
# compiler generated makefile snippet (they have the extension *.d)
# and the minus in front of the include makes sure it won't produce 
# an error if they do not yet exist (for example after clean).
DEPS = $(patsubst %.o,%.d,$(OBJS))
-include $(DEPS)

# Force a rebuild of everything when the Makefile itself is changed.
#  
# Just adding the Makefile as prerequisite to all object files is
# enough to accomplish this. 
$(OBJS): Makefile

# Force a rebuild of everything when the compiler flags have changed.
#
# On the obscurity scale from 0 to 10 the following Voodoo 
# will reach a solid 8 but it is very strong and it is useful
# enough to use it despite its WTF-factor.
#  
# The phony force prerequisite just makes sure the recipe is always 
# executed, even when the compiler_flags file already exists,
# thats is its only purpose. When the recipe is executed (on every 
# build because of the phony dependency) it compares the *contents* 
# of the compiler_flags file and then it might or might not update 
# the compiler_flags file depending on the current flags. 
# The object files will be made depending on the compiler_flags
# file and when its timestamp is newer then they will be rebuilt 
# also.
ALLFLAGS=$(INCLUDE) $(DEFINES) $(CFLAGS) $(WFLAGS)
.PHONY: force
$(BUILDDIR)compiler_flags: force
	echo '$(ALLFLAGS)' | cmp -s - $@ || echo '$(ALLFLAGS)' > $@
$(OBJS): $(BUILDDIR)compiler_flags
