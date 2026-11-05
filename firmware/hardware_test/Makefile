MARCH = rv32i_zicsr_zifencei
EFFORT = -Os

USER_FLAGS += -ggdb -gdwarf-3
USER_FLAGS += -Wl,--defsym,__neorv32_rom_size=16k
USER_FLAGS += -Wl,--defsym,__neorv32_ram_size=8k

NEORV32_HOME ?= ../../third_party/neorv32

include $(NEORV32_HOME)/sw/common/common.mk
