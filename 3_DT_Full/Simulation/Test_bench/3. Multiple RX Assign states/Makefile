# Cocotb Makefile for DigitalTwin VHDL simulation

# Simulator (use GHDL, as in your main Makefile)
SIM ?= ghdl
GTK ?= gtk_settings.sav

# Simulation stop time
SIM_TIME ?= 200us

# Language
TOPLEVEL_LANG ?= vhdl

# Top-level entity (use lowercase to match GHDL's instance naming)
TOPLEVEL = digitaltwin

# Python test module (updated for deprecation warning)
COCOTB_TEST_MODULES? = tb_multiple_rx_assign_states

# VHDL sources (absolute paths for reliability)
VHDL_SOURCES += /home/ludvig/Desktop/FPGA_Synthesis/3_DT_Full/Simulation/DigitalTwin.vhd
VHDL_SOURCES += /home/ludvig/Desktop/FPGA_Synthesis/0_Library/Platform/Common.vhd
VHDL_SOURCES += /home/ludvig/Desktop/FPGA_Synthesis/0_Library/Platform/sim_SM.vhd
VHDL_SOURCES += /home/ludvig/Desktop/FPGA_Synthesis/0_Library/Platform/simulation_time.vhd
VHDL_SOURCES += /home/ludvig/Desktop/FPGA_Synthesis/0_Library/DT_Data/ConfigurationData.vhd
VHDL_SOURCES += /home/ludvig/Desktop/FPGA_Synthesis/0_Library/DT_Data/DT_Components_declaration.vhd
VHDL_SOURCES += /home/ludvig/Desktop/FPGA_Synthesis/0_Library/DT_Data/DT_IDs.vhd
VHDL_SOURCES += /home/ludvig/Desktop/FPGA_Synthesis/0_Library/DT_Data/DT_Parameters.vhd
VHDL_SOURCES += /home/ludvig/Desktop/FPGA_Synthesis/0_Library/DT_Data/fixed_point_formats.vhd
VHDL_SOURCES += /home/ludvig/Desktop/FPGA_Synthesis/0_Library/DT_Data/num_of_bits.vhd
VHDL_SOURCES += /home/ludvig/Desktop/FPGA_Synthesis/0_Library/DT_Data/Transceiver_configuration.vhd
VHDL_SOURCES += /home/ludvig/Desktop/FPGA_Synthesis/0_Library/Debugging/bcd.vhd
VHDL_SOURCES += /home/ludvig/Desktop/FPGA_Synthesis/0_Library/Debugging/hex_digits.vhd
VHDL_SOURCES += /home/ludvig/Desktop/FPGA_Synthesis/0_Library/Debugging/hex_to_dbg_val.vhd
VHDL_SOURCES += /home/ludvig/Desktop/FPGA_Synthesis/0_Library/Debugging/hex_to_int.vhd
VHDL_SOURCES += /home/ludvig/Desktop/FPGA_Synthesis/0_Library/Debugging/prepare_for_bcd0EN16.vhd
VHDL_SOURCES += /home/ludvig/Desktop/FPGA_Synthesis/0_Library/ECM/Calc_SOC.vhd
VHDL_SOURCES += /home/ludvig/Desktop/FPGA_Synthesis/0_Library/ECM/dV_R0.vhd
VHDL_SOURCES += /home/ludvig/Desktop/FPGA_Synthesis/0_Library/ECM/dV_RC.vhd
VHDL_SOURCES += /home/ludvig/Desktop/FPGA_Synthesis/0_Library/ECM/ECM_Cell_sim.vhd
VHDL_SOURCES += /home/ludvig/Desktop/FPGA_Synthesis/0_Library/ECM_Parameters_Lookup/ECM_Parameters_sim.vhd
VHDL_SOURCES += /home/ludvig/Desktop/FPGA_Synthesis/0_Library/ECM_Parameters_Lookup/1DLUT/LUT1D_sim.vhd
VHDL_SOURCES += /home/ludvig/Desktop/FPGA_Synthesis/0_Library/ECM_Parameters_Lookup/1DLUT/tbl_rd_ow_1D_sim.vhd
VHDL_SOURCES += /home/ludvig/Desktop/FPGA_Synthesis/0_Library/ECM_Parameters_Lookup/1DLUT/tbl_rd_reset_1D_sim.vhd
VHDL_SOURCES += /home/ludvig/Desktop/FPGA_Synthesis/0_Library/ECM_Parameters_Lookup/2DLUT/LUT2D_sim.vhd
VHDL_SOURCES += /home/ludvig/Desktop/FPGA_Synthesis/0_Library/ECM_Parameters_Lookup/2DLUT/tbl_read_ow_sim.vhd
VHDL_SOURCES += /home/ludvig/Desktop/FPGA_Synthesis/0_Library/ECM_Parameters_Lookup/2DLUT/tbl_reset_rd_sim.vhd
VHDL_SOURCES += /home/ludvig/Desktop/FPGA_Synthesis/0_Library/ECM_Parameters_Lookup/Indices/idx_calc.vhd
VHDL_SOURCES += /home/ludvig/Desktop/FPGA_Synthesis/0_Library/ECM_Parameters_Lookup/Indices/Normalizer.vhd
VHDL_SOURCES += /home/ludvig/Desktop/FPGA_Synthesis/0_Library/Interface/DT_UART_32bit.vhd
VHDL_SOURCES += /home/ludvig/Desktop/FPGA_Synthesis/0_Library/Interface/Transceiver/DT_TX.vhd
VHDL_SOURCES += /home/ludvig/Desktop/FPGA_Synthesis/0_Library/Interface/Transceiver/tx.vhd
VHDL_SOURCES += /home/ludvig/Desktop/FPGA_Synthesis/0_Library/Interface/Transceiver/tx_32bit.vhd
VHDL_SOURCES += /home/ludvig/Desktop/FPGA_Synthesis/0_Library/Interface/Receiver/DT_RX.vhd
VHDL_SOURCES += /home/ludvig/Desktop/FPGA_Synthesis/0_Library/Interface/Receiver/rx.vhd
VHDL_SOURCES += /home/ludvig/Desktop/FPGA_Synthesis/0_Library/Interface/Receiver/rx_4byte.vhd
VHDL_SOURCES += /home/ludvig/Desktop/FPGA_Synthesis/0_Library/Interface/Receiver/rx_route4byte.vhd


# Set VHDL generics
#PLUSARGS += -g g_clk_rate=3

# Add this for elaboration (to include all signals)
GHDL_ELAB_FLAGS += --vcd-all

# Update SIM_ARGS for run (remove --vcd-all)
SIM_ARGS += --vcd=waveform.vcd
#SIM_ARGS += --stop-time=$(SIM_TIME)

# Include cocotb's standard simulation Makefile
#include $(shell cocotb-config --makefiles)/Makefile.sim
include $(shell cocotb-config --makefiles)/Makefile.sim


# View target: open waveform in GTKWave
.PHONY: view
view:
	gtkwave waveform.vcd $(GTK) &

# Custom all target: run sim (ignoring errors), then view
.PHONY: all
all:
	@echo "Starting all target - running sim and then view"
	(make sim || true) && make view

