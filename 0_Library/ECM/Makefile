# Variables
VHDL_FILES = "/home/ludvig/Documents/Digital Twin/Synthesized FPGA Projects/0. Library/Platform/Common.vhd" \
"/home/ludvig/Documents/Digital Twin/Synthesized FPGA Projects/0. Library/Platform/sim_SM.vhd" \
"/home/ludvig/Documents/Digital Twin/Synthesized FPGA Projects/0. Library/Platform/simulation_time.vhd" \
"/home/ludvig/Documents/Digital Twin/Synthesized FPGA Projects/0. Library/Interface/Receiver/DT_RX.vhd" \
"/home/ludvig/Documents/Digital Twin/Synthesized FPGA Projects/0. Library/Interface/Receiver/rx.vhd" \
"/home/ludvig/Documents/Digital Twin/Synthesized FPGA Projects/0. Library/Interface/Receiver/rx_4byte.vhd" \
"/home/ludvig/Documents/Digital Twin/Synthesized FPGA Projects/0. Library/Interface/Receiver/rx_route4byte.vhd" \
"/home/ludvig/Documents/Digital Twin/Synthesized FPGA Projects/0. Library/Interface/Receiver/rx_signal_router.vhd" \
"/home/ludvig/Documents/Digital Twin/Synthesized FPGA Projects/0. Library/Interface/Transceiver/DT_TX.vhd"\
"/home/ludvig/Documents/Digital Twin/Synthesized FPGA Projects/0. Library/Interface/Transceiver/tx_32bit.vhd"\
"/home/ludvig/Documents/Digital Twin/Synthesized FPGA Projects/0. Library/Interface/Transceiver/tx.vhd"\
"/home/ludvig/Documents/Digital Twin/Synthesized FPGA Projects/0. Library/Debugging/bcd.vhd" \
"/home/ludvig/Documents/Digital Twin/Synthesized FPGA Projects/0. Library/Debugging/hex_digits.vhd" \
"/home/ludvig/Documents/Digital Twin/Synthesized FPGA Projects/0. Library/Debugging/prepare_for_bcd0EN16.vhd" \
"/home/ludvig/Documents/Digital Twin/Synthesized FPGA Projects/0. Library/ECM_Parameters_Lookup/Indices/idx_calc.vhd" \
"/home/ludvig/Documents/Digital Twin/Synthesized FPGA Projects/0. Library/ECM_Parameters_Lookup/Indices/Normalizer.vhd" \
"/home/ludvig/Documents/Digital Twin/Synthesized FPGA Projects/0. Library/ECM_Parameters_Lookup/2DLUT/LUT2D_sim.vhd" \
"/home/ludvig/Documents/Digital Twin/Synthesized FPGA Projects/0. Library/ECM_Parameters_Lookup/2DLUT/tbl_read_ow_sim.vhd" \
"/home/ludvig/Documents/Digital Twin/Synthesized FPGA Projects/0. Library/ECM_Parameters_Lookup/2DLUT/tbl_reset_rd_sim.vhd" \
"/home/ludvig/Documents/Digital Twin/Synthesized FPGA Projects/0. Library/ECM_Parameters_Lookup/ECM_Parameters_sim.vhd" \
"/home/ludvig/Documents/Digital Twin/Synthesized FPGA Projects/0. Library/ECM/Calc_SOC.vhd" \
"/home/ludvig/Documents/Digital Twin/Synthesized FPGA Projects/0. Library/ECM/dV_RC.vhd" \
"/home/ludvig/Documents/Digital Twin/Synthesized FPGA Projects/0. Library/ECM/dV_R0.vhd" \
ECM_Cell.vhd \
ECM_Cell_tb.vhd
TB_NAME = ECM_Cell_tb
WAVEFORM_FILE = ECM_Cell_tb.vcd
GTK_SETTINGS_DIR = "GTK"
GTK_SETTINGS = $(GTK_SETTINGS_DIR)/gtk_settings.sav

STOP_TIME = 50us

# Targets
all: analyze elaborate run view

analyze:
	ghdl -a $(VHDL_FILES)

elaborate:
	ghdl -e $(TB_NAME)

run: analyze elaborate
	ghdl -r $(TB_NAME) --vcd=$(WAVEFORM_FILE) --stop-time=$(STOP_TIME)

view:
	gtkwave $(WAVEFORM_FILE) $(GTK_SETTINGS)

clean:
	rm -f $(TB_NAME) $(TB_NAME).cf $(WAVEFORM_FILE) 