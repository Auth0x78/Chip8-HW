# ==============================================================================
# Verilator Build System (Linux only)
# ==============================================================================
# USAGE QUICK REFERENCE:
#   make              - Run default testbench (testbench/tb.sv)
#   make test_alu     - Run specific testbench (testbench/tb_alu.sv)
#   make waves        - Open default waveform in GTKWave (waveforms/default.vcd)
#   make wave_alu     - Open specific waveform in GTKWave (waveforms/alu.vcd)
#   make clean        - Remove all build outputs and generated waveforms
#   make help         - Display help instructions
# ==============================================================================

# OS Detection
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Linux)
    IS_LINUX := 1
else ifeq ($(findstring MINGW,$(UNAME_S)),MINGW)
    IS_WINDOWS := 1
else ifeq ($(findstring MSYS,$(UNAME_S)),MSYS)
    IS_WINDOWS := 1
else ifeq ($(findstring CYGWIN,$(UNAME_S)),CYGWIN)
    IS_WINDOWS := 1
else
    IS_WINDOWS := 1
endif

# Windows is not supported
ifdef IS_WINDOWS
$(error Windows is not supported. Please use Linux or WSL.)
endif

# Output Directories
OUTPUT_DIR := build
VCD_DIR    := waveforms
OBJ_DIR    := $(OUTPUT_DIR)/obj

# Header Include Directory (.vh files)
INC_DIR    := include

# Discover Source Files
RTL_SRCS := $(wildcard rtl/*.sv) $(wildcard rtl/**/*.sv)
TB_SRCS  := $(wildcard testbench/*.sv)
HDRS     := $(wildcard $(INC_DIR)/*.vh) $(wildcard rtl/**/*.vh)

# Default Testbench Configurations
DEFAULT_TB  := testbench/tb.sv
SIM_EXE     := $(OUTPUT_DIR)/test_sim
DEFAULT_VCD := $(VCD_DIR)/default.vcd

# Toolchain Binaries
VERILATOR := verilator
GTKWAVE   := gtkwave

# Verilator Flags
# --cc: Generate C++ code
# --binary: Create standalone executable from SystemVerilog testbench
# --trace: Enable waveform tracing (VCD/FST)
# --timing: Enable timing simulation (account for #delay statements)
# -Wall: Enable all warnings
# -Wno-UNUSED: Suppress unused signal warnings
# -Wno-WIDTH: Suppress width mismatch warnings
# -Wno-VARHIDDEN: Suppress variable hidden warnings (expected with `include pattern)
# -Wno-UNUSEDSIGNAL: Suppress unused signal warnings (testbench only uses A[0])
# --top-module: Specify top module name
VERILATOR_FLAGS := --cc -O3 --binary --trace --timing -Wall -Wno-UNUSED -Wno-WIDTH \
                   -Wno-VARHIDDEN -Wno-UNUSEDSIGNAL \
                   -I$(INC_DIR) \
                   -DVCD_DIR=\"$(VCD_DIR)\" \
                   --top-module

.PHONY: all help sim lint waves wave-% clean

# Default target runs simulation
all: sim

# ------------------------------------------------------------------------------
# Help Target
# ------------------------------------------------------------------------------
help:
	@echo "Available Targets (Linux/WSL only):"
	@echo "  make              : Compile & simulate default testbench ($(DEFAULT_TB))"
	@echo "  make test_<name>  : Compile & simulate testbench/tb_<name>.sv"
	@echo "  make lint         : Run Verilator lint checks only"
	@echo "  make waves        : Open default waveform ($(DEFAULT_VCD)) in GTKWave"
	@echo "  make wave_<name>  : Open specific waveform ($(VCD_DIR)/<name>.vcd) in GTKWave"
	@echo "  make clean        : Delete '$(OUTPUT_DIR)' and '$(VCD_DIR)' directories"

# ------------------------------------------------------------------------------
# Output Directory Creation
# ------------------------------------------------------------------------------
$(OUTPUT_DIR) $(VCD_DIR) $(OBJ_DIR):
	@mkdir -p $@

# ------------------------------------------------------------------------------
# Default Simulation (make / make sim)
# Recompiles automatically when any RTL source or header changes.
# ------------------------------------------------------------------------------
sim: $(RTL_SRCS) $(DEFAULT_TB) $(HDRS) | $(OUTPUT_DIR) $(VCD_DIR) $(OBJ_DIR)
	@echo "Building with Verilator..."
	$(VERILATOR) $(VERILATOR_FLAGS) $(notdir $(basename $(DEFAULT_TB))) \
		$(RTL_SRCS) $(DEFAULT_TB) \
		--Mdir $(OBJ_DIR) \
		-o $(SIM_EXE)
	@echo "Running simulation..."
	$(SIM_EXE)

# ------------------------------------------------------------------------------
# Verilator Lint Check
# ------------------------------------------------------------------------------
lint: $(RTL_SRCS) $(HDRS)
	@echo "Running Verilator lint checks..."
	$(VERILATOR) --lint-only -Wall -Wno-fatal -Irtl \
		-I$(INC_DIR) $(RTL_SRCS)

# ------------------------------------------------------------------------------
# Dynamic Pattern Rule for Specific Testbenches (e.g., make test_alu)
# Looks for testbench/tb_<name>.sv
# ------------------------------------------------------------------------------
test-%: $(RTL_SRCS) $(HDRS) | $(OUTPUT_DIR) $(VCD_DIR) $(OBJ_DIR)
	@TB_FILE=$$( [ -f testbench/tb_$*.sv ] && echo "testbench/tb_$*.sv" || echo "testbench/$*.sv" ); \
	if [ ! -f "$$TB_FILE" ]; then \
		echo "Error: Testbench not found: $$TB_FILE"; \
		exit 1; \
	fi; \
	VCD_PATH="$(VCD_DIR)/$*.vcd"; \
	TOP_MODULE=$$(basename $$TB_FILE .sv); \
	echo "Compiling and running: $$TB_FILE -> $$VCD_PATH"; \
	rm -rf $(OBJ_DIR)/$*; \
	$(VERILATOR) $(VERILATOR_FLAGS) $$TOP_MODULE \
		$(RTL_SRCS) $$TB_FILE \
		--Mdir $(OBJ_DIR)/$* && \
	$(OBJ_DIR)/$*/V$$TOP_MODULE

# ------------------------------------------------------------------------------
# Waveform Viewing Rules (GTKWave)
# ------------------------------------------------------------------------------
# Open the default waveform: make waves
waves:
	$(GTKWAVE) $(DEFAULT_VCD) &

# Open a specific waveform: make wave_alu (opens waveforms/alu.vcd)
wave-%:
	$(GTKWAVE) $(VCD_DIR)/$*.vcd &

# ------------------------------------------------------------------------------
# Cleanup Target
# ------------------------------------------------------------------------------
clean:
	rm -rf $(OUTPUT_DIR) $(VCD_DIR)