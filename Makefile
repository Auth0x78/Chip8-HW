# Makefile for Icarus Verilog with Header Support

# Base output paths
OUTPUT_DIR := build
VCD_DIR    := waveforms

INC_DIR    := include   # Folder containing .vh / header files

# Find source files
RTL_SRCS := $(wildcard rtl/*.v) $(wildcard rtl/**/*.v)
TB_SRCS  := $(wildcard testbench/*.v)
HDRS     := $(wildcard $(INC_DIR)/*.vh) $(wildcard rtl/**/*.vh)

DEFAULT_TB := testbench/tb.v
SIM_OUT    := $(OUTPUT_DIR)/test_sim.vvp

# Global fallback VCD path
DEFAULT_VCD := $(VCD_DIR)/default.vcd

IVERILOG   := iverilog
VVP        := vvp
GTKWAVE    := gtkwave

# Include flags for Icarus Verilog
FLAGS      := -g2012 -I$(INC_DIR) -DVCD_DIR=\"$(VCD_DIR)\"

.PHONY: all sim waves wave_% clean

all: sim

# Directories creation rule
$(OUTPUT_DIR) $(VCD_DIR):
	@mkdir $@

# Default simulation rule
sim: $(RTL_SRCS) $(DEFAULT_TB) $(HDRS) | $(OUTPUT_DIR) $(VCD_DIR)
	$(IVERILOG) $(FLAGS) \
		-DVCD_FILE=\"$(DEFAULT_VCD)\" \
		-o $(SIM_OUT) \
		$(RTL_SRCS) \
		$(DEFAULT_TB)
	$(VVP) $(SIM_OUT)

# Pattern Rule for specific testbenches (e.g., make test_alu)
# Generates $(VCD_DIR)/<name>.vcd
test_%: $(RTL_SRCS) $(HDRS) | $(OUTPUT_DIR) $(VCD_DIR)
	@TB_FILE=$$( [ -f testbench/tb_$*.v ] && echo "testbench/tb_$*.v" || echo "testbench/$*.v" ); \
	VCD_PATH="$(VCD_DIR)/$*.vcd"; \
	echo "Compiling and running: $$TB_FILE -> $$VCD_PATH"; \
	$(IVERILOG) $(FLAGS) -DVCD_FILE=\"$$VCD_PATH\" -o $(OUTPUT_DIR)/$*.vvp $(RTL_SRCS) $$TB_FILE && \
	$(VVP) $(OUTPUT_DIR)/$*.vvp

# Global waveform rule (opens the default waveform)
waves:
	$(GTKWAVE) $(DEFAULT_VCD) &

# Specific waveform rule (e.g., make wave_alu opens waveforms/alu.vcd)
wave_%:
	$(GTKWAVE) $(VCD_DIR)/$*.vcd &

clean:
	rm -rf $(OUTPUT_DIR) $(VCD_DIR)