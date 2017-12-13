#############################################################
# Makefile geral para simulacao da Hybrid HeMPS no ambiente Nupedee
#############################################################
HEMPS_PATH=~/srcs/7.2
UNISIM_PATH=~/srcs/xilinx/src/hemps_unisim
XILINX=~/srcs/xilinx
LIB=wrklib
CDS_INST_DIR=/home/tools/cadence/installs/INCISIVE152
# this environment variable must point to the hemps path, where the hardware,
# software and tools folders are located
BASE_PATH=$(HEMPS_PATH)
HW_PATH=$(BASE_PATH)/hardware

#VHDL Files
PKG_SRC=HeMPS_defaults.vhd
PKG_DIR=$(HW_PATH)/top
PKG_PATH=$(addprefix $(PKG_DIR)/,$(PKG_SRC))

SCENARIO_SRC=HeMPS_PKG.vhd #repository.vhd
SCENARIO_DIR=.
SCENARIO_PATH=$(addprefix $(SCENARIO_DIR)/,$(SCENARIO_SRC))

MPACK_SRC=mlite_pack.vhd UartFile.vhd
MPACK_DIR=$(HW_PATH)/plasma/rtl
MPACK_PATH=$(addprefix $(MPACK_DIR)/,$(MPACK_SRC))

MLITE_SRC=alu.vhd bus_mux.vhd control.vhd mem_ctrl.vhd mult.vhd pc_next.vhd pipeline.vhd reg_bank.vhd shifter.vhd mlite_cpu.vhd
MLITE_DIR=$(HW_PATH)/plasma/rtl
MLITE_PATH=$(addprefix $(MLITE_DIR)/,$(MLITE_SRC))

DMNI_SRC=dmni.vhd
DMNI_DIR=$(HW_PATH)/dmni/rtl
DMNI_PATH=$(addprefix $(DMNI_DIR)/,$(DMNI_SRC))

ROUTER_SRC=Hermes_buffer.vhd Hermes_crossbar.vhd Hermes_switchcontrol.vhd RouterCC.vhd
ROUTER_DIR=$(HW_PATH)/router/rtl
ROUTER_PATH=$(addprefix $(ROUTER_DIR)/,$(ROUTER_SRC))

PLASMA_RAM_SRC=ram_master.vhd ram_plasma.vhd
PLASMA_RAM_DIR=$(SCENARIO_DIR)/plasma_ram/rtl
PLASMA_RAM_PATH=$(addprefix $(PLASMA_RAM_DIR)/,$(PLASMA_RAM_SRC))

PLASMA_SRC=access_repository.vhd plasma.vhd
PLASMA_DIR=$(HW_PATH)/plasma/rtl
PLASMA_PATH=$(addprefix $(PLASMA_DIR)/,$(PLASMA_SRC))

BUS_SRC_RR=bus_ctrl_hy.vhd rr_arbiter.vhd Bus_BridgeRR.vhd plasma_busRR.vhd #Bus_Wrapper.sv
BUS_DIR_RR=$(HW_PATH)/bus/bus_RR
BUS_PATH_RR=$(addprefix $(BUS_DIR_RR)/,$(BUS_SRC_RR))

CROSS_SRC=bus_arb_gen.vhd crossbar_bridge.vhd crossgen.vhd plasma_cross.vhd #Crossbar_Wrapper.sv
CROSS_DIR=$(HW_PATH)/crossbar
CROSS_PATH=$(addprefix $(CROSS_DIR)/,$(CROSS_SRC))

TOP_SRC=PE_injector.vhd processing_element.vhd HeMPS.vhd test_bench.vhd
TOP_LOG=log_tb.vhd log_h_tb.vhd
TB=tb_top_hybrid.sv tb_top_hybrid_HH.sv tb_top_hybrid_HH_comm.sv #if_logs_comm.sv
TOP_LOCAL=if_plasma.sv Bus_Wrapper.sv Crossbar_Wrapper.sv hybrid_top_setup.sv
TOP_DIR=$(HW_PATH)/top
TOP_PATH=$(addprefix $(TOP_DIR)/,$(TOP_SRC))
TB_PATH=$(addprefix $(TOP_DIR)/,$(TB))
TOP_LOCAL_PATH=$(addprefix ./,$(TOP_LOCAL))
LOG=$(addprefix $(TOP_DIR)/,$(TOP_LOG))

#/////////////
BLOCK_NAME=
DEBUG_DIR=
DUV_FILES= $(SCENARIO_PATH) $(PKG_PATH) $(MPACK_PATH) $(MLITE_PATH) $(DMNI_PATH) $(ROUTER_PATH) $(PLASMA_RAM_PATH) $(MBLITE_STD_PATH) $(MBLITE_CORE_PATH) $(MBLITE_RAM_PATH) $(MBLITE_PATH) $(PLASMA_PATH) $(BUS_PATH_RR) $(CROSS_PATH) $(TOP_PATH)
DUV_NAME=
IP_FILES=
TOP_NAME=HeMPS
ASSERT=

IUS=irun
########################## Command options #############################
ELAB_OPTS=-message -LICQUEUE -timescale 1ns/1ns
VLOG_OPTS= -sv
VHDL_OPTS=-INITZERO -nobuiltin
IRUN_OPTS=-assert -access +RW -mccodegen
SIM_OPTS=

##############################TAGS######################################
echo:
	@echo $(DUV_FILES)

compile:
	@echo "############################################################"
	@echo "##################      COMPILE Designs   ##################"
	@echo "############################################################"
	#ncvhdl -messages -work unisim -smartorder
	ncvlog $(UNISIM_PATH)/glbl.v -vtimescale 1ns/1ps
	ncvhdl -mess -v93 repository.vhd
	ncvhdl -mess -v200X -list $(DUV_FILES)
	ncvhdl -mess -v200X -list $(LOG)
	ncvlog -mess -SV $(TB_PATH) $(TOP_LOCAL_PATH) -vtimescale 1ns/1ps

unisim:
	@echo "############################################################"
	@echo "##################    COMPILE UNISIM    ####################"
	@echo "############################################################"
	ncvlog $(UNISIM_PATH)/*.v -vtimescale 1ns/1ps
	ncvhdl -work unisim -V200X $(UNISIM_PATH)/vcomponents.vhd

elab:
	@echo "############################################################"
	@echo "################## ELABORATION  HeMPS  #####################"
	@echo "############################################################"
	ncelab  -VHDLSYNC -disable_sem2009 -messages -nocopyright -libverbose -NOMXINDR -access +rwc work.test_bench work.glbl

elabh:
	@echo "############################################################"
	@echo "##################  ELABORATION HYBRID #####################"
	@echo "############################################################"
	ncelab  -VHDLSYNC -disable_sem2009 -messages -nocopyright -libverbose -NOMXINDR -access +rwc work.hemps_hybrid_tb work.glbl

sim:
	@echo "############################################################"
	@echo "##################   SIMULATION HeMPS  #####################"
	@echo "############################################################"
	ncsim -input input.in work.test_bench -gui
	@cp -R log Log_HeMPS_`date +%a_%d-%m_%H:%M:%S_%Y`

simh:
	@echo "############################################################"
	@echo "##################   SIMULATION HYBRID #####################"
	@echo "############################################################"
	ncsim -input input.in work.hemps_hybrid_tb -gui
	@cp -R log Log_Hybrid`date +%a_%d-%m_%H:%M:%S_%Y`

simnogui:
	@echo "#############################################################"
	@echo "################## SIMULATION NO GUI HYBRID #################"
	@echo "#############################################################"
	ncsim  work.hemps_hybrid_tb -input input_nogui.in
	@cp -R log Log_Hybrid_`date +%a_%d-%m_%H:%M:%S_%Y`

clean:
	@rm -r log
	@rm -rf wrklib/
	@mkdir wrklib
	@mkdir log
	@cp ~/srcs/scripts_confs/hdl.var .
	@cp ~/srcs/scripts_confs/cds.lib .
	@cp ~/srcs/scripts_confs/input.in .
	@cp ~/srcs/scripts_confs/input_nogui.in .
	@cp ~/srcs/7.2/hardware/bus/bus_RR/Bus_Wrapper.sv .
	@cp ~/srcs/7.2/hardware/crossbar/Crossbar_Wrapper.sv .
	@rm -f *.key
	@rm -f *.o
	@rm -f *.log
	@rm -f *~

clean_unisim:
	@rm -r ~/srcs/hemps_unisim/inca*