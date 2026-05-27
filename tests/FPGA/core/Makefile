# --- variáveis relevantes ---
PROJECT_NAME := quartus/core_fpga_test
ASM_DIR := asm_tests
BUILD_DIR := build
TOOLS_DIR := tools
ROM_MIF := quartus/ips/ROM1PORT/init.mif
SOF_FILE := quartus/output_files/core_fpga_test.sof
COMPARE_SCRIPT := $(TOOLS_DIR)/compare_mif_with_json.py

ASM_FILE := $(shell ls $(ASM_DIR)/*.S 2>/dev/null | head -n 1)
ifeq ($(ASM_FILE),)
$(error Nenhum arquivo .S encontrado em $(ASM_DIR).)
endif
BNAME := $(basename $(notdir $(ASM_FILE)))
OUTDDIR := output_mifs
MEM_DUMP := $(OUTDDIR)/$(BNAME)_ram.mif
MEM_IDX := 1
WAIT_SECS := 30

AS := riscv64-unknown-elf-as
LD := riscv64-unknown-elf-ld
OBJCOPY := riscv64-unknown-elf-objcopy
HEXDUMP := hexdump
PY := python3
HEX2MIF := $(TOOLS_DIR)/hex2mif.py

HEX_FILE := $(BUILD_DIR)/$(BNAME).hex
BIN_FILE := $(BUILD_DIR)/$(BNAME).bin
ELF_FILE := $(BUILD_DIR)/$(BNAME).elf

.PHONY: all asm update_rom quartus_compile program_board wait dump_ram compare clean

all: program_board wait dump_ram compare
	@echo "Fluxo completo finalizado."

# 1) montar .S -> .hex
asm: $(HEX_FILE)
	@echo "Assembly gerado: $(HEX_FILE)"

$(BUILD_DIR)/%.hex: $(ASM_DIR)/%.S | $(BUILD_DIR)
	@echo "Compilando $< ..."
	@if command -v $(AS) >/dev/null 2>&1; then \
		$(AS) -march=rv32im -mabi=ilp32 -o $(BUILD_DIR)/$*.o $< ; \
		$(LD) -m elf32lriscv -Ttext=0x0 -o $(ELF_FILE) $(BUILD_DIR)/$*.o ; \
		$(OBJCOPY) -O binary $(ELF_FILE) $(BIN_FILE) ; \
		$(HEXDUMP) -v -e '1/4 "%08X\n"' $(BIN_FILE) > $(HEX_FILE) ; \
		rm -f $(BUILD_DIR)/$*.o $(ELF_FILE) $(BIN_FILE) ; \
	else \
		echo "Erro: assembler $(AS) nao encontrado."; \
		exit 1; \
	fi
	@echo "Gerado: $(HEX_FILE)"

$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

# 2) compilar Quartus (ROM fica zerada, sera carregada via JTAG)
quartus_compile: asm
	@echo "Iniciando compilacao Quartus (projeto: $(PROJECT_NAME)) ..."
	@quartus_sh --flow compile $(PROJECT_NAME)
	@echo "Compilacao Quartus concluida."

# 3) programar FPGA + carregar ROM via JTAG
program_board: quartus_compile
	@echo "Programando placa (SOF: $(SOF_FILE)) ..."
	@quartus_pgm -m JTAG -o "p;$(SOF_FILE)"
	@echo "Programacao enviada."
	@echo "Carregando programa na ROM via JTAG ..."
	@$(PY) $(HEX2MIF) $(HEX_FILE) /tmp/rom_jtag.mif 8192
	@quartus_stp -t $(TOOLS_DIR)/loadROM.tcl /tmp/rom_jtag.mif
	@echo "ROM carregada."

# 4) aguarda execucao
wait:
	@echo "Aguardando $(WAIT_SECS) segundos para o programa executar na placa..."
	@sleep $(WAIT_SECS)

# 5) dump da RAM
dump_ram: wait
	@echo "Criando diretorio de saida para MIFs: $(OUTDDIR)"
	@mkdir -p $(OUTDDIR)
	@echo "Executando quartus_stp para salvar memoria em: $(MEM_DUMP)"
	@quartus_stp -t $(TOOLS_DIR)/dumpMemory.tcl $(MEM_DUMP) $(MEM_IDX)
	@echo "Dump gravado em: $(MEM_DUMP)"

# 6) comparar com gabarito
compare: dump_ram
	@echo "Comparando $(MEM_DUMP) com asm_tests/$(BNAME).json ..."
	@if [ ! -f "$(COMPARE_SCRIPT)" ]; then \
	    echo "Erro: script de comparacao nao encontrado: $(COMPARE_SCRIPT)"; exit 1; \
	fi
	@if [ ! -f "$(MEM_DUMP)" ]; then \
	    echo "Erro: MIF de dump nao encontrado: $(MEM_DUMP)"; exit 1; \
	fi
	@if [ ! -f "asm_tests/$(BNAME).json" ]; then \
	    echo "Erro: gabarito JSON asm_tests/$(BNAME).json nao encontrado"; exit 1; \
	fi
	@$(PY) $(COMPARE_SCRIPT) $(MEM_DUMP) asm_tests/$(BNAME).json
	@echo "Comparacao finalizada."

clean:
	@rm -rf $(BUILD_DIR) $(OUTDDIR)
