# ==============================================================================
# Icarus Verilog & GTKWave Build System
# ==============================================================================
# USAGE QUICK REFERENCE:
#   make              - Run default testbench (testbench/tb.v)
#   make test_alu     - Run specific testbench (testbench/tb_alu.v or alu.v)
#   make waves        - Open default waveform in GTKWave (waveforms/default.vcd)
#   make wave_alu     - Open specific waveform in GTKWave (waveforms/alu.vcd)
#   make clean        - Remove all build outputs and generated waveforms
#   make help         - Display help instructions
# ==============================================================================

# Output Directories
OUTPUT_DIR := build
VCD_DIR    := waveforms

# Header Include Directory (.vh files)
INC_DIR    := include

# Discover Source Files
RTL_SRCS := $(wildcard rtl/*.sv) $(wildcard rtl/**/*.sv)
TB_SRCS  := $(wildcard testbench/*.sv)
HDRS     := $(wildcard $(INC_DIR)/*.vh) $(wildcard rtl/**/*.vh)

# Default Testbench Configurations
DEFAULT_TB  := testbench/tb.sv
SIM_OUT     := $(OUTPUT_DIR)/test_sim.vvp
DEFAULT_VCD := $(VCD_DIR)/default.vcd

# Toolchain Binaries
IVERILOG := iverilog
VVP      := vvp
GTKWAVE  := gtkwave

# Compiler Flags (-g2012 enables IEEE 1800-2012 SystemVerilog features)
FLAGS    := -g2012 -I$(INC_DIR) -DVCD_DIR=\"$(VCD_DIR)\"

.PHONY: all help sim waves wave_% clean

# Default target runs simulation
all: sim

# ------------------------------------------------------------------------------
# Help Target
# ------------------------------------------------------------------------------
help:
	@echo "Available Targets:"
	@echo "  make              : Compile & simulate default testbench ($(DEFAULT_TB))"
	@echo "  make test_<name>  : Compile & simulate testbench/tb_<name>.v or testbench/<name>.v"
	@echo "  make waves        : Open default waveform ($(DEFAULT_VCD)) in GTKWave"
	@echo "  make wave_<name>  : Open specific waveform ($(VCD_DIR)/<name>.vcd) in GTKWave"
	@echo "  make clean        : Delete '$(OUTPUT_DIR)' and '$(VCD_DIR)' directories"

# ------------------------------------------------------------------------------
# Output Directory Creation
# ------------------------------------------------------------------------------
$(OUTPUT_DIR) $(VCD_DIR):
	@mkdir -p $@

# ------------------------------------------------------------------------------
# Default Simulation (make / make sim)
# Recompiles automatically when any RTL source or header changes.
# ------------------------------------------------------------------------------
sim: $(RTL_SRCS) $(DEFAULT_TB) $(HDRS) | $(OUTPUT_DIR) $(VCD_DIR)
	$(IVERILOG) $(FLAGS) \
		-DVCD_FILE=\"$(DEFAULT_VCD)\" \
		-o $(SIM_OUT) \
		$(RTL_SRCS) \
		$(DEFAULT_TB)
	$(VVP) $(SIM_OUT)

# ------------------------------------------------------------------------------
# Dynamic Pattern Rule for Specific Testbenches (e.g., make test_alu)
# Looks for testbench/tb_<name>.v first; falls back to testbench/<name>.v.
# ------------------------------------------------------------------------------
test_%: $(RTL_SRCS) $(HDRS) | $(OUTPUT_DIR) $(VCD_DIR)
	@TB_FILE=$$( [ -f testbench/tb_$*.sv ] && echo "testbench/tb_$*.sv" || echo "testbench/$*.sv" ); \
	VCD_PATH="$(VCD_DIR)/$*.vcd"; \
	echo "Compiling and running: $$TB_FILE -> $$VCD_PATH"; \
	$(IVERILOG) $(FLAGS) -DVCD_FILE=\"$$VCD_PATH\" -o $(OUTPUT_DIR)/$*.vvp $(RTL_SRCS) $$TB_FILE && \
	$(VVP) $(OUTPUT_DIR)/$*.vvp

# ------------------------------------------------------------------------------
# Waveform Viewing Rules (GTKWave)
# ------------------------------------------------------------------------------
# Open the default waveform: make waves
waves:
	$(GTKWAVE) $(DEFAULT_VCD) &

# Open a specific waveform: make wave_alu (opens waveforms/alu.vcd)
wave_%:
	$(GTKWAVE) $(VCD_DIR)/$*.vcd &

# ------------------------------------------------------------------------------
# Cleanup Target
# ------------------------------------------------------------------------------
clean:
	rm -rf $(OUTPUT_DIR) $(VCD_DIR)