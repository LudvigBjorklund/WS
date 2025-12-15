## ======================
## FOLDER PATHS
## ======================
CURRENT_DIR = $(shell pwd)
# Extract the base path by going up to "Digital Twin" directory
BASE_PATH = $(shell echo $(CURRENT_DIR) | sed 's|\(.*Digital Twin\).*|\1|')

TB_PATH = $(CURRENT_DIR)/Test_Bench

# Get the version path by going up from test bench to the version root
VERSION_PATH = $(shell dirname $(shell dirname $(CURRENT_DIR)))


LIBRARY_PATH = /home/ludvig/Desktop/FPGA_Synthesis/0_Library

# Sub-directories of the Library
LIB_UART_PATH = $(LIBRARY_PATH)/Interface
LIB_RECEIVER_PATH = $(LIB_UART_PATH)/Receiver
LIB_TRANSCEIVER_PATH = $(LIB_UART_PATH)/Transceiver

LIB_PLATFORM_PATH = $(LIBRARY_PATH)/Platform
LIB_DATA_FILES_PATH = $(LIBRARY_PATH)/DT_Data
LIB_DEBUG_PATH = $(LIBRARY_PATH)/Debugging
LIB_ECM_LOOKUP_PATH = $(LIBRARY_PATH)/ECM_Parameters_Lookup
LIB_ECM_LOOKUP_1DLUT_PATH = $(LIB_ECM_LOOKUP_PATH)/1DLUT# LUT1D_sim.vhd, tbl_rd_ow_1D_sim.vhd, tbl_rd_reset_1D_sim.vhd
LIB_ECM_LOOKUP_2DLUT_PATH = $(LIB_ECM_LOOKUP_PATH)/2DLUT
LIB_ECM_LOOKUP_INDICES_PATH = $(LIB_ECM_LOOKUP_PATH)/Indices
#LIB_TB_PKG_PATH = $(LIBRARY_PATH)/TB_packages
LIB_ECM_PATH = $(LIBRARY_PATH)/ECM


## =========================================================================
## VHDL FILES
## =========================================================================

## ===================================
## VHDL FILES - Platform 
## ===================================
LIB_PLATFORM_FILES = "$(LIB_PLATFORM_PATH)/Common.vhd" \
"$(LIB_PLATFORM_PATH)/sim_SM.vhd" \
"$(LIB_PLATFORM_PATH)/simulation_time.vhd"

## ===================================
## VHDL FILES - Data Files 
## ===================================
LIB_DATA_FILES = "$(LIB_DATA_FILES_PATH)/ConfigurationData.vhd" \
"$(LIB_DATA_FILES_PATH)/DT_Components_declaration.vhd"
## ===================================
## VHDL FILES - PC-FPGA Interface
## ===================================
LIB_UART_FILES = "$(LIB_UART_PATH)/DT_UART_32bit.vhd" \
## =============
## VHDL FILES - Transceiver (To the PC)
## =============
LIB_TX_FILES = "$(LIB_TRANSCEIVER_PATH)/tx.vhd" \
"$(LIB_TRANSCEIVER_PATH)/tx_32bit.vhd" \
"$(LIB_TRANSCEIVER_PATH)/DT_TX.vhd"
## =============
## VHDL FILES - Receiver (To the PC)
## =============
LIB_RX_FILES = "$(LIB_RECEIVER_PATH)/rx.vhd" \
"$(LIB_RECEIVER_PATH)/rx_4byte.vhd" \
"$(LIB_RECEIVER_PATH)/rx_route4byte.vhd" \
"$(LIB_RECEIVER_PATH)/DT_RX.vhd"
## ===================================
## VHDL FILES - ECM Lookup
## ===================================
LIB_ECM_LOOKUP_FILES = "$(LIB_ECM_LOOKUP_INDICES_PATH)/idx_calc.vhd" \
"$(LIB_ECM_LOOKUP_INDICES_PATH)/Normalizer.vhd" \
"$(LIB_ECM_LOOKUP_1DLUT_PATH)/tbl_rd_ow_1D_sim.vhd" \
"$(LIB_ECM_LOOKUP_1DLUT_PATH)/tbl_rd_reset_1D_sim.vhd" \
"$(LIB_ECM_LOOKUP_1DLUT_PATH)/LUT1D_sim.vhd" \
"$(LIB_ECM_LOOKUP_2DLUT_PATH)/tbl_read_ow_sim.vhd" \
"$(LIB_ECM_LOOKUP_2DLUT_PATH)/tbl_reset_rd_sim.vhd" \
"$(LIB_ECM_LOOKUP_2DLUT_PATH)/LUT2D_sim.vhd" \
"$(LIB_ECM_LOOKUP_PATH)/ECM_Parameters_sim.vhd"

LIB_DEBUG_FILES = "$(LIB_DEBUG_PATH)/bcd.vhd" \
"$(LIB_DEBUG_PATH)/hex_digits.vhd" \
"$(LIB_DEBUG_PATH)/hex_to_int.vhd" \
"$(LIB_DEBUG_PATH)/hex_to_dbg_val.vhd"

LIB_ECM_CELL_FILES = "$(LIB_ECM_PATH)/Calc_SOC.vhd" \
"$(LIB_ECM_PATH)/dV_R0.vhd" \
"$(LIB_ECM_PATH)/dV_RC.vhd" \
"$(LIB_ECM_PATH)/ECM_Cell_sim.vhd"


# Test Bench Files - Now configurable
FOLDER_NAME_INPUT = 1_Added_HEX_Display# Default folder name; override with make FOLDER_NAME_INPUT="folder_name"
TB_FILE ?= "$(TB_PATH)/$(FOLDER_NAME_INPUT)/tb_DT.vhd"  # Default testbench; override with make TB_FILE="path/to/tb.vhd"
TB_FILES = $(TB_FILE)
# Extract testbench entity name from file (assumes filename without extension is entity)
TB = tb_DT

TL_FILE = "$(CURRENT_DIR)/DigitalTwin.vhd"
## =========================================================================
## SIMULATION SETTINGS
## =========================================================================

# Default stop time
STOP_TIME = 50us

# Conditional stop time based on folder name in TB_FILE path
# ifneq (,$(findstring 1_Added_HEX_Display,$(TB_FILE)))
#     STOP_TIME = 200ns
# endif
# Add more conditions as needed, e.g.:
# ifneq (,$(findstring another_folder_name,$(TB_FILE)))
#     STOP_TIME = 100ns
# endif

WAVEFORM_FILE = "$(TB)_waveform.vcd"
GTK=gtk_settings.sav


all: analyze elaborate run view

analyze:
	@echo "Starting analysis of VHDL files..."

	@ghdl -a $(LIB_PLATFORM_FILES)
	@echo "Successfully analyzed Platform Files."
	@ghdl -a $(LIB_DATA_FILES)
	@echo "Successfully analyzed Data Files."
	@ghdl -a $(LIB_DEBUG_FILES)
	@echo "Successfully analyzed Debugging Files."
	@ghdl -a $(LIB_TX_FILES)
	@echo "Successfully analyzed Transmitter Files."
	@ghdl -a $(LIB_RX_FILES)
	@echo "Successfully analyzed Receiver Files."
	@ghdl -a $(LIB_UART_FILES)
	@echo "Successfully analyzed UART Files."
	@ghdl -a $(LIB_ECM_LOOKUP_FILES)
	@echo "Successfully analyzed ECM Lookup Files."
	@ghdl -a $(LIB_ECM_CELL_FILES)
	@echo "Successfully analyzed ECM Cell Files."
	@ghdl -a $(TB_FILES)
	@echo "Successfully analyzed Test Bench Files."
	@ghdl -a $(TL_FILE)
	@echo "Successfully analyzed Top-Level Component ."
	@echo "Analysis complete. All Files Added to Work"
elaborate:
	ghdl -e $(TB)

run:
	ghdl -r $(TB) $(TEST_FLAGS) --vcd=$(WAVEFORM_FILE) --stop-time=$(STOP_TIME) 
	@echo "Simulation complete. Waveform saved to $(WAVEFORM_FILE)"

view:
	gtkwave $(WAVEFORM_FILE) $(GTK)


# ...existing code...

# Add this new target at the end of the file
debug-paths:
	@echo "CURRENT_DIR: $(CURRENT_DIR)"
	@echo "BASE_PATH: $(BASE_PATH)"
	@echo "TB_PATH: $(TB_PATH)"
	@echo "VERSION_PATH: $(VERSION_PATH)"
	@echo "LIBRARY_PATH: $(LIBRARY_PATH)"
	@echo "LIB_UART_PATH: $(LIB_UART_PATH)"
	@echo "LIB_RECEIVER_PATH: $(LIB_RECEIVER_PATH)"
	@echo "LIB_TRANSCEIVER_PATH: $(LIB_TRANSCEIVER_PATH)"
	@echo "LIB_PLATFORM_PATH: $(LIB_PLATFORM_PATH)"
	@echo "LIB_DATA_FILES_PATH: $(LIB_DATA_FILES_PATH)"
	@echo "LIB_DEBUG_PATH: $(LIB_DEBUG_PATH)"
	@echo "LIB_ECM_LOOKUP_PATH: $(LIB_ECM_LOOKUP_PATH)"
	@echo "LIB_ECM_LOOKUP_1DLUT_PATH: $(LIB_ECM_LOOKUP_1DLUT_PATH)"
	@echo "LIB_ECM_LOOKUP_2DLUT_PATH: $(LIB_ECM_LOOKUP_2DLUT_PATH)"
	@echo "LIB_ECM_LOOKUP_INDICES_PATH: $(LIB_ECM_LOOKUP_INDICES_PATH)"
	@echo "LIB_ECM_PATH: $(LIB_ECM_PATH)"
	@echo "TB_FILE: $(TB_FILE)"
	@echo "TB: $(TB)"
	@echo "STOP_TIME: $(STOP_TIME)"
	@echo "ALL VHDL FILES EXCEPT TOP-LEVEL:"
	@echo "TL_FILE: $(TL_FILE)"
