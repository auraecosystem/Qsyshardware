# Make sure /bin/bash is used for the 'find' in clean
SHELL := /bin/bash

.PHONY: test run clean

# Run all tests (no args)
test:
	python3 tests/python/runner.py

# Run a single test by name
# Usage: make run TEST=<test_name>
run:
ifndef TEST
	$(error Usage: make run TEST=<test_name>)
endif
	python3 tests/python/runner.py $(TEST)

# Remove generated waveforms
clean:
	find . -type f \( -name '*.vcd' -o -name '*.ghw' \) -print -delete


# ---------------------------------------------------------------
# VHDL Syntax Check (using GHDL)
# Run with:  make check
# ---------------------------------------------------------------
# ---------------------------------------------------------------
# VHDL Syntax Check (GHDL) — EXCLUI IPs de vendor (altera_mf etc.)
# ---------------------------------------------------------------
GHDL := ghdl
STD  := --std=08
WDIR := build/ghdl

# 1) Coleta todos .vhd/.vhdl
CHECK_SRCS_ALL := $(shell find src -type f \( -name '*.vhd' -o -name '*.vhdl' \) | sort)

# 2) EXCLUI vendors/IPs e arquivos que usam bibliotecas Intel (lpm, altera)
EXCLUDE_GLOB := \
  src/ROM1PORT/% \
  src/RAM1PORT/% \
  src/ROM_IP/% \
  src/%/ip/% \
  src/%/quartus_ip/% \
  src/**/ip/% \
  src/**/quartus_ip/% \
  src/RV32M.vhd \
  src/mhu.vhd

CHECK_SRCS_ALL := $(filter-out $(EXCLUDE_GLOB),$(CHECK_SRCS_ALL))

# 3) Coloque consts e genericRegister primeiro
CHECK_SRCS := src/rv32i_ctrl_consts.vhd src/genericRegister.vhd \
              $(filter-out src/rv32i_ctrl_consts.vhd src/genericRegister.vhd,$(CHECK_SRCS_ALL))

# 4) Forçar ordem: dependencias folha → subsistemas internos → topos
#    Resolve erros de "unit not found" no GHDL

# --- Entidades folha (compartilhadas por GPIO e TIMER) ---
LEAF_FLIPFLOP  := src/FlipFlop.vhd
LEAF_TRISTATE  := $(firstword $(shell find src -type f -iname "tristate_buffer_1bit.vh*"))
LEAF_MUX4      := $(firstword $(shell find src -type f -iname "generic_mux_4x1.vh*"))
LEAF_MUX8      := $(firstword $(shell find src -type f -iname "generic_mux_8x1.vh*"))
LEAF_MUX2      := $(firstword $(shell find src -type f -iname "generic_mux_2x1.vh*" -path "*/TIMER/*"))
LEAF_SYNC      := $(firstword $(shell find src -type f -iname "generic_synchronizer_1bit.vh*"))
LEAF_DEPS      := $(LEAF_FLIPFLOP) $(LEAF_TRISTATE) $(LEAF_MUX4) $(LEAF_MUX8) $(LEAF_MUX2) $(LEAF_SYNC)

# --- GPIO: decoder → cell → top ---
GPIO_DEC  := $(firstword $(shell find src -type f -iname "gpio*_operation*decoder*.vh*"))
GPIO_CELL := $(firstword $(shell find src -type f -iname "gpio*_cell*.vh*"))
GPIO_TOP  := $(firstword $(shell find src -type f -iname "gpio.vh*"))

# --- TIMER: carry → adder → register → alu_ge → counter_ovf → prescaler → decoder → top ---
TIMER_CARRY   := $(firstword $(shell find src -type f -iname "generic_carry_lookahead.vh*"))
TIMER_ADDER   := $(firstword $(shell find src -type f -iname "generic_adder.vh*" -path "*/TIMER/*"))
TIMER_REG     := $(firstword $(shell find src -type f -iname "generic_register.vh*" -path "*/TIMER/*"))
TIMER_ALU_GE  := $(firstword $(shell find src -type f -iname "alu_ge_unsigned.vh*"))
TIMER_CNT_OVF := $(firstword $(shell find src -type f -iname "counter_overflow.vh*"))
TIMER_PRESC   := $(firstword $(shell find src -type f -iname "clock_prescaler.vh*"))
TIMER_DEC     := $(firstword $(shell find src -type f -iname "timer_operation_decoder.vh*"))
TIMER_TOP     := $(firstword $(shell find src -type f -iname "timer.vh*" -path "*/TIMER/*"))
TIMER_DEPS    := $(TIMER_CARRY) $(TIMER_ADDER) $(TIMER_REG) $(TIMER_ALU_GE) $(TIMER_CNT_OVF) $(TIMER_PRESC) $(TIMER_DEC)

# Tudo que precisa vir antes
EARLY   := $(LEAF_DEPS) $(GPIO_DEC) $(GPIO_CELL) $(TIMER_DEPS)
# Topos que vem por ultimo
LATE    := $(GPIO_TOP) $(TIMER_TOP)

ORDERED_SRCS := \
  $(EARLY) \
  $(filter-out $(EARLY) $(LATE),$(CHECK_SRCS)) \
  $(LATE)

.PHONY: print-check check
print-check:
	@echo "Arquivos que o check vai analisar:"; echo
	@printf '  %s\n' $(ORDERED_SRCS)

check:
	@echo "🔍 Checking VHDL syntax with GHDL..."
	@mkdir -p $(WDIR)
	@rm -rf $(WDIR)/*
	@$(GHDL) -a $(STD) --work=work --workdir=$(WDIR) $(ORDERED_SRCS)
	@echo "✅ VHDL syntax check passed"
