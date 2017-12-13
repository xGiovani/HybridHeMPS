#!/usr/bin/perl
# hexadec.pl
use POSIX;
use Data::Dumper qw(Dumper);

print "
  _   _      __  __ ____  ____    _____ 
 | | | | ___|  \\/  |  _ \\/ ___|  |___  |
 | |_| |/ _ \\ |\\/| | |_) \\___ \\     / / 
 |  _  |  __/ |  | |  __/ ___) |   / /  
 |_| |_|\\___|_|  |_|_|   |____/   /_/   
                                        
";

$path_applications=".";
#$app_repo_size = 60000;
$kernelSize=32;
$NoC_buffer_size=8;
$NoC_routing_algorithm="xy"; 
$hempsPath = $ENV{"HEMPS_PATH"};

	if ($hempsPath eq ""){
		print "
		Enviroment variable: HEMPS_PATH not defined.
		Please define in your .barch file:
		export HEMPS_PATH=<hemps root directory>
		export PATH=\$PATH:\$HEMPS_PATH/bin 
		";
		exit;
	} elsif ($ARGV[0] ne "") {

		$path = shift; 		    #caminho do projeto ou HMP		
		$path_applications = shift; #caminho das aplicacoes
		
	}

	else {
          print "

         Main script of the HeMPS platform
         
         Input:  project description (hmp file - see https://corfu.pucrs.br/redmine/projects/hemps/wiki)
               
         Usage:   hemps.pl <test>.hmp  [optional: path to the application]
         
         This step is responsible to compile the software (kernel and user applications) in the <test>/build. 
	 Any modification in the software may be done by using the makefile inside the build directory.
         
         Applications are search in the following order: (1) path specified by the user (if present); 
	 (2) current directory; (3) repository installation
         
          
         NEXT: 
         It is necessary to create the platform (i.e. - create the hardware): cd <test>;  make all

    	 THEN:
     	 Execute the applications specified in the project description:  ./HeMPS -c 10
     	 -c parameter corresponds to the simulation time in ms

     	 At the end of the execution it is expected the following message:

	        END OF ALL APPLICATIONS!!!
	        SystemC: simulation stopped by user.
	        END OF ALL APPLICATIONS!!!

         Tools to debug:  hemps-read.pl <test>.hmp, hemps-debugger; hemps-trace \n\n" ;


	  exit;
	}

# READ HMP FILE
($projectName, $pagesPerPe, $memorySize, $pageSize, $procDescription,
$x_dimensions, $y_dimensions, $x_cluster, $y_cluster, $injector_flag,
$bus_count, $proc_per_bus, $bus_position,
$crossbar_count, $proc_per_crossbar, $crossbar_position,
$mastersLocation, $masterCluster) = read_hmp_file($path);

# CREATE CLUSTERS
create_clusters();

# SET PROCESSORS TYPE
set_processors_type();

# CREATE PROJECT
create_project();

# READ APPLICATIONS INFO
read_applications_info();

# TASK DEPENDENCES
initial_tasks();

# CREATE HYBRID TOP SETUP AND INTERFACE FILES
generate_hybrid_top_setup();

# Generate HyMap.h
generate_hybrid_map();

# FIRST TIME  #######################
if($pagesPerPe > 0) {
	# PARAMETERS MEMORY
	parameters_memory_fake();

	# PARAMETERS NoC
	parameters_NoC();

	# Generates HeMPS_PKG
	generate_Hemps_PKG();

	#Generates application IDs files
	generate_app_id_files();

	#Generates ids_master.h
	generate_ids_master();

	#Generates ids_slave.h
	generate_ids_slave();

	#Generates hemps_param.h
	generate_hemps_param();

	# Generates makefile software
	generate_makefile_software();
	
	# PARAMETERS MEMORY
	parameters_memory();

	#Generates ids_master.h
	generate_ids_master();

	#Generates ids_slave.h
	generate_ids_slave();

	#Generates hemps_param.h
	generate_hemps_param();

	# Generates HeMPS_PKG
	generate_Hemps_PKG();

	# Generates makefile software
	generate_makefile_software();
}
else{
	# PARAMETERS MEMORY
	parameters_memory_per_memory_size();

	# PARAMETERS NoC
	parameters_NoC();

	# Generates HeMPS_PKG
	generate_Hemps_PKG();

	#Generates application IDs files
	generate_app_id_files();

	#Generates ids_master.h
	generate_ids_master();

	#Generates ids_slave.h
	generate_ids_slave();

	#Generates hemps_param.h
	generate_hemps_param();

	# Generates makefile software
	generate_makefile_software();
}

# Generates makefile hardware
generate_makefile_hardware();

# Generates sim.do
generate_sim_do();

# Generates wave.do
#generate_wave_do();

#Generates Repositories
repositories();

#Generates Debugger files
generate_debugger_files();

#################################################################################################
################################## Generate Hybrid Hemps Top Setup ##############################
#################################################################################################

sub generate_hybrid_top_setup{

	my @bus_position = @$bus_position;
	my @proc_per_bus = @$proc_per_bus;
	my @crossbar_position = @$crossbar_position;
	my @proc_per_crossbar = @$proc_per_crossbar;

	open( C_FILE_SV, ">./$projectName/hybrid_top_setup.sv" );
	
	print C_FILE_SV "// Hybrid HeMPS Top File\n";
	print C_FILE_SV "// NoC Size: ".$x_dimensions."x".$y_dimensions."\n";
	if($injector_flag==1){
		print C_FILE_SV "// This NoC has Message Injectors!\n";
	}
	else{
		print C_FILE_SV "// No Message injectors!\n";
	}
	
	for($x=0; $x<$bus_count; $x++){
		$bus_proc_count = $bus_proc_count+@proc_per_bus[$x];
	}
	for($x=0; $x<$crossbar_count; $x++){
		$crossbar_proc_count = $crossbar_proc_count+@proc_per_crossbar[$x];
	}
	$totalProcessors = $x_dimensions*$y_dimensions+$bus_proc_count-$bus_count+$crossbar_proc_count-$crossbar_count;
	print C_FILE_SV "// Total Processors: ".$totalProcessors."\n";
	
	# Bus Informations
	print C_FILE_SV "// Number of bus(es) connected on NoC: ".$bus_count."\n";
	print C_FILE_SV "// Bus(es) Connected on position(s): ";
	for($x=0; $x<$bus_count; $x++){
		print C_FILE_SV "@bus_position[$x]";
		if($x != $bus_count-1){
			print C_FILE_SV ",";
		}
	}
	print C_FILE_SV "\n// Number of Processors on each Bus: ";
	for($x=0; $x<$bus_count; $x++){
		print C_FILE_SV "@proc_per_bus[$x]";
		if($x != $bus_count-1){
			print C_FILE_SV ",";
		}
	}
	# Crossbar Informations
	print C_FILE_SV "\n// Number of crossbar(s) connected on NoC: ".$crossbar_count."\n";
	print C_FILE_SV "// Crossbar(s) Connected on position(s): ";
	for($x=0; $x<$crossbar_count; $x++){
		print C_FILE_SV "@crossbar_position[$x]";
		if($x != $crossbar_count-1){
			print C_FILE_SV ",";
		}
	}
	print C_FILE_SV "\n// Number of Processors on each Crossbar: ";
	for($x=0; $x<$crossbar_count; $x++){
		print C_FILE_SV "@proc_per_crossbar[$x]";
		if($x != $crossbar_count-1){
			print C_FILE_SV ",";
		}
	}
	print C_FILE_SV "\n\n";
	
	print C_FILE_SV "import HeMPS_defaults::*;\n\n";
	print C_FILE_SV "module Hybrid_top(\n";
	print C_FILE_SV "\tinput clock,\n";
	print C_FILE_SV "\tinput reset\n";
	print C_FILE_SV ");\n\n";
	
	################### Clock_tx and clock_rx for slaves on NoC ###################
	print C_FILE_SV " // Connection's Wires on NoC\n\n";
	print C_FILE_SV " // clock_tx and clock_rx\n";
	print C_FILE_SV " wire logic[4:0] ";
	for($i=1; $i<$x_dimensions*$y_dimensions; $i++){
		print C_FILE_SV "clock_tx_r$i";
			if($i != $x_dimensions*$y_dimensions-1){
			print C_FILE_SV ", ";
		}
	}
	print C_FILE_SV ";\n";
	
	print C_FILE_SV " wire logic[4:0] ";
	for($i=1; $i<$x_dimensions*$y_dimensions; $i++){
		print C_FILE_SV "clock_rx_r$i";
			if($i != $x_dimensions*$y_dimensions-1){
			print C_FILE_SV ", ";
		}
	}
	print C_FILE_SV ";\n";
	
	## Master signals
	print C_FILE_SV " wire logic[4:0] clock_tx_m, clock_rx_m;\n";
	
	## Bus/Crossbar Wrapper signals
	## tx
	if($bus_count>0){print C_FILE_SV " wire logic[4:0] "};
	$i=0;
	while($i<$bus_count){
		print C_FILE_SV "clock_tx_bus_wp$i";
		if($i != $bus_count-1){print C_FILE_SV ", ";}
		$i++;
		if($i == $bus_count){print C_FILE_SV ";\n";}
	}
	
	if($crossbar_count>0){print C_FILE_SV " wire logic[4:0] ";}
	$i=0;
	while($i<$crossbar_count){
		print C_FILE_SV "clock_tx_crossbar_wp$i";
		if($i != $crossbar_count-1){print C_FILE_SV ", ";}
		$i++;
		if($i == $crossbar_count){print C_FILE_SV ";\n";}
	}

	## rx
	if($bus_count>0){print C_FILE_SV " wire logic[4:0] "};
	$i=0;
	while($i<$bus_count){
		print C_FILE_SV "clock_rx_bus_wp$i";
		if($i != $bus_count-1){print C_FILE_SV ", ";}
		$i++;
		if($i == $bus_count){print C_FILE_SV ";\n";}
	}
	if($crossbar_count>0){print C_FILE_SV " wire logic[4:0] "};
	$i=0;
	while($i<$crossbar_count){
		print C_FILE_SV "clock_rx_crossbar_wp$i";
		if($i != $crossbar_count-1){print C_FILE_SV ", ";}
		$i++;
		if($i == $crossbar_count){print C_FILE_SV ";\n";}
	}
	
	######### Tx and Rx Signals ###############################
	print C_FILE_SV " // Tx and Rx signals\n";
	print C_FILE_SV " wire [4:0] ";
	for($i=1; $i<$x_dimensions*$y_dimensions; $i++){
		print C_FILE_SV "tx_r$i";
			if($i != $x_dimensions*$y_dimensions-1){
			print C_FILE_SV ", ";
		}
	}
	print C_FILE_SV ";\n";	
	print C_FILE_SV " wire [4:0] ";
	for($i=1; $i<$x_dimensions*$y_dimensions; $i++){
		print C_FILE_SV "rx_r$i";
			if($i != $x_dimensions*$y_dimensions-1){
			print C_FILE_SV ", ";
		}
	}
	print C_FILE_SV ";\n";
	
	## Master signals
	print C_FILE_SV " wire [4:0] tx_m, rx_m;\n";
	
	## Bus/Crossbar Wrapper Signals
	# Tx wrappers
	if($bus_count>0){print C_FILE_SV " wire [4:0] ";}
	$i=0;
	while($i<$bus_count){
		print C_FILE_SV "tx_bus_wp$i";
		if($i != $bus_count-1){print C_FILE_SV ", ";}
		$i++;
		if($i == $bus_count){print C_FILE_SV ";\n";}
	}
	
	if($crossbar_count>0){print C_FILE_SV " wire [4:0] ";}
	$i=0;
	while($i<$crossbar_count){
		print C_FILE_SV "tx_crossbar_wp$i";
		if($i != $crossbar_count-1){print C_FILE_SV ", ";}
		$i++;
		if($i == $crossbar_count){print C_FILE_SV ";\n";}
	}
	# Rx wrappers
	if($bus_count>0){print C_FILE_SV " wire [4:0] ";}
	$i=0;
	while($i<$bus_count){
		print C_FILE_SV "rx_bus_wp$i";
		if($i != $bus_count-1){print C_FILE_SV ", ";}
		$i++;
		if($i == $bus_count){print C_FILE_SV ";\n";}
	}
	if($crossbar_count>0){print C_FILE_SV " wire [4:0] ";}
	$i=0;
	while($i<$crossbar_count){
		print C_FILE_SV "rx_crossbar_wp$i";
		if($i != $crossbar_count-1){print C_FILE_SV ", ";}
		$i++;
		if($i == $crossbar_count){print C_FILE_SV ";\n";}
	}
	
	######### Credits Signals ###############################
	print C_FILE_SV " // Credit signals\n";
	print C_FILE_SV " wire logic[4:0] ";
	for($i=1; $i<$x_dimensions*$y_dimensions; $i++){
		print C_FILE_SV "credit_i_r$i";
			if($i != $x_dimensions*$y_dimensions-1){
			print C_FILE_SV ", ";
		}
	}
	print C_FILE_SV ";\n";
	
	print C_FILE_SV " wire logic[4:0] ";
	for($i=1; $i<$x_dimensions*$y_dimensions; $i++){
		print C_FILE_SV "credit_o_r$i";
			if($i != $x_dimensions*$y_dimensions-1){
			print C_FILE_SV ", ";
		}
	}
	print C_FILE_SV ";\n";
	
	## Master signals
	print C_FILE_SV " wire logic[4:0] credit_i_m, credit_o_m;\n";
	
	## Bus/Crossbar Wrapper signals
	if($bus_count>0){print C_FILE_SV " wire logic[4:0] ";}
	$i=0;
	while($i<$bus_count){
		print C_FILE_SV "credit_i_bus_wp$i";
		if($i != $bus_count-1){print C_FILE_SV ", ";}
		$i++;
		if($i == $bus_count){print C_FILE_SV ";\n";}
	}
	
	if($crossbar_count>0){print C_FILE_SV " wire logic[4:0] ";}
	$i=0;
	while($i<$crossbar_count){
		print C_FILE_SV "credit_i_crossbar_wp$i";
		if($i != $crossbar_count-1){print C_FILE_SV ", ";}
		$i++;
		if($i == $crossbar_count){print C_FILE_SV ";\n";}
	}
	
	if($bus_count>0){print C_FILE_SV " wire logic[4:0] ";}
	$i=0;
	while($i<$bus_count){
		print C_FILE_SV "credit_o_bus_wp$i";
		if($i != $bus_count-1){print C_FILE_SV ", ";}
		$i++;
		if($i == $bus_count){print C_FILE_SV ";\n"}
	}
	
	if($crossbar_count>0){print C_FILE_SV " wire logic[4:0] ";}
	$i=0;
	while($i<$crossbar_count){
		print C_FILE_SV "credit_o_crossbar_wp$i";
		if($i != $crossbar_count-1){print C_FILE_SV ", ";}
		$i++;
		if($i == $crossbar_count){print C_FILE_SV ";\n";}
	}
	
	########### Data I/O Signals ######################
	print C_FILE_SV " // Data I/O signals\n";
	print C_FILE_SV " wire regflit[4:0] ";
	for($i=1; $i<$x_dimensions*$y_dimensions; $i++){
		print C_FILE_SV "data_in_r$i";
			if($i != $x_dimensions*$y_dimensions-1){
			print C_FILE_SV ", ";
		}
	}
	print C_FILE_SV ";\n";
	
	print C_FILE_SV " wire regflit[4:0] ";
	for($i=1; $i<$x_dimensions*$y_dimensions; $i++){
		print C_FILE_SV "data_out_r$i";
			if($i != $x_dimensions*$y_dimensions-1){
			print C_FILE_SV ", ";
		}
	}
	print C_FILE_SV ";\n";
	
	## Master signals
	print C_FILE_SV " wire regflit[4:0] data_in_m, data_out_m;\n";
	
	## Bus Wrapper signals
	if($bus_count>0){print C_FILE_SV " wire regflit[4:0] ";}
	$i=0;
	while($i<$bus_count){
		print C_FILE_SV "data_in_bus_wp$i";
		if($i != $bus_count-1){print C_FILE_SV ", ";}
		$i++;
		if($i == $bus_count){print C_FILE_SV ";\n";}
	}
	$i=0;
	
	if($crossbar_count>0){print C_FILE_SV " wire regflit[4:0] ";}
	while($i<$crossbar_count){
		print C_FILE_SV "data_in_crossbar_wp$i";
		if($i != $crossbar_count-1){print C_FILE_SV ", ";}
		$i++;
		if($i == $crossbar_count){print C_FILE_SV ";\n";}
	}
	
	if($bus_count>0){print C_FILE_SV " wire regflit[4:0] ";}
	$i=0;
	while($i<$bus_count){
		print C_FILE_SV "data_out_bus_wp$i";
		if($i != $bus_count-1){print C_FILE_SV ", ";}
		$i++;
		if($i == $bus_count){print C_FILE_SV ";\n";}
	}
	
	if($crossbar_count>0){print C_FILE_SV " wire regflit[4:0] ";}
	$i=0;
	while($i<$crossbar_count){
		print C_FILE_SV "data_out_crossbar_wp$i";
		if($i != $crossbar_count-1){print C_FILE_SV ", ";}
		$i++;
		if($i == $crossbar_count){print C_FILE_SV ";\n";}
	}
	
	# Data out Slaves/Local
	print C_FILE_SV " wire regflit ";
	for($i=1; $i<$x_dimensions*$y_dimensions; $i++){
		print C_FILE_SV "data_out_s$i";
			if($i != $x_dimensions*$y_dimensions-1){
			print C_FILE_SV ", ";
		}
	}
	print C_FILE_SV ";\n";
	print C_FILE_SV " wire regflit data_out_mm;\n\n";
	
############# Injectors Signals #####################
	if($injector_flag==1){
		print C_FILE_SV " // Injectors Signals\n";
		print C_FILE_SV " wire logic ";
		for($i=1; $i<$x_dimensions*$y_dimensions; $i++){
			$column = $i%$x_dimensions;
			if($i<$x_dimensions or $column==0 or $column==$x_dimensions-1 or $i>=$x_dimensions*$y_dimensions-$x_dimensions ){ # Bottom Side or Left Side or Right Side or Top side
				print C_FILE_SV "clock_tx_inj$i";
				if($i != $x_dimensions*$y_dimensions-1){print C_FILE_SV ", ";}
			}
		}
		print C_FILE_SV ";\n";
		
		print C_FILE_SV " wire logic ";
		for($i=1; $i<$x_dimensions*$y_dimensions; $i++){
			$column = $i%$x_dimensions;
			if($i<$x_dimensions or $column==0 or $column==$x_dimensions-1 or $i>=$x_dimensions*$y_dimensions-$x_dimensions ){ # Bottom Side or Left Side or Right Side or Top side
				print C_FILE_SV "tx_inj$i";
				if($i != $x_dimensions*$y_dimensions-1){print C_FILE_SV ", ";}
			}
		}
		print C_FILE_SV ";\n";
		
		print C_FILE_SV " wire regflit ";
		for($i=1; $i<$x_dimensions*$y_dimensions; $i++){
			$column = $i%$x_dimensions;
			if($i<$x_dimensions or $column==0 or $column==$x_dimensions-1 or $i>=$x_dimensions*$y_dimensions-$x_dimensions ){ # Bottom Side or Left Side or Right Side or Top side
				print C_FILE_SV "data_out_inj$i";
				if($i != $x_dimensions*$y_dimensions-1){print C_FILE_SV ", ";}
			}
		}
		print C_FILE_SV ";\n";
		
		print C_FILE_SV " wire logic ";
		for($i=1; $i<$x_dimensions*$y_dimensions; $i++){
			$column = $i%$x_dimensions;
			if($i<$x_dimensions or $column==0 or $column==$x_dimensions-1 or $i>=$x_dimensions*$y_dimensions-$x_dimensions ){ # Bottom Side or Left Side or Right Side or Top side
				print C_FILE_SV "credit_o_inj$i";
				if($i != $x_dimensions*$y_dimensions-1){print C_FILE_SV ", ";}
			}
		}
		print C_FILE_SV ";\n\n";
	}
	
############# Connections on Buses ########################
	print C_FILE_SV " // Connection's Wires on Buses\n";
	for($i=0; $i<$bus_count; $i++){
		print C_FILE_SV " // Bus $i Connections Signals\n";
		print C_FILE_SV " wire regflit[0:".@proc_per_bus[$i]."] data_out_bus$i, tx_addr$i;\n";
		print C_FILE_SV " wire regflit bus_data$i;\n";
		print C_FILE_SV " wire logic bus_credit$i, ack_arb$i;\n";
		print C_FILE_SV " wire logic[".@proc_per_bus[$i].":0] tx_bus$i, credit_o_bus$i, grant$i, grant_out$i, bus_rx$i, request$i, using_bus$i, ack_o$i, tmp$i=0;\n";
		print C_FILE_SV " logic[".@proc_per_bus[$i]."-1:0] tx_change_flit$i;\n";
	}
	
############# Connections on Buses ########################
	print C_FILE_SV " // Connection's Wires on Crossbars\n";
	for($i=0; $i<$crossbar_count; $i++){
		print C_FILE_SV " // Crossbar $i Connections Signals\n";
		print C_FILE_SV " wire regflit[0:".@proc_per_crossbar[$i]."] data_out_crossbar$i, data_in_crossbar$i, tx_addr_crossbar$i;\n";
		print C_FILE_SV " wire logic[".@proc_per_crossbar[$i].":0] tx_crossbar$i, rx_crossbar$i, credit_o_crossbar$i, credit_i_crossbar$i, grant_crossbar$i, request_crossbar$i;\n";
		print C_FILE_SV " logic[".@proc_per_crossbar[$i]."-1:0] tx_change_flit_crossbar$i;\n";
	}
	
# -------------------------------------------------------------------------------
# Addresses Functions For Hybrid HeMPS ------------------------------------------
# -------------------------------------------------------------------------------
	# Router, Bus Wrappers and Crossbar Wrappers Addresses
	for($i=0,$x=0,$y=0; $i<$y_dimensions*$x_dimensions; $i++){
		# Hexadecimal converter
		$x_aux2 = int($x/16);
		$y_aux2 = int($y/16);
		if($x%16>9 && $x%16<16){ # To Hexadecimal 10=A, 11=B, 12=C, 13=D, 14=E, 15=F
			if($x%16==10){$x_aux = "A";} 
			elsif($x%16==11){$x_aux = "B";}
			elsif($x%16==12){$x_aux = "C";}
			elsif($x%16==13){$x_aux = "D";}
			elsif($x%16==14){$x_aux = "E";}
			else{$x_aux = "F";}
		}
		else{
			$x_aux = $x%16;
		}
		if($y%16>9 && $y%16<16){ # To Hexadecimal 10=A, 11=B, 12=C, 13=D, 14=E, 15=F
			if($y%16==10){$y_aux = "A";}
			elsif($y%16==11){$y_aux = "B";}
			elsif($y%16==12){$y_aux = "C";}
			elsif($y%16==13){$y_aux = "D";}
			elsif($y%16==14){$y_aux = "E";}
			else{$y_aux = "F";}
		}
		else{
			$y_aux = $y%16;
		}
		# End Hexadecimal Converter
		@router_addresses[$i]= "16'h".$x_aux2."".$x_aux."".$y_aux2."".$y_aux.""; # General Router Addresses
		@bus_flag[$i]=0;
		@crossbar_flag[$i]=0;
		for($j=0; $j<$bus_count; $j++){                     # Bus Addresses
			if($i == @$bus_position[$j]){
				@bus_flag[$i]=1;                            # 1 if there is a bus wrapper
				@bus_addresses[$j] = "16'h".$x_aux2."".$x_aux."".$y_aux2."".$y_aux."";       # Bus Wrapper Addresses
				$bus_proc_address[$j][0] = "16'h".$x_aux2."".$x_aux."".$y_aux2."".$y_aux.""; # First processor has the same Wrapper Address
			}
		}
		for($j=0; $j<$crossbar_count; $j++){                # Crossbar Addresses
			if($i == @$crossbar_position[$j]){
				@crossbar_flag[$i]=1;
				@crossbar_addresses[$j] = "16'h".$x_aux2."".$x_aux."".$y_aux2."".$y_aux."";
				$crossbar_proc_address[$j][0] = "16'h".$x_aux2."".$x_aux."".$y_aux2."".$y_aux."";
			}
		}
		if($x<$x_dimensions-1){ # next column
			$x++;
		}
		else{ # next line, return to first column
			$x = 0;
			$y++;
		}
	}
	# Generate Bus and Crossbar Processors Addresses for Hybrid NoC
	$x_dimensions_aux = $x_dimensions;
	$y_dimensions_aux = $y_dimensions;
	$x_bus = 0; # Bus
	$x_cross = 0; # Crossbars
	$y_bus = 1; # Processors on bus
	$y_cross = 1; # Processors on Crossbar
	for($i=0, $x=0, $y=$y_dimensions; $i<$bus_proc_count+$crossbar_proc_count; $i++){
		# Hexadecimal converter
		$x_aux2 = int($x/16);
		$y_aux2 = int($y/16);
		if($x%16>9 && $x%16<16){ # To Hexadecimal 10=A, 11=B, 12=C, 13=D, 14=E, 15=F
			if($x%16==10){$x_aux = "A";} 
			elsif($x%16==11){$x_aux = "B";}
			elsif($x%16==12){$x_aux = "C";}
			elsif($x%16==13){$x_aux = "D";}
			elsif($x%16==14){$x_aux = "E";}
			else{$x_aux = "F";}
		}
		else{
			$x_aux = $x%16;
		}
		if($y%16>9 && $y%16<16){ # To Hexadecimal 10=A, 11=B, 12=C, 13=D, 14=E, 15=F
			if($y%16==10){$y_aux = "A";}
			elsif($y%16==11){$y_aux = "B";}
			elsif($y%16==12){$y_aux = "C";}
			elsif($y%16==13){$y_aux = "D";}
			elsif($y%16==14){$y_aux = "E";}
			else{$y_aux = "F";}
		}
		else{
			$y_aux = $y%16;
		}
		if($x_bus<$bus_count){ # Set the bus processors addresses, number of buses
			if($y_bus<@proc_per_bus[$x_bus]){ # Number of processors on each bus
				$bus_proc_address[$x_bus][$y_bus] = "16'h".$x_aux2."".$x_aux."".$y_aux2."".$y_aux."";
				$y_bus++;
				$addr_flag=0;
			}
			else{ # new bus 
				$y_bus=1;
				$x_bus++;
				$addr_flag=1;
			}
		}
		else{ # Set the crossbar processors addresses
			if($x_cross<$crossbar_count){ # Number of crossbars
				if($y_cross<@proc_per_crossbar[$x_cross]){ # Number of processors on each crossbar
					$crossbar_proc_address[$x_cross][$y_cross] = "16'h".$x_aux2."".$x_aux."".$y_aux2."".$y_aux."";
					$y_cross++;
					$addr_flag=0;
				}
				else{ # new crossbar 
					$y_cross=1;
					$x_cross++;
					$addr_flag=1;
				}
			}
		}
		# Control the new NoC XY dimensions for extra addresses
		if($x<$x_dimensions_aux and $addr_flag==0){ # Next Column
			$x++;
		}
		elsif($addr_flag==0){ # Next Address if same bus/crossbar
			if($y>0){ # Next Line(Top to Bottom)
				$y--;
			}
			else{ # Reached Bottom Line, return to first column and next top line
				$x_dimensions_aux++;
				$y_dimensions_aux++;
				$y = $y_dimensions_aux;
				$x = 0;
			}
		}
	}
	
	print "RouterAddr: @router_addresses\n";
	#print "BusFlag: @bus_flag\n";
	#print "CrossbarFlag: @crossbar_flag\n";
	#print "BusWrapperAddr: @bus_addresses\n";
	#print "CrossbarWrapperAddr: @crossbar_addresses\n";
	print Dumper \@bus_proc_address;
	print Dumper \@crossbar_proc_address;
	
	# NoC Elements 
	print C_FILE_SV "\n //--------------------------------------------\n // NoC\n //--------------------------------------------\n";
	# Routers
	print C_FILE_SV " //--------------------------------------------\n // Routers\n //--------------------------------------------\n";
	$b=0;
	$c=0;
	for($i=0,$x=0,$y=0; $i<$y_dimensions*$x_dimensions; $i++){
		if($i!=0 and @bus_flag[$i]==0 and @crossbar_flag[$i]==0){ # Slave's Router and not Bus Wrapper
			print C_FILE_SV " RouterCC#(\n\t.address(".@router_addresses[$i]."))\n router$i(\n";
			print C_FILE_SV "\t.clock(clock),\n\t.reset(reset),\n\t.clock_tx(clock_tx_r$i),\n\t.clock_rx(clock_rx_r$i),\n\t.tx(tx_r$i),\n\t.rx(rx_r$i),\n\t.data_in(data_in_r$i),\n\t.data_out(data_out_r$i),\n\t.credit_i(credit_i_r$i),\n\t.credit_o(credit_o_r$i));\n\n";
		}
		elsif($i==0){ # Master's Router
			print C_FILE_SV " RouterCC#(\n\t.address(16'h0000))\n m_router(\n";
			print C_FILE_SV "\t.clock(clock),\n\t.reset(reset),\n\t.clock_tx(clock_tx_m),\n\t.clock_rx(clock_rx_m),\n\t.tx(tx_m),\n\t.rx(rx_m),\n\t.data_in(data_in_m),\n\t.data_out(data_out_m),\n\t.credit_i(credit_i_m),\n\t.credit_o(credit_o_m));\n\n";
		}
		elsif(@bus_flag[$i]==1){ # Replace with a Wrapper
			print C_FILE_SV "\t// There is a Bus Wrapper(".$b.") here!\n\n";
			$b++;
		}
		else{ # @crossbar_flag[$i]==1
			print C_FILE_SV "\t// There is a Crossbar Wrapper(".$c.") here!\n\n";
			$c++;
		}
	}
	
	print C_FILE_SV " //--------------------------------------------\n // Plasmas NoC\n //--------------------------------------------\n";
	# Processors
	$total_elements=0;
	$b=0;
	$c=0;	
	for($i=0; $i<$y_dimensions*$x_dimensions; $i++){
		$column = $i%$x_dimensions;
		$line = int($i/$x_dimensions);
		$y_dimensions_aux = $y_dimensions-1;
		$x_dimensions_aux = $x_dimensions-1;
		if($i==0){ # Master's Processor
			print C_FILE_SV " plasma #(\n\t.memory_type(\"TRI\"),\n\t.mlite_description(\"RTL\"),\n\t.ram_description(\"RTL\"),\n\t.log_file(\"log/master\"),\n\t.router_address(16'h0000),\n\t.is_master('b1))\n Master(\n\t";
			print C_FILE_SV ".clock(clock),\n\t.reset(reset),\n\t.clock_tx(if_m.clock_tx),\n\t.clock_rx(if_m.clock_rx),\n\t.tx(if_m.tx),\n\t.rx(if_m.rx),\n\t.data_in(if_m.data_in),\n\t.data_out(if_m.data_out),\n\t.credit_i(if_m.credit_i),\n\t.credit_o(if_m.credit_o),\n\t//debug\n\t";
			print C_FILE_SV ".write_enable_debug(if_m.wed),\n\t.data_out_debug(if_m.dod),\n\t.busy_debug(if_m.bd),\n\t.ack_app(if_m.aa),\n\t.req_app(if_m.ra),\n\t.address(if_m.address),\n\t.data_read(if_m.dr));\n\n";
		}
		elsif($injector_flag==1 and ($i<$x_dimensions or $column==0 or $column==$x_dimensions-1 or $i>=$x_dimensions*$y_dimensions-$x_dimensions )){ # Replace NoC's Plasma with a Message Injector
			if($i<$x_dimensions){ # Bottom Injectors, target is Top
				$target = "16'h0$column"."0$y_dimensions_aux";
			}
			elsif($column==0){ # Left Injectors, target is Right
				$target = "16'h0$x_dimensions_aux"."0$line";
			}
			elsif($column==$x_dimensions-1){ # Right Injectors, target is Left
				$target = "16'h000$line";
			}
			else{ # Top Injectors, target is Bottom
				$target = "16'h0$column"."00";
			}
			print C_FILE_SV " PE_injector #(\n\t.source_address(".@router_addresses[$i]."),\n\t.target_address(".$target."))\n pe_inj$i(\n";
			print C_FILE_SV "\t.clock(clock),\n\t.reset(reset),\n\t// Router Local Port Connection\n";
			print C_FILE_SV "\t.clock_tx(clock_tx_inj$i),\n\t.tx(tx_inj$i),\n\t.data_out(data_out_inj$i),\n\t.credit_i(credit_o_r".$i."[4]),\n";
			print C_FILE_SV "\t.clock_rx(clock_tx_r".$i."[4]),\n\t.rx(tx_r".$i."[4]),\n\t.data_in(data_out_r".$i."[4]),\n\t.credit_o(credit_o_inj$i));\n\n";
		}
		elsif(@bus_flag[$i]==0 and @crossbar_flag[$i]==0){ # Slave's Processors and not Bus Wrapper
			print C_FILE_SV " plasma #(\n\t.memory_type(\"TRI\"),\n\t.mlite_description(\"RTL\"),\n\t.ram_description(\"RTL\"),\n\t.log_file(\"log/slave$i\"),\n\t.router_address(".@router_addresses[$i]."),\n\t.is_master('b0))\n slave".$i."(\n";
			print C_FILE_SV "\t.clock(clock),\n\t.reset(reset),\n\t.clock_tx(if_s$i.clock_tx),\n\t.clock_rx(if_s$i.clock_rx),\n\t.tx(if_s$i.tx),\n\t.rx(if_s$i.rx),\n\t.data_in(if_s$i.data_in),\n\t.data_out(if_s$i.data_out),\n\t.credit_i(if_s$i.credit_i),\n\t.credit_o(if_s$i.credit_o),\n\t//debug\n";
			print C_FILE_SV "\t.write_enable_debug(if_s$i.wed),\n\t.data_out_debug(if_s$i.dod),\n\t.busy_debug(if_s$i.bd),\n\t.ack_app(if_s$i.aa),\n\t.req_app(if_s$i.ra),\n\t.address(if_s$i.address),\n\t.data_read(if_s$i.dr));\n\n";
		}
		elsif(@bus_flag[$i]){ # Replace with a Wrapper
			print C_FILE_SV "\t// There is a Bus Wrapper(".$b.") here!\n\n";
		}
		else{ # @cross_bar_flag[$i]==1
			print C_FILE_SV "\t// There is a Crossbar Wrapper(".$c.") here!\n\n";
		}
		$total_elements++;
	}
	
	print C_FILE_SV " //--------------------------------------------\n // Plasmas Bus\n //--------------------------------------------\n";
	for($i=0; $i<$bus_count; $i++){ # Number of Buses connected on NoC
		print C_FILE_SV " // Bus ".$i."\n";
		for($j=0; $j<$proc_per_bus[$i]; $j++){ # Number of processors on the Bus
			print C_FILE_SV " plasma_busRR #(\n\t.memory_type(\"TRI\"),\n\t.mlite_description(\"RTL\"),\n\t.ram_description(\"RTL\"),\n\t.log_file(\"log/slave".$total_elements."_bus".$i."\"),\n\t.router_address(".$bus_proc_address[$i][$j]."),\n\t.is_master('b0))\n slave".$total_elements."_bus".$i."(\n";
			print C_FILE_SV "\t.clock(clock),\n\t.reset(reset),\n\t.tx(if_s".$total_elements.".tx),\n\t.rx(bus_rx".$i."[$j]),\n\t.data_in(bus_data".$i."),\n";
			print C_FILE_SV "\t.data_out(if_s".$total_elements.".data_out),\n\t.credit_i(bus_credit".$i."),\n\t.credit_o(credit_o_bus".$i."[$j]),\n\t.tx_addr(tx_addr".$i."[$j]),\n\t.source_addr(if_s".$total_elements.".source_addr),\n";
			print C_FILE_SV "\t// Bus Signals\n";
			print C_FILE_SV "\t.ack(ack_o".$i."[$j]),\n\t.grant(grant".$i."[$j]),\n\t.request(request".$i."[$j]),\n\t.using_bus(using_bus".$i."[$j]),\n\t.tx_change_flit(tx_change_flit".$i."[$j]),\n";
			print C_FILE_SV "\t// Debug\n";
			print C_FILE_SV "\t.write_enable_debug(if_s".$total_elements.".wed),\n\t.data_out_debug(if_s".$total_elements.".dod),\n\t.busy_debug(if_s".$total_elements.".bd),\n\t.ack_app(if_s".$total_elements.".aa),\n\t.req_app(if_s".$total_elements.".ra),\n\t.address(if_s".$total_elements.".address),\n\t.data_read(if_s".$total_elements.".dr));\n\n";
			$total_elements++;
		}	
	}
	print C_FILE_SV " //--------------------------------------------\n // Plasmas Crossbar\n //--------------------------------------------\n";
	for($i=0; $i<$crossbar_count; $i++){ # Number of Crossbars connected on NoC
		print C_FILE_SV " // Crossbar ".$i."\n";
		for($j=0; $j<$proc_per_crossbar[$i]; $j++){ # Number of processors on the Bus
			print C_FILE_SV " plasma_cross #(\n\t.memory_type(\"TRI\"),\n\t.mlite_description(\"RTL\"),\n\t.ram_description(\"RTL\"),\n\t.log_file(\"log/slave".$total_elements."_crossbar".$i."\"),\n\t.router_address(".$crossbar_proc_address[$i][$j]."),\n\t.is_master('b0))\n slave".$total_elements."_cb".$i."(\n";
			print C_FILE_SV "\t.clock(clock),\n\t.reset(reset),\n\t.tx(if_s".$total_elements.".tx),\n\t.rx(rx_crossbar".$i."[$j]),\n\t.data_in(data_in_crossbar".$i."[$j]),\n";
			print C_FILE_SV "\t.data_out(if_s".$total_elements.".data_out),\n\t.credit_i(credit_i_crossbar".$i."[$j]),\n\t.credit_o(credit_o_crossbar".$i."[$j]),\n\t.tx_addr(tx_addr_crossbar".$i."[$j]),\n\t.source_addr(if_s".$total_elements.".source_addr),\n";
			print C_FILE_SV "\t// Crossbar Arbiter\n";
			print C_FILE_SV "\t.grant(grant_crossbar".$i."[$j]),\n\t.request(request_crossbar".$i."[$j]),\n\t.tx_change_flit(tx_change_flit_crossbar".$i."[$j]),\n";
			print C_FILE_SV "\t//Debug\n";
			print C_FILE_SV "\t.write_enable_debug(if_s".$total_elements.".wed),\n\t.data_out_debug(if_s".$total_elements.".dod),\n\t.busy_debug(if_s".$total_elements.".bd),\n\t.ack_app(if_s".$total_elements.".aa),\n\t.req_app(if_s".$total_elements.".ra),\n\t.address(if_s".$total_elements.".address),\n\t.data_read(if_s".$total_elements.".dr));\n\n";
			$total_elements++;
		}	
	}
	
	print C_FILE_SV " //--------------------------------------------\n // Interfaces\n //--------------------------------------------\n";
	print C_FILE_SV " // NoC's Plasmas Interface\n";
	$b=0;
	$c=0;
	$total_elements=0;
	for($i=0; $i<$y_dimensions*$x_dimensions; $i++){
		if($i==0){  # Master
			print C_FILE_SV " if_plasma if_m(\n";
			print C_FILE_SV "\t.clock(clock),\n\t.reset(reset),\n\t.credit_i_Local_p(credit_o_m[4]),\n\t.data_in_Local_p(data_out_m[4]),\n";
			print C_FILE_SV "\t.clock_rx_Local_p(clock_tx_m[4]),\n\t.rx_Local_p(tx_m[4]),\n\t.data_out_Local_p(data_out_mm));\n\n";
		}
		elsif($injector_flag==1 and ($i<$x_dimensions or $i%$x_dimensions==0 or $i%$x_dimensions==$x_dimensions-1 or $i>=$x_dimensions*$y_dimensions-$x_dimensions)){ # Injectors have no interface
			print C_FILE_SV "\t// There is a Injector(".$i.") here!\n\n"
		}
		elsif(@bus_flag[$i]==0 and @crossbar_flag[$i]==0){ # Slave
			print C_FILE_SV " if_plasma if_s".$i."(\n";
			print C_FILE_SV "\t.clock(clock),\n\t.reset(reset),\n\t.credit_i_Local_p(credit_o_r".$i."[4]),\n\t.data_in_Local_p(data_out_r".$i."[4]),\n";
			print C_FILE_SV "\t.clock_rx_Local_p(clock_tx_r".$i."[4]),\n\t.rx_Local_p(tx_r".$i."[4]),\n\t.data_out_Local_p(data_out_s".$i."));\n\n";
		}
		else{ # Replace with a Wrapper
			if(@bus_flag[$i]){
				print C_FILE_SV "\t// There is a Bus Wrapper(".$b.") here!\n\n";
				$b++;
			}
			else{ # @crossbar_flag[$i]==1
				print C_FILE_SV "\t// There is a Crossbar Wrapper(".$c.") here!\n\n";
				$c++;
			}
		}
		$total_elements++;
	}
	print C_FILE_SV " // Bus Plasmas Interface\n";
	for($i=0; $i<$bus_count; $i++){ # Number of Buses connected on NoC
		print C_FILE_SV " // Bus Processors Interface Number ".$i."\n";
		for($j=0; $j<$proc_per_bus[$i]; $j++){ # Number of processors on the Bus
			print C_FILE_SV " if_plasma_bus_crossbar if_s".$total_elements."(\n";
			print C_FILE_SV "\t.clock(clock),\n\t.reset(reset),\n\t.tx_b_p(tx_bus".$i."[$j]),\n\t.data_o_b_p(data_out_bus".$i."[$j]));\n\n";
			$total_elements++;
		}
	}
	print C_FILE_SV " // Crossbar Plasmas Interface\n";
	for($i=0; $i<$crossbar_count; $i++){ # Number of Buses connected on NoC
		print C_FILE_SV " // Crossbar Processors Interface Number ".$i."\n";
		for($j=0; $j<$proc_per_crossbar[$i]; $j++){ # Number of processors on the Bus
			print C_FILE_SV " if_plasma_bus_crossbar if_s".$total_elements."(\n";
			print C_FILE_SV "\t.clock(clock),\n\t.reset(reset),\n\t.tx_b_p(tx_crossbar".$i."[$j]),\n\t.data_o_b_p(data_out_crossbar".$i."[$j]));\n\n";
			$total_elements++;
		}
	}
	
	print C_FILE_SV " //--------------------------------------------\n // Bus Wrapper(s)\n //--------------------------------------------\n";
	for($i=0; $i<$bus_count; $i++){
		print C_FILE_SV " Bus_Wrapper #(\n\t.router_address(".@bus_addresses[$i]."))\n bus_wp$i(\n";
		print C_FILE_SV "\t.clock(clock),\n\t.reset(reset),\n\t.clock_tx(clock_tx_bus_wp$i),\n\t.clock_rx(clock_rx_bus_wp$i),\n\t.tx(tx_bus_wp$i),\n\t.rx(rx_bus_wp$i),\n\t.data_in(data_in_bus_wp$i),\n\t.data_out(data_out_bus_wp$i),\n\t.credit_i(credit_i_bus_wp$i),\n\t.credit_o(credit_o_bus_wp$i),\n";
		print C_FILE_SV "\t// Connections with bus\n";
		print C_FILE_SV "\t.rx_b(bus_rx$i\[".@proc_per_bus[$i]."]),\n\t.credit_i_b(bus_credit$i),\n\t.data_in_b(bus_data$i),\n\t.tx_b(tx_bus$i\[".@proc_per_bus[$i]."]),\n\t.tx_addr_b(tx_addr$i\[".@proc_per_bus[$i]."]),\n\t.credit_o_b(credit_o_bus$i\[".@proc_per_bus[$i]."]),\n\t.data_out_b(data_out_bus$i\[".@proc_per_bus[$i]."]),\n";
		print C_FILE_SV "\t// Bus Arbiter Interface\n";
		print C_FILE_SV "\t.ack(ack_o$i\[".@proc_per_bus[$i]."]),\n\t.grant(grant$i\[".@proc_per_bus[$i]."]),\n\t.request(request$i\[".@proc_per_bus[$i]."]),\n\t.using_bus(using_bus$i\[".@proc_per_bus[$i]."]));\n\n";
	}
	
	print C_FILE_SV " //--------------------------------------------\n // Bus(es)\n //--------------------------------------------\n";
	for($i=0; $i<$bus_count; $i++){
		print C_FILE_SV " bus_ctrl_hy #(\n\t.BusID($i),\n\t.NUMBER_PROC_BUS(".@proc_per_bus[$i]."))\n bus_ctrl$i(\n";
		print C_FILE_SV "\t//-- Input to bus\n";
		print C_FILE_SV "\t.tx(tx_bus$i),\n\t.data_out(data_out_bus$i),\n\t.credit_o(credit_o_bus$i),\n";
		print C_FILE_SV "\t//-- Output to processors\n";
		print C_FILE_SV "\t.bus_data(bus_data$i),\n\t.bus_rx(bus_rx$i),\n\t.bus_credit(bus_credit$i),\n";
		print C_FILE_SV "\t// In - Controls which element is using the bus\n";
		print C_FILE_SV "\t.using_bus(using_bus$i),\n\t.tx_addr(tx_addr$i));\n\n";
	}
	
	print C_FILE_SV " //--------------------------------------------\n // Bus Arbiter(s)\n //--------------------------------------------\n";
	for($i=0; $i<$bus_count; $i++){
		print C_FILE_SV " rr_arbiter #(\n\t.NUMBER_PROC_BUS(".@proc_per_bus[$i]."))\n RR_arbiter$i(\n";
		print C_FILE_SV "\t.clock(clock),\n\t.reset(reset),\n\t.ack(ack_arb$i),\n\t.request(request$i),\n\t.grant(grant_out$i));\n\n";
	}

	print C_FILE_SV "\n //--------------------------------------------\n // Round-Robin Arbiter Connections\n //--------------------------------------------\n";
	for($i=0; $i<$bus_count; $i++){
		print C_FILE_SV " assign grant$i = (using_bus$i == tmp$i) ? grant_out$i : tmp$i;\n";
		print C_FILE_SV " assign ack_arb$i = (ack_o$i == tmp$i) ? 1'b0 : 1'b1;\n";
	}
	
	print C_FILE_SV "\n //--------------------------------------------\n // Crossbar Wrapper(s)\n //--------------------------------------------\n";
	for($i=0; $i<$crossbar_count; $i++){
		print C_FILE_SV " Crossbar_Wrapper #(\n\t.router_address(".@crossbar_addresses[$i]."))\n crossbar_wp$i(\n";
		print C_FILE_SV "\t.clock(clock),\n\t.reset(reset),\n\t.clock_tx(clock_tx_crossbar_wp$i),\n\t.clock_rx(clock_rx_crossbar_wp$i),\n\t.tx(tx_crossbar_wp$i),\n\t.rx(rx_crossbar_wp$i),\n\t.data_in(data_in_crossbar_wp$i),\n\t.data_out(data_out_crossbar_wp$i),\n\t.credit_i(credit_i_crossbar_wp$i),\n\t.credit_o(credit_o_crossbar_wp$i),\n";
		print C_FILE_SV "\t// Connections with Crossbar\n";
		print C_FILE_SV "\t.rx_c(rx_crossbar".$i."[".@proc_per_crossbar[$i]."]),\n\t.credit_i_c(credit_i_crossbar".$i."[".@proc_per_crossbar[$i]."]),\n\t.data_in_c(data_in_crossbar".$i."[".@proc_per_crossbar[$i]."]),\n\t.tx_c(tx_crossbar".$i."[".@proc_per_crossbar[$i]."]),\n\t.tx_addr_c(tx_addr_crossbar".$i."[".@proc_per_crossbar[$i]."]),\n\t.credit_o_c(credit_o_crossbar".$i."[".@proc_per_crossbar[$i]."]),\n\t.data_out_c(data_out_crossbar".$i."[".@proc_per_crossbar[$i]."]),\n";
		print C_FILE_SV "\t// Crossbar Arbiter Interface\n";
		print C_FILE_SV "\t.grant(grant_crossbar".$i."[".@proc_per_crossbar[$i]."]),\n\t.request(request_crossbar".$i."[".@proc_per_crossbar[$i]."]));\n\n";
	}
	
	print C_FILE_SV " //--------------------------------------------\n // Crossbar(s)\n //--------------------------------------------\n";
	for($i=0; $i<$crossbar_count; $i++){
		print C_FILE_SV " crossgen #(\n\t.CrossbarID($i),\n\t.NUMBER_PROC_CROSSBAR(".@proc_per_crossbar[$i]."))\n crossbar$i(\n";
		print C_FILE_SV "\t.clock(clock),\n\t.reset(reset),\n\t.data_in(data_in_crossbar$i),\n\t.data_out(data_out_crossbar$i),\n\t.tx(tx_crossbar$i),\n\t.rx(rx_crossbar$i),\n";
		print C_FILE_SV "\t.credit_i(credit_i_crossbar$i),\n\t.credit_o(credit_o_crossbar$i),\n\t.tx_addr(tx_addr_crossbar$i),\n";
		print C_FILE_SV "\t// Crossbar Arbiter\n";
		print C_FILE_SV "\t.grant(grant_crossbar$i),\n\t.request(request_crossbar$i));\n\n";
	}
	
	print C_FILE_SV "\n //--------------------------------------------\n // NoC Connections\n //--------------------------------------------\n";
	print C_FILE_SV " // 4     3 2 1 0\n";
	print C_FILE_SV " // Local S N W E\n\n";
	for($i=0; $i<$y_dimensions*$x_dimensions; $i++){
		$south = $i-$x_dimensions;
		$north = $i+$x_dimensions;
		$west = $i-1;
		$east = $i+1;
		@wp_flag = (0) x 4; # Reset the Wrapper's Flags
		for($j=0; $j<$bus_count; $j++){ # Verify Bus Wrappers Connections
			if($i == @$bus_position[$j]){ # This position is a Wrapper
				@wp_flag[4]=1;
				@wp_num[4]=$j;
			}
			if(($south>=0) and ($south == @$bus_position[$j])){ # South Bus Wrapper Connection
				@wp_flag[3]=1;
				@wp_num[3]=$j;
			}
			if(($north<$x_dimensions*$y_dimensions) and ($north == @$bus_position[$j])){ # North Bus Wrapper Connection
				@wp_flag[2]=1;
				@wp_num[2]=$j;
			}
			if(($west+1%$x_dimensions!=0) and ($west == @$bus_position[$j])){ # West Bus Wrapper Connection
				@wp_flag[1]=1;
				@wp_num[1]=$j;
			}
			if(($east%$x_dimensions!=0) and ($east == @$bus_position[$j])){ # East Bus Wrapper Connection
				@wp_flag[0]=1;
				@wp_num[0]=$j;
			}
		}
		for($j=0; $j<$crossbar_count; $j++){ # Verify Crossbars Wrappers Connections
			if($i == @$crossbar_position[$j]){ # This position is a Crossbar Wrapper
				@wp_flag[4]=2;
				@wp_num[4]=$j;
			}
			if(($south>=0) and ($south == @$crossbar_position[$j])){ # South Crossbar Wrapper Connection
				@wp_flag[3]=2;
				@wp_num[3]=$j;
			}
			if(($north<$x_dimensions*$y_dimensions) and ($north == @$crossbar_position[$j])){ # North Crossbar Wrapper Connection
				@wp_flag[2]=2;
				@wp_num[2]=$j;
			}
			if(($west+1%$x_dimensions!=0) and ($west == @$crossbar_position[$j])){ # West Crossbar Wrapper Connection
				@wp_flag[1]=2;
				@wp_num[1]=$j;
			}
			if(($east%$x_dimensions!=0) and ($east == @$crossbar_position[$j])){ # East Crossbar Wrapper Connection
				@wp_flag[0]=2;
				@wp_num[0]=$j;
			}
		}
		# Verify the position on NoC
		$column = $i%$x_dimensions;
		if($i >= $x_dimensions*$y_dimensions-$x_dimensions){ # TOP 
			if($column == $x_dimensions-1){ # RIGHT
				$position = "TR";
			}
			elsif($column == 0){ # LEFT
				$position = "TL";
			}
			else{ # CENTER X
				$position = "TC";
			}
		}
		elsif($i < $x_dimensions){ # BOTTOM
			if($column == $x_dimensions-1){ # RIGHT
				$position = "BR";
			}
			elsif($column == 0){ # LEFT
				$position = "BL";
			}
			else{ # CENTER X
				$position = "BC";
			}
		}
		else{ # CENTER Y
			if($column == $x_dimensions-1){ # RIGHT
				$position = "CR";
			}
			elsif($column == 0){ # LEFT
				$position = "CL";
			}
			else{ # CENTER X
				$position = "CC";
			}
		}
		if($i==0){ # Master's PE
			print C_FILE_SV " // Processing Element - Left Bottom (Master)\n";
			print C_FILE_SV " assign rx_m[4]         = if_m.tx;\n";
			print C_FILE_SV " assign clock_rx_m[4]   = if_m.clock_tx;\n";
			print C_FILE_SV " assign data_in_m[4]    = data_out_mm;\n";
			print C_FILE_SV " assign credit_i_m[4]   = if_m.credit_o;\n";
		}
		elsif(@wp_flag[4]==0){ # Slave's PE
			if($injector_flag==1 and ($i<$x_dimensions or $i%$x_dimensions==0 or $i%$x_dimensions==$x_dimensions-1 or $i>=$x_dimensions*$y_dimensions-$x_dimensions)){
				print C_FILE_SV " // Message Injector Number ".$i." --------------------------------------------------------------\n";
				print C_FILE_SV " assign rx_r".$i."[4]         = tx_inj".$i.";\n";
				print C_FILE_SV " assign clock_rx_r".$i."[4]   = clock_tx_inj".$i.";\n";
				print C_FILE_SV " assign data_in_r".$i."[4]    = data_out_inj".$i.";\n";
				print C_FILE_SV " assign credit_i_r".$i."[4]   = credit_o_inj".$i.";\n";
			}
			else{# ($injector_flag==0){
				print C_FILE_SV " // Processing Element Number ".$i." --------------------------------------------------------------\n";
				print C_FILE_SV " assign rx_r".$i."[4]         = if_s".$i.".tx;\n";
				print C_FILE_SV " assign clock_rx_r".$i."[4]   = if_s".$i.".clock_tx;\n";
				print C_FILE_SV " assign data_in_r".$i."[4]    = data_out_s".$i.";\n";
				print C_FILE_SV " assign credit_i_r".$i."[4]   = if_s".$i.".credit_o;\n";
			}
			for($aux=0; $aux<4; $aux++){
				$StringAux[$aux][0] = "r$i";
			}
		}
		elsif(@wp_flag[4]==1){ #  Replace PE with Bus Wrapper
			print C_FILE_SV " // Bus Wrapper Number ".$wp_num[4]." -------------------------------------------------------------------------\n";
			for($aux=0; $aux<4; $aux++){
				$StringAux[$aux][0] = "bus_wp$wp_num[4]";
			}
		}
		else{ # @wp_flag[4]==2){ #  Replace PE with Crossbar Wrapper
			print C_FILE_SV " // Crossbar Wrapper Number ".$wp_num[4]." -------------------------------------------------------------------------\n";
			for($aux=0; $aux<4; $aux++){
				$StringAux[$aux][0] = "crossbar_wp$wp_num[4]";
			}
		}
		# Verify if there's a Wrapper or a PE connected on each side
		for($aux=0; $aux<4; $aux++){
			if($wp_flag[3]==0){
				$StringAux[$aux][1] = "r$south";
			}
			else{
				if($wp_flag[3]==1){
					$StringAux[$aux][1] = "bus_wp$wp_num[3]";
				}
				else{ # $wp_flag[3]==2
					$StringAux[$aux][1] = "crossbar_wp$wp_num[3]";
				}
			}
			if($wp_flag[2]==0){
				$StringAux[$aux][2] = "r$north";
			}
			else{
				if($wp_flag[2]==1){
					$StringAux[$aux][2] = "bus_wp$wp_num[2]";
				}
				else{ # $wp_flag[2]==2
					$StringAux[$aux][2] = "crossbar_wp$wp_num[2]";
				}
			}
			if($wp_flag[1]==0){
				$StringAux[$aux][3] = "r$west";
			}
			else{
				if($wp_flag[1]==1){
					$StringAux[$aux][3] = "bus_wp$wp_num[1]";
				}
				else{ # $wp_flag[1]==2
					$StringAux[$aux][3] = "crossbar_wp$wp_num[1]";
				}
			}
			if($wp_flag[0]==0){
				$StringAux[$aux][4] = "r$east";
			}
			else{
				if($wp_flag[0]==1){
					$StringAux[$aux][4] = "bus_wp$wp_num[0]";
				}
				else{ # $wp_flag[0]==2
					$StringAux[$aux][4] = "crossbar_wp$wp_num[0]";
				}
			}
		}
		if($i==1 or $i==$x_dimensions){ # These PE's are always connected with Master - have different signals
			for($aux=0; $aux<4; $aux++){
				if($i==1){
					$StringAux[$aux][3]= "m";
				}
				else{ # above master
					$StringAux[$aux][1]= "m";
				}
			}
		}
		# Processor Element Position on NoC
		if($position eq "BL"){ # Bottom Left - BL
			print C_FILE_SV " assign clock_rx_m[3:0] = {1'b0  , clock_tx_".$StringAux[0][2]."[3], 1'b0  , clock_tx_".$StringAux[0][4]."[1]};\n";
			print C_FILE_SV " assign rx_m[3:0]       = {1'b0  , tx_".$StringAux[1][2]."[3]      , 1'b0  , tx_".$StringAux[1][4]."[1]};\n";
			print C_FILE_SV " assign credit_i_m[3:0] = {1'b0  , credit_o_".$StringAux[2][2]."[3], 1'b0  , credit_o_".$StringAux[2][4]."[1]};\n";
			print C_FILE_SV " assign data_in_m[3:0]  = {32'h00, data_out_".$StringAux[3][2]."[3], 32'h00, data_out_".$StringAux[3][4]."[1]};\n\n";
		}
		elsif($position eq "CC"){ # Center - CC
			print C_FILE_SV " assign clock_rx_".$StringAux[0][0]."[3:0] = {clock_tx_".$StringAux[0][1]."[2], clock_tx_".$StringAux[0][2]."[3], clock_tx_".$StringAux[0][3]."[0], clock_tx_".$StringAux[0][4]."[1]};\n";
			print C_FILE_SV " assign rx_".$StringAux[1][0]."[3:0]       = {tx_".$StringAux[1][1]."[2]      , tx_".$StringAux[1][2]."[3]      , tx_".$StringAux[1][3]."[0]      , tx_".$StringAux[1][4]."[1]};\n";
			print C_FILE_SV " assign credit_i_".$StringAux[2][0]."[3:0] = {credit_o_".$StringAux[2][1]."[2], credit_o_".$StringAux[2][2]."[3], credit_o_".$StringAux[2][3]."[0], credit_o_".$StringAux[2][4]."[1]};\n";
			print C_FILE_SV " assign data_in_".$StringAux[3][0]."[3:0]  = {data_out_".$StringAux[3][1]."[2], data_out_".$StringAux[3][2]."[3], data_out_".$StringAux[3][3]."[0], data_out_".$StringAux[3][4]."[1]};\n\n";
		}
		elsif($position eq "BC"){ # Bottom Center - BC
			print C_FILE_SV " assign clock_rx_".$StringAux[0][0]."[3:0] = {1'b0  , clock_tx_".$StringAux[0][2]."[3], clock_tx_".$StringAux[0][3]."[0], clock_tx_".$StringAux[0][4]."[1]};\n";
			print C_FILE_SV " assign rx_".$StringAux[1][0]."[3:0]       = {1'b0  , tx_".$StringAux[1][2]."[3]      , tx_".$StringAux[1][3]."[0]      , tx_".$StringAux[1][4]."[1]};\n";
			print C_FILE_SV " assign credit_i_".$StringAux[2][0]."[3:0] = {1'b0  , credit_o_".$StringAux[2][2]."[3], credit_o_".$StringAux[2][3]."[0], credit_o_".$StringAux[2][4]."[1]};\n";
			print C_FILE_SV " assign data_in_".$StringAux[3][0]."[3:0]  = {32'h00, data_out_".$StringAux[3][2]."[3], data_out_".$StringAux[3][3]."[0], data_out_".$StringAux[3][4]."[1]};\n\n";
		}
		elsif($position eq "BR"){ # Bottom Right - BR
			print C_FILE_SV " assign clock_rx_".$StringAux[0][0]."[3:0] = {1'b0  , clock_tx_".$StringAux[0][2]."[3], clock_tx_".$StringAux[0][3]."[0], 1'b0};\n";
			print C_FILE_SV " assign rx_".$StringAux[1][0]."[3:0]       = {1'b0  , tx_".$StringAux[1][2]."[3]      , tx_".$StringAux[1][3]."[0]      , 1'b0};\n";
			print C_FILE_SV " assign credit_i_".$StringAux[2][0]."[3:0] = {1'b0  , credit_o_".$StringAux[2][2]."[3], credit_o_".$StringAux[2][3]."[0], 1'b0};\n";
			print C_FILE_SV " assign data_in_".$StringAux[3][0]."[3:0]  = {32'h00, data_out_".$StringAux[3][2]."[3], data_out_".$StringAux[3][3]."[0], 32'h00};\n\n";
		}
		elsif($position eq "CL"){ # Center Left - CL
			print C_FILE_SV " assign clock_rx_".$StringAux[0][0]."[3:0] = {clock_tx_".$StringAux[0][1]."[2], clock_tx_".$StringAux[0][2]."[3], 1'b0  , clock_tx_".$StringAux[0][4]."[1]};\n";
			print C_FILE_SV " assign rx_".$StringAux[1][0]."[3:0]       = {tx_".$StringAux[1][1]."[2]      , tx_".$StringAux[1][2]."[3]      , 1'b0  , tx_".$StringAux[1][4]."[1]};\n";
			print C_FILE_SV " assign credit_i_".$StringAux[2][0]."[3:0] = {credit_o_".$StringAux[2][1]."[2], credit_o_".$StringAux[2][2]."[3], 1'b0  , credit_o_".$StringAux[2][4]."[1]};\n";
			print C_FILE_SV " assign data_in_".$StringAux[3][0]."[3:0]  = {data_out_".$StringAux[3][1]."[2], data_out_".$StringAux[3][2]."[3], 32'h00, data_out_".$StringAux[3][4]."[1]};\n\n";
		}
		elsif($position eq "TL"){ # Top Left - TL
			print C_FILE_SV " assign clock_rx_".$StringAux[0][0]."[3:0] = {clock_tx_".$StringAux[0][1]."[2], 1'b0  ,  1'b0 , clock_tx_".$StringAux[0][4]."[1]};\n";
			print C_FILE_SV " assign rx_".$StringAux[1][0]."[3:0]       = {tx_".$StringAux[1][1]."[2]      , 1'b0  ,  1'b0 , tx_".$StringAux[1][4]."[1]};\n";
			print C_FILE_SV " assign credit_i_".$StringAux[2][0]."[3:0] = {credit_o_".$StringAux[2][1]."[2], 1'b0  ,  1'b0 , credit_o_".$StringAux[2][4]."[1]};\n";
			print C_FILE_SV " assign data_in_".$StringAux[3][0]."[3:0]  = {data_out_".$StringAux[3][1]."[2], 32'h00, 32'h00, data_out_".$StringAux[3][4]."[1]};\n\n";
		}
		elsif($position eq "TC"){# Top Center - TC
			print C_FILE_SV " assign clock_rx_".$StringAux[0][0]."[3:0] = {clock_tx_".$StringAux[0][1]."[2], 1'b0  , clock_tx_".$StringAux[0][3]."[0], clock_tx_".$StringAux[0][4]."[1]};\n";
			print C_FILE_SV " assign rx_".$StringAux[1][0]."[3:0]       = {tx_".$StringAux[1][1]."[2]      , 1'b0  , tx_".$StringAux[1][3]."[0]      , tx_".$StringAux[1][4]."[1]};\n";
			print C_FILE_SV " assign credit_i_".$StringAux[2][0]."[3:0] = {credit_o_".$StringAux[2][1]."[2], 1'b0  , credit_o_".$StringAux[2][3]."[0], credit_o_".$StringAux[2][4]."[1]};\n";
			print C_FILE_SV " assign data_in_".$StringAux[3][0]."[3:0]  = {data_out_".$StringAux[3][1]."[2], 32'h00, data_out_".$StringAux[3][3]."[0], data_out_".$StringAux[3][4]."[1]};\n\n";
		}
		elsif($position eq "TR"){# Top Right - TR
			print C_FILE_SV " assign clock_rx_".$StringAux[0][0]."[3:0] = {clock_tx_".$StringAux[0][1]."[2], 1'b0  , clock_tx_".$StringAux[0][3]."[0], 1'b0};\n";
			print C_FILE_SV " assign rx_".$StringAux[1][0]."[3:0]       = {tx_".$StringAux[1][1]."[2]      , 1'b0  , tx_".$StringAux[1][3]."[0]      , 1'b0};\n";
			print C_FILE_SV " assign credit_i_".$StringAux[2][0]."[3:0] = {credit_o_".$StringAux[2][1]."[2], 1'b0  , credit_o_".$StringAux[2][3]."[0], 1'b0};\n";
			print C_FILE_SV " assign data_in_".$StringAux[3][0]."[3:0]  = {data_out_".$StringAux[3][1]."[2], 32'h00, data_out_".$StringAux[3][3]."[0], 32'h00};\n\n";
		}
		else{ #($position == "CR"){ Center Right - CR
			print C_FILE_SV " assign clock_rx_".$StringAux[0][0]."[3:0] = {clock_tx_".$StringAux[0][1]."[2], clock_tx_".$StringAux[0][2]."[3], clock_tx_".$StringAux[0][3]."[0], 1'b0};\n";
			print C_FILE_SV " assign rx_".$StringAux[1][0]."[3:0]       = {tx_".$StringAux[1][1]."[2]      , tx_".$StringAux[1][2]."[3]      , tx_".$StringAux[1][3]."[0]      , 1'b0};\n";
			print C_FILE_SV " assign credit_i_".$StringAux[2][0]."[3:0] = {credit_o_".$StringAux[2][1]."[2], credit_o_".$StringAux[2][2]."[3], credit_o_".$StringAux[2][3]."[0], 1'b0};\n";
			print C_FILE_SV " assign data_in_".$StringAux[3][0]."[3:0]  = {data_out_".$StringAux[3][1]."[2], data_out_".$StringAux[3][2]."[3], data_out_".$StringAux[3][3]."[0], 32'h00};\n\n";
		}
	}

	print C_FILE_SV "endmodule: Hybrid_top";
	
	close(C_FILE_SV);
	
#------------------------------------------------------------
# Generate if_plasma.sv ---------------------------------
#------------------------------------------------------------
	open( C_FILE_SV, ">./$projectName/if_plasma.sv" );
	
	$total_bus_crossbar = $bus_count+$crossbar_count;
	# Verfiry which bus and crossbar has more processors
	$largest_bus_cross = $proc_per_bus[0];
	$i=1;
	while($i<$bus_count){
		if($largest_bus_cross < @proc_per_bus[$i]){
			$largest_bus_cross = $proc_per_bus[$i];
		}
		$i++;
	}
	$i=0;
	while($i<$crossbar_count){
		if($largest_bus_cross < @proc_per_crossbar[$i]){
			$largest_bus_cross = $proc_per_crossbar[$i];
		}
		$i++;
	}
	
	print C_FILE_SV "import HeMPS_defaults::*;\n\n";
	# NoC Processors Interface ######################################
	print C_FILE_SV " interface if_plasma(\n";
	print C_FILE_SV "\tinput clock,\n\tinput reset,\n\tinput credit_i_Local_p,\n\tinput regflit data_in_Local_p,\n";
	print C_FILE_SV "\tinput clock_rx_Local_p,\n\tinput rx_Local_p,\n\toutput regflit data_out_Local_p\n );\n\n";
	
	print C_FILE_SV " logic credit_o, tx, clock_tx;\n logic credit_i, clock_rx, rx;\n logic [31:0] data_in, data_out;\n logic wed, bd, aa;\n logic [31:0] dod, ea, ra, dr;\n logic [29:0] address;\n\n";
	print C_FILE_SV " // Controls flit change\n";
	print C_FILE_SV " logic [0:".$largest_bus_cross."][15:0] tab[];\n integer change_flit=0, NUMBER_BUS_CROSS=".$total_bus_crossbar.", PROC_ADDR=".$largest_bus_cross.";\n";
	print C_FILE_SV " integer x=0, y=0, wp_addr=0;\n logic [31:0] Addr_WP=32'hFFFFFFFF;\n\n";
	print C_FILE_SV " initial begin\n\ttab = new[NUMBER_BUS_CROSS];\n";
	for($x=0; $x<$bus_count; $x++){
		for($y=0; $y<$proc_per_bus[$x]; $y++){
			print C_FILE_SV "\ttab[".$x."][".$y."] = ".$bus_proc_address[$x][$y].";\n";
		}
	}
	$aux = $x;
	for($x=0; $x<$crossbar_count; $x++, $aux++){
		for($y=0; $y<$proc_per_crossbar[$x]; $y++){
			print C_FILE_SV "\ttab[".$aux."][".$y."] = ".$crossbar_proc_address[$x][$y].";\n";
		}
	}
	print C_FILE_SV " end\n\n";
	
	print C_FILE_SV " always @ (posedge tx) begin\n";
	print C_FILE_SV "\n\tchange_flit=0;\n\tAddr_WP[31:16] = 16'HFFFF;\n";
	print C_FILE_SV "\tif(tx == 1'b1) begin\n";
	print C_FILE_SV "\t\tfor(integer x=0; x<NUMBER_BUS_CROSS; x++) begin\n";
	print C_FILE_SV "\t\t\tfor(integer y=0; y<PROC_ADDR; y++) begin\n";
	print C_FILE_SV "\t\t\t\tif(data_out == tab[x][y]) begin // Trocar para Roteador Especial que contem esse processador\n";
	print C_FILE_SV "\t\t\t\t\tchange_flit=1;\n\t\t\t\t\twp_addr = x;\n";
	print C_FILE_SV "\t\t\t\tend\n\t\t\tend\n\t\tend\n"; # end for x, end for y, end if
	print C_FILE_SV "\t\tif(change_flit == 1) begin\n";
	print C_FILE_SV "\t\t\tAddr_WP[15:0] = tab[wp_addr][0];\n";
	print C_FILE_SV "\t\t\tAddr_WP[31:16] = data_out;\n";
	print C_FILE_SV "\t\t\t@(posedge clock);\n";
	print C_FILE_SV "\t\t\tchange_flit=0;\n";
	print C_FILE_SV "\t\tend\n\tend\n end\n\n";
	
	print C_FILE_SV " assign data_in = data_in_Local_p;\n assign clock_rx = clock_rx_Local_p;\n assign credit_i = credit_i_Local_p;\n assign rx = rx_Local_p;\n assign data_out_Local_p = (change_flit) ? Addr_WP : data_out;\n\n";
	print C_FILE_SV "endinterface: if_plasma\n\n";
	
	# Bus/Crossbar Processors Interface ###############################
	print C_FILE_SV "interface if_plasma_bus_crossbar(\n";
	print C_FILE_SV "\tinput clock,\n\tinput reset,\n\toutput tx_b_p,\n\toutput regflit data_o_b_p\n);\n\n";
	
	print C_FILE_SV " logic tx;\n";
	print C_FILE_SV " logic [31:0] data_out;\n logic [15:0] source_addr;\n // debug\n logic wed, bd, aa;\n";
	print C_FILE_SV " logic [31:0] dod, ea, ra, dr;\n logic [29:0] address;\n\n";
	
	# Controls Flit Change 
	print C_FILE_SV " // Controls flit change\n";
	print C_FILE_SV " logic [0:".$largest_bus_cross."][15:0] tab[];\n integer change_flit=0, NUMBER_BUS_CROSS=".$total_bus_crossbar.", PROC_ADDR=".$largest_bus_cross.";\n";
	print C_FILE_SV " integer x=0, y=0, wp_addr_target=0, wp_addr_source=0;\n logic [31:0] Addr_WP=32'hFFFFFFFF;\n\n";
	print C_FILE_SV " // Matrix containing addresses of all Processors on Bus(es) and Crossbar(s)\n";
	print C_FILE_SV " // x indicates Bus/Crossbar and y indicates the processor's address\n";
	print C_FILE_SV " initial begin\n\ttab = new[NUMBER_BUS_CROSS];\n";
	for($x=0; $x<$bus_count; $x++){
		for($y=0; $y<$proc_per_bus[$x]; $y++){
			print C_FILE_SV "\ttab[".$x."][".$y."] = ".$bus_proc_address[$x][$y].";\n";
		}
	}
	$aux = $x;
	for($x=0; $x<$crossbar_count; $x++, $aux++){
		for($y=0; $y<$proc_per_crossbar[$x]; $y++){
			print C_FILE_SV "\ttab[".$aux."][".$y."] = ".$crossbar_proc_address[$x][$y].";\n";
		}
	}
	print C_FILE_SV " end\n\n";
	
	print C_FILE_SV " always @ (posedge tx) begin\n";
	print C_FILE_SV "\n\tchange_flit=0;\n\tAddr_WP[31:16] = 16'HFFFF;\n";
	print C_FILE_SV "\tif(tx == 1'b1) begin\n";
	print C_FILE_SV "\t\tfor(integer x=0; x<NUMBER_BUS_CROSS; x++) begin\n";
	print C_FILE_SV "\t\t\tfor(integer y=0; y<PROC_ADDR; y++) begin\n";
	print C_FILE_SV "\t\t\t\tif(source_addr == tab[x][y]) begin // Verify which Bus/Crossbar this processor belongs\n";
	print C_FILE_SV "\t\t\t\t\twp_addr_source = x; // Source Wrapper Address\n\t\t\t\t\tend\n";
	print C_FILE_SV "\t\t\t\tif(data_out == tab[x][y]) begin // // The message goes to another Bus/Crossbar\n";
	print C_FILE_SV "\t\t\t\t\tchange_flit=1;\n\t\t\t\t\twp_addr_target = x;\n";
	print C_FILE_SV "\t\t\t\tend\n\t\t\tend\n\t\tend\n"; # end for x, end for y, end if
	print C_FILE_SV "\t\t // If the message goes to another Bus/Crossbar then change the first flit\n";
	print C_FILE_SV "\t\t // Else it goes to a Router or to the SAME Bus/Crossbar then do not change the first flit\n";
	print C_FILE_SV "\t\tif(change_flit == 1 && (wp_addr_source != wp_addr_target)) begin\n";
	print C_FILE_SV "\t\t\tAddr_WP[15:0] = tab[wp_addr_target][0];\n";
	print C_FILE_SV "\t\t\tAddr_WP[31:16] = data_out;\n";
	print C_FILE_SV "\t\t\t@(posedge clock);\n";
	print C_FILE_SV "\t\t\tchange_flit=0;\n";
	print C_FILE_SV "\t\tend\n\tend\n end\n\n";
	
	print C_FILE_SV " assign tx_b_p = tx;\n assign data_o_b_p = (change_flit) ? Addr_WP : data_out;\n\n";
	
	print C_FILE_SV "endinterface: if_plasma_bus_crossbar";
	
	close(C_FILE_SV);
}

#################################################################################################
################################## HYBRID HEMPS CONSTANTS HEADER ################################
#################################################################################################

sub generate_hybrid_map{

	my @bus_position = @$bus_position;
	my @proc_per_bus = @$proc_per_bus;
	my @crossbar_position = @$crossbar_position;
	my @proc_per_crossbar = @$proc_per_crossbar;
	
# -------------------------------------------------------------------------------
# Addresses Functions For Hybrid HeMPS ------------------------------------------
# -------------------------------------------------------------------------------
	# Generate Bus and Crossbar correspondent XY coordinates
	$x_dimensions_aux = $x_dimensions;
	$y_dimensions_aux = $y_dimensions;
	$bus_proc=0;
	$cb_proc=0;
	$x_bus = 0;
	$x_cross = 0;
	$y_aux = 1;
	for($i=0, $x=0, $y=$y_dimensions; $i<$bus_proc_count+$crossbar_proc_count; $i++){
		if($x_bus<$bus_count){ # Set the bus processor's XY coordinates
			if($y_aux<@proc_per_bus[$x_bus]){ # Number of processors on each bus
				$x_id_bus[$bus_proc] = $x; 	  # x coordinate
				$y_id_bus[$bus_proc] = $y;	  # y coordinate
				$y_aux++;
				$addr_flag=0;
				$bus_proc++;
			}
			else{ # new bus 
				$y_aux=1;
				$x_bus++;
				$addr_flag=1;
			}
		}
		else{ # Set the crossbar processor's XY coordinates
			if($x_cross<$crossbar_count){ # Number of crossbars
				if($y_aux<@proc_per_crossbar[$x_cross]){ # Number of processors on each crossbar
					$x_id_cb[$cb_proc] = $x; 			 # x coordinate
					$y_id_cb[$cb_proc] = $y; 			 # y coordinate
					$y_aux++;
					$addr_flag=0;
					$cb_proc++;
				}
				else{ # new crossbar 
					$y_aux=1;
					$x_cross++;
					$addr_flag=1;
				}
			}
		}
		# Control the new NoC XY dimensions for extra addresses
		if($x<$x_dimensions_aux and $addr_flag==0){ # 
			$x++;
		}
		elsif($addr_flag==0){
			if($y>0){
				$y--;
			}
			else{
				$x_dimensions_aux++;
				$y_dimensions_aux++;
				$y = $y_dimensions_aux;
				$x = 0;
			}
		}
	}
	
	#print "x_id_bus: @x_id_bus\n";
	#print "y_id_bus: @y_id_bus\n";
	#print "x_id_cb: @x_id_cb\n";
	#print "y_id_cb: @y_id_cb\n";
	
	open(C_FILE_H, ">./$projectName/HyMap.h");
	print C_FILE_H "// Hybrid HeMPS \n// Bus and Crossbar Constants\n\n";
	
	################################################# Bus Constants
	print C_FILE_H "#define NUM_BUS\t\t".$bus_count."\t\t// Number of Buses\n"; 
	print C_FILE_H "#define NUM_PE_BUS\t{";
	for($i=0; $i<$bus_count; $i++){
		print C_FILE_H "".@proc_per_bus[$i]."";
		if($i != $bus_count-1){
			print C_FILE_H ",";
		}
	}
	print C_FILE_H "}\t\t// Number of processors on each Bus\n";
	
	print C_FILE_H "#define POS_BUS\t\t{";
	for($i=0; $i<$bus_count; $i++){
		$x = @bus_position[$i]%$x_dimensions;
		$y = int(@bus_position[$i]/$y_dimensions);
		print C_FILE_H "".$x."*256+".$y."";
		if($i != $bus_count-1){
			print C_FILE_H ",";
		}
	}
	print C_FILE_H "}\t// Bus Wrappers XY Addresses\n";
	
	print C_FILE_H "#define PEs_BUS\t\t{{";
	for($i=0, $bus_proc=0; $i<$bus_count; $i++){ # Number of Buses
		for($j=0; $j<@proc_per_bus[$i]; $j++){   # Bus Processors
			if($j==0){ 							 # First processor has the Wrapper Address
				$x = @bus_position[$i]%$x_dimensions;
				$y = int(@bus_position[$i]/$y_dimensions);
				print C_FILE_H "".$x."*256+".$y."";
			}
			else{
				print C_FILE_H "".$x_id_bus[$bus_proc]."*256+".$y_id_bus[$bus_proc]."";
				$bus_proc++;
			}
			if($j<@proc_per_bus[$i]-1){
				print C_FILE_H ","; 
			}
		}
		if($i<$bus_count-1){ # next bus
			print C_FILE_H "}, {";
		}
	}
	print C_FILE_H "}}// Bus Procecessors Addresses \n\n";
	
	################################################ Crossbar Constants
	print C_FILE_H "#define NUM_CB\t\t".$crossbar_count."\t\t// Number of Crossbars\n"; 
	print C_FILE_H "#define NUM_PE_CB\t{";
	for($i=0; $i<$crossbar_count; $i++){
		print C_FILE_H "".@proc_per_crossbar[$i]."";
		if($i != $crossbar_count-1){
			print C_FILE_H ",";
		}
	}
	print C_FILE_H "}\t\t// Number of processors on each Crossbar\n";
	
	print C_FILE_H "#define POS_CB\t\t{";
	for($i=0; $i<$crossbar_count; $i++){
		$x = @crossbar_position[$i]%$x_dimensions;
		$y = int(@crossbar_position[$i]/$y_dimensions);
		print C_FILE_H "".$x."*256+".$y."";
		if($i != $crossbar_count-1){
			print C_FILE_H ",";
		}
	}
	print C_FILE_H "}\t// Crossbar Wrappers XY Addresses\n";
	
	print C_FILE_H "#define PEs_CB\t\t{{";
	for($i=0, $crossbar_proc=0; $i<$crossbar_count; $i++){ # Number of Crossbars
		for($j=0; $j<@proc_per_crossbar[$i]; $j++){  # Crossbars Processors
			if($j==0){ 							 # First processor has the Wrapper Address
				$x = @crossbar_position[$i]%$x_dimensions;
				$y = int(@crossbar_position[$i]/$y_dimensions);
				print C_FILE_H "".$x."*256+".$y."";
			}
			else{
				print C_FILE_H "".$x_id_cb[$crossbar_proc]."*256+".$y_id_cb[$crossbar_proc]."";
				$crossbar_proc++;
			}
			if($j<@proc_per_crossbar[$i]-1){
				print C_FILE_H ",";
			}
		}
		if($i<$crossbar_count-1){ # next crossbar
			print C_FILE_H "}, {";
		}
	}
	print C_FILE_H "}} // Crossbar Procecessors Addresses \n\n";
	
	###################### Verfiry which bus and crossbar has more processors
	$largest_bus_cross = $proc_per_bus[0];
	$i=1;
	while($i<$bus_count){
		if($largest_bus_cross < @proc_per_bus[$i]){
			$largest_bus_cross = $proc_per_bus[$i];
		}
		$i++;
	}
	$i=0;
	while($i<$crossbar_count){
		if($largest_bus_cross < @proc_per_crossbar[$i]){
			$largest_bus_cross = $proc_per_crossbar[$i];
		}
		$i++;
	}
	#################### HeMPS coordinates
	print C_FILE_H "#define MAX_PE\t\t ".$largest_bus_cross."\n";
	print C_FILE_H "#define hemps_xi\t 0\n";
	print C_FILE_H "#define hemps_xf\t ".$x_dimensions."\n";
	print C_FILE_H "#define hemps_yi\t 0\n";
	print C_FILE_H "#define hemps_yf\t ".$y_dimensions."\n\n";
	
	print C_FILE_H "typedef struct{\n\tchar tipo;\n\tint ID;\n\tint numPE;\n\tint wrapperPos;\n\tint* PEs;\n} CommStruct;\n\n";
	print C_FILE_H "void constructCommArray();\n";
	print C_FILE_H "void printStruct();\n";
	print C_FILE_H "void get_app_main_task(int app_ID);\n";
	print C_FILE_H "int get_app_commStruct(int app_ID);\n";
	print C_FILE_H "int get_bus_processor();\n";
	print C_FILE_H "int get_struct_processor(int structIndex);\n";
	print C_FILE_H "int free_procs_bus();\n";
	print C_FILE_H "int free_procs_struct(int structIndex);\n";
	print C_FILE_H "int MapTaskNearBus(int application, int task);\n";
	print C_FILE_H "int MapTaskNearStruct(int structIndex);\n";
	print C_FILE_H "int goes2bus(int taskID);";
	
	close(C_FILE_H);
}

#################################################################################################
################################## PARAMETERS NoC ###############################################
#################################################################################################

sub parameters_NoC{

#NoC Routing Algorithm
	opendir(DIR, "$hempsPath/hardware/router/sc/");

	(@aux)=readdir(DIR);
	@aux = sort @aux;
	$size_aux = @aux; 
	closedir(DIR);
	system("mkdir ./$projectName/hardware/ 2> /dev/null");
	system("mkdir ./$projectName/hardware/router/ 2> /dev/null");
	system("mkdir ./$projectName/hardware/router/sc/ 2> /dev/null");
	system("cp -rf $hempsPath/hardware/router/sc/* ./$projectName/hardware/router/sc 2> /dev/null");
			
	if($NoC_routing_algorithm ne ""){
		for($i=0; $i<$size_aux; $i++){
			if($aux[$i] =~ /switchcontrol_$NoC_routing_algorithm/ig){
				$aux[$i] =~ s/\n//ig;
				($aux2) = $aux[$i];
				
				if($aux[$i] =~ /.cpp/ig){
					($switchcontrol_cpp) = $aux[$i];
					$switchcontrol_cpp =~ s/\.cpp//ig;
				}
				else{
					($switchcontrol_h) = $aux[$i];
				}
			}
			elsif($aux[$i] =~ /switchcontrol_/ig){
				system("rm -rf ./$projectName/hardware/router/sc/$aux[$i] 2> /dev/null");
			}
		}
	}
	else{
		$switchcontrol_cpp="switchcontrol";
		$switchcontrol_h="switchcontrol.h";
	}

	system("sed 's/#include \"switchcontrol\.h\".*/#include \"$switchcontrol_h\"/ig' ./$projectName/hardware/router/sc/router_cc.h > ./$projectName/hardware/router/sc/router_cc.h.tmp && mv -f ./$projectName/hardware/router/sc/router_cc.h.tmp ./$projectName/hardware/router/sc/router_cc.h");


#NoC Buffer Size
	if($NoC_buffer_size ne ""){
		system("sed 's/#define BUFFER_TAM.*/#define BUFFER_TAM $NoC_buffer_size/ig' ./$projectName/hardware/router/sc/packet.h > ./$projectName/hardware/router/sc/packet.h.tmp && mv -f ./$projectName/hardware/router/sc/packet.h.tmp ./$projectName/hardware/router/sc/packet.h");
	}
}

#################################################################################################
################################## Generates Repositories #######################################
#################################################################################################

sub repositories{

### REPOSITORY SYSTEMC	

	open( C_FILE_H, ">./$projectName/repository.h" );

	print C_FILE_H "#ifndef _repository\n";
	print C_FILE_H "#define _repository\n\n";
	
	print C_FILE_H "\t#define NUMBER_OF_APPS ".$numberAPPs."\n";
	print C_FILE_H "\tint appstime[".$numberAPPs."] = {";

	$pastTime=0;
	$delay=0;
	for($i=0; $i<$numberAPPs; $i++){
		($delay)=$StartTimeApp[$i]-$pastTime;
		$pastTime=$StartTimeApp[$i];
		print C_FILE_H "$delay,";
	}
	print C_FILE_H "};\n";

	$aux_repo_size=$app_repo_size*$cont_app_new;
	
	print C_FILE_H "\t#define REPO_SIZE\t".$aux_repo_size."\n";
	print C_FILE_H "\tunsigned int repository[REPO_SIZE] = {		\n";
	print C_FILE_H "     											\n";
	

### REPOSITORY VHDL

	open( C_FILE_VHD, ">./$projectName/repository.vhd" );
	
	print C_FILE_VHD "-------------------------------------------------------------------------------------\n";
	print C_FILE_VHD "--\tPartial Repository																\n";
	print C_FILE_VHD "--\t\tContains the object codes of the tasks inserted on runtime						\n";
	print C_FILE_VHD "-------------------------------------------------------------------------------------\n";
	print C_FILE_VHD "--repository structure:																\n";
	print C_FILE_VHD "--[/this structure is replicaded according the number of tasks]						\n";
	print C_FILE_VHD "--number of tasks																	\n";
	print C_FILE_VHD "--task id																			\n";
	print C_FILE_VHD "--task code size																		\n";
	print C_FILE_VHD "--processor (ffffffff means dynamic allocation)										\n";
	print C_FILE_VHD "--task code start address															\n";
	print C_FILE_VHD "--[/this structure is replicaded according the number of tasks]						\n";
	print C_FILE_VHD "--tasks codes																		\n";
	print C_FILE_VHD "-------------------------------------------------------------------------------------\n";
	print C_FILE_VHD "library IEEE;																		\n";
	print C_FILE_VHD "use IEEE.Std_Logic_1164.all;														  \n\n";
	print C_FILE_VHD "package memory_pack is 															  \n\n";
	print C_FILE_VHD "\tconstant NUMBER_OF_APPS\t\t\t: integer := ".$numberAPPs.";\n";
	
	print C_FILE_VHD "\ttype timearray is array(0 to NUMBER_OF_APPS) of time;\n";
	print C_FILE_VHD "\tconstant appstime : timearray := (";

	$pastTime=0;
	$delay=0;
	for($i=0; $i<$numberAPPs; $i++){
		($delay)=$StartTimeApp[$i]-$pastTime;
		$pastTime=$StartTimeApp[$i];
		print C_FILE_VHD "$delay ms,";
	}
		print C_FILE_VHD "0 ms";

	print C_FILE_VHD ");\n";
	
	print C_FILE_VHD "\tconstant REPOSITORY_SIZE	: integer := ".$aux_repo_size.";\n"; 
	print C_FILE_VHD "\ttype ram is array (0 to REPOSITORY_SIZE) of std_logic_vector(31 downto 0);		  \n\n";
	print C_FILE_VHD "\tconstant memory : ram := (		
														\n";
														
	$cont_app_new=0;
	$application_new[0]=-1;					
	for($i=0; $i<$numberAPPs; $i++){
		$application_new[$i]=-1;													

	}
	for($i=0; $i<$numberAPPs; $i++){
		
		$cont_aux=0;
		for($g=0; $g<=$cont_app_new; $g++){
			if($applications[$i] eq $application_new[$g]){
				$cont_aux=1;
				last;
				}
		}
		if($cont_aux == 0){
			$application_new[$cont_app_new]=$applications[$i];


		# Sets the first task object code start in the repositoty
		$initialAddressCode= (26 * $size_apps[$i]) + 11 + ($app_repo_size*$cont_app_new);
		
		$codeCont = (26 * $size_apps[$i]) + 11;
		

		# Creates the repository file
		
		print C_FILE_VHD "\t\tx\"".sprintf("%08x", $size_apps[$i])."\",\t --application $applications[$i]\t#id $i\n";
		print C_FILE_H "\t\t0x".sprintf("%08x", $size_apps[$i]).",\t //application $applications[$i]\t#id $i\n";

		$cont=0;
		
		for($j=0; $j<$size_apps[$i]; $j++){
			if($initTasks[$i][$j][0] != -1){
				
				print C_FILE_VHD "\t\tx\"".sprintf("%08x", $applications_Tasks_id[$i][$j][0])."\",\t --initial task id $applications_Tasks[$i][$j]\n";
				print C_FILE_H "\t\t0x".sprintf("%08x", $applications_Tasks_id[$i][$j][0]).",\t //initial task $applications_Tasks[$i][$j]\n";
				$cont++;
			}
		}
		
		for($h=$cont; $h<10; $h++){
			print C_FILE_VHD "\t\tx\"ffffffff\",\n";
			print C_FILE_H "\t\t0xffffffff,\n";
		}

		for($j=0; $j<$size_apps[$i]; $j++){
			$name_aux = $applications_Tasks[$i][$j];
			$name_aux =~ s/\.c//ig;
			$ids_aux = ($cont_app_new << 8) | $applications_Tasks_id[$i][$j][0];

			open( C_FILE, "<./$projectName/build/$name_aux\_$ids_aux\.txt" );
			my @c_lines = <C_FILE>;
			close(C_FILE);
			
			$code_size = @c_lines;

			$x_master_h= sprintf("%x", $x_master);
			
			$cont_sta=0;
						
			$static_task=-1;
			for($t=0; $t<$size_apps[$i]*3; $t++){
			
				if($static_app[$i][$t] eq $name_aux){
					$static_task=$static_app[$i][$t+1];
				}
			}
			
			$task_full_name = $name_aux."_".$applications_Tasks_id[$i][$j][0];
			
			$command = "mips-elf-size $projectName/build/$name_aux\_$ids_aux\.bin | tail -1 | sed 's/ //g' | sed 's/\t/:/g' | cut -d':' -f2";
			
			$data_size = qx{$command};
			
			$command = "mips-elf-size $projectName/build/$name_aux\_$ids_aux\.bin | tail -1 | sed 's/ //g' | sed 's/\t/:/g' | cut -d':' -f3";
			
			$bss_size = qx{$command};
			
			while($data_size % 4 != 0){
				$data_size++;
			}
			
			while($bss_size % 4 != 0){
				$bss_size++;
			}
			
			$data_size = $data_size / 4;
			
			$bss_size = $bss_size / 4;
						
			print C_FILE_VHD "\t\tx\"".sprintf("%08x", $applications_Tasks_id[$i][$j][0])."\",\t --$applications_Tasks[$i][$j]\n";
			print C_FILE_H "\t\t0x".sprintf("%08x", $applications_Tasks_id[$i][$j][0]).",\t //$applications_Tasks[$i][$j]\n";
			print C_FILE_VHD "\t\tx\"".sprintf("%08x", $code_size)."\",\t --code size\n";
			print C_FILE_H "\t\t0x".sprintf("%08x", $code_size).",\t //code size\n";
			
			print C_FILE_VHD "\t\tx\"".sprintf("%08x", $data_size)."\",\t --data size\n";
			print C_FILE_H "\t\t0x".sprintf("%08x", $data_size).",\t //data size\n";
			
			print C_FILE_VHD "\t\tx\"".sprintf("%08x", $bss_size)."\",\t --bss size\n";
			print C_FILE_H "\t\t0x".sprintf("%08x", $bss_size).",\t //bss size\n";
			
			print C_FILE_VHD "\t\tx\"".sprintf("%08x", $initialAddressCode * 4)."\",\t --initial address\n";
			print C_FILE_H "\t\t0x".sprintf("%08x", $initialAddressCode * 4).",\t //initial address\n";	
		#	if($static_task == -1){
		#		print C_FILE_VHD "\t\tx\"ffffffff\",\t --static position\n";
		#		print C_FILE_H "\t\t0xffffffff,\t //static position\n";	
		#		}
		#	else{
		#		print C_FILE_VHD "\t\tx\"".sprintf("%08x", $static_task )."\",\t --static position\n";
		#		print C_FILE_H "\t\t0x".sprintf("%08x", $static_task ).",\t //static position\n";	

		#	}
		
			print C_FILE_VHD "\t\tx\"".sprintf("%08x", $load_Tasks[$i][$j] )."\",\t --load\n";
			print C_FILE_H "\t\t0x".sprintf("%08x", $load_Tasks[$i][$j] ).",\t //load\n";	
			$initialAddressCode = $initialAddressCode + $code_size;

			$codeCont = $codeCont + $code_size;
		

			$cont=0;
			for($t=0; $t<$size_apps[$i]; $t++){
				if(($depTasks_txt[$i][$j][$t] ne -1) and ($depTasks_txt[$i][$j][$t] ne "")){
										
					print C_FILE_VHD "\t\tx\"".sprintf("%08x", $depTasks_txt[$i][$j][$t])."\",\n";
					print C_FILE_H "\t\t0x".sprintf("%08x", $depTasks_txt[$i][$j][$t]).",\n";
					print C_FILE_VHD "\t\tx\"".sprintf("%08x", $depTasks_txt_load[$i][$j][$t][0])."\",\n";
					print C_FILE_H "\t\t0x".sprintf("%08x", $depTasks_txt_load[$i][$j][$t][0]).",\n";
					$cont++;
				}
			}
			
			for($k=$cont; $k<10; $k++){
				print C_FILE_VHD "\t\tx\"ffffffff\",\n";
				print C_FILE_VHD "\t\tx\"ffffffff\",\n";
				print C_FILE_H "\t\t0xffffffff,\n";
				print C_FILE_H "\t\t0xffffffff,\n";
			}
		}
		for($j=0; $j<$size_apps[$i]; $j++){
			$name_aux = $applications_Tasks[$i][$j];
			$name_aux =~ s/\.c//ig;
			
			$ids_aux = ($cont_app_new << 8) | $applications_Tasks_id[$i][$j][0];
			
			open( C_FILE, "<./$projectName/build/$name_aux\_$ids_aux\.txt" );
			my @c_lines = <C_FILE>;
			close(C_FILE);
			
			$code_size = @c_lines;
			$first=0;

			for($t=0; $t<$code_size; $t++){
				$c_lines[$t] =~ s/\n//ig;
				if($first == 0){
					print C_FILE_VHD "\t\tx\"".$c_lines[$t]."\",\t --$applications_Tasks[$i][$j]\n";
					print C_FILE_H "\t\t0x".$c_lines[$t].",\t //$applications_Tasks[$i][$j]\n";
					$first++;
				}
				else{					
					#//print C_FILE_VHD "\t\tx0\"".sprintf("%08", $c_lines[$t])."\"\n";
					#$teste1 = print hex $c_lines[$t],"\"\n";				
					$num1 = "0x" . $c_lines[$t];
					#print "Num1:", $num1, "\n";
					$num=oct($num1);
					#print "Num:", $num, "\n";
					$teste = sprintf("%08x", $num);
					#print "TESTE: ",$teste, "-", $num, "- ", $c_lines[$t], "\n";
					#print C_FILE_VHD "\t\tx\"".$c_lines[$t]."\"\n";
					print C_FILE_VHD "\t\tx\"".$teste."\",\n";								
				}
			}		
		}

		for($t=$codeCont; $t<$app_repo_size; $t++){
				print C_FILE_VHD "\t\tx\"00000000\",\n";
				print C_FILE_H "\t\t0x00000000,\n";
				$count_lines++

		}

			$cont_app_new++;

		}	
	}

	print C_FILE_VHD "\t\t(others=>'0'));\n";
	print C_FILE_VHD "end memory_pack;\n";
	
	print C_FILE_H "};\n";
	print C_FILE_H "\n";
	print C_FILE_H "#endif\n";	


	close(C_FILE_VHD);
	close(C_FILE_H);

}

#################################################################################################
################################## Generates ids_slave.h #######################################
#################################################################################################

sub generate_ids_slave{
	
	open( C_FILE, ">./$projectName/build/ids_slave.h" );
	
	$aux= $pageSize*1024;
	
	print C_FILE "#define MAX_PROCESSORS\t\t".$slaveProcessors."\t/* Number of slave processors available in the platform */\n";
	print C_FILE "#define MAXLOCALTASKS\t\t".$maxTasksSlave."\t/* Number of task which can be allocated simultaneously in one processor */\n";
	print C_FILE "#define MAX_GLOBAL_TASKS\tMAXLOCALTASKS * MAX_PROCESSORS\t/* Number of task which can be allocated simultaneously in the platform */\n";
	print C_FILE "#define KERNELPAGECOUNT\t".$kernelPages."\n";
	print C_FILE "#define PAGESIZE\t\t\t".$aux."\n";
	print C_FILE "#define APP_NUMBER\t\t".$numberAPPs."\n";
	print C_FILE "#define TASK_NUMBER\t\t".$taskNumber."\n";
	print C_FILE "#define MAX_APP_SIZE\t\t".$max_app_size."\n";   
					          
	print C_FILE "int task_location[APP_NUMBER][MAX_APP_SIZE] = { ";
	for($i=0; $i<$numberAPPs; $i++){
		print C_FILE "{";
		for($j=0; $j<$max_app_size; $j++){	
			print C_FILE "-1, ";
		}
		print C_FILE "}, ";
	}
	print C_FILE "};\n";
	
	print C_FILE "unsigned char task_status[APP_NUMBER][MAX_APP_SIZE] = { ";
	for($i=0; $i<$numberAPPs; $i++){
		print C_FILE "{";
		for($j=0; $j<$max_app_size; $j++){	
			print C_FILE "0, ";
		}
		print C_FILE "}, ";
	}
	print C_FILE "};\n";
	
	print C_FILE "int request_task[APP_NUMBER][MAX_APP_SIZE] = {";
	for($i=0; $i<$numberAPPs; $i++){
		print C_FILE "{";
		for($j=0; $j<$max_app_size; $j++){	
			print C_FILE "-1, ";
		}
		print C_FILE "}, ";
	}
	print C_FILE "};\n";
	close(C_FILE);
}

#################################################################################################
################################## Generates ids_master.h #######################################
#################################################################################################

sub generate_ids_master{
	
	
	$cont_app_new=0;
	$app_repo_size=0;

	for($i=0; $i<$numberAPPs; $i++){
		$application_new[$i]=-1;													

	}
	for($i=0; $i<$numberAPPs; $i++){
		
		$cont_aux=0;
		for($g=0; $g<=$cont_app_new; $g++){
			if($applications[$i] eq $application_new[$g]){
				$cont_aux=1;
				last;
				}
		}
		if($cont_aux == 0){
			for($j=0; $j<$size_apps[$i]; $j++){
				$name_aux = $applications_Tasks[$i][$j];
				$name_aux =~ s/\.c//ig;
				$ids_aux = ($cont_app_new << 8) | $applications_Tasks_id[$i][$j][0];
				open( C_FILE, "<./$projectName/build/$name_aux\_$ids_aux\.txt" );
				my @c_lines = <C_FILE>;
				close(C_FILE);
				
				$app_repo_size_aux += @c_lines + 26;
				#print "app_repo_size_aux $app_repo_size_aux $name_aux\_$ids_aux\.txt\n"; 
			}
			
			$app_repo_size_aux += 11;
			$app_repo_size_aux = $app_repo_size_aux;
			
			if($app_repo_size < $app_repo_size_aux){
				($app_repo_size) = $app_repo_size_aux;
			}
			
			$app_repo_size_aux = 0;
			
			
			$application_new[$cont_app_new]=$applications[$i];
			$cont_app_new++;
		}
	}
	
	($slaveProcessors) = ($x_dimensions * $y_dimensions) - $localMastersCont;
	($maxClusterTasks) = $maxTasksSlave * ((($x_dimensions * $y_dimensions) - $localMastersCont)/ $localMastersCont);
	
	#$totalProcessors= $slaveProcessors+$localMastersCont + $x_dimensions;
	
	open( C_FILE, ">./$projectName/build/ids_master.h" );
	
	print C_FILE "#ifndef __ids_master_h__\n";	
	print C_FILE "#define __ids_master_h__\n";
	print C_FILE "/*--------------------------------------------------------------------\n";
	print C_FILE " * struct ClusterInfo\n";
	print C_FILE " *\n";
	print C_FILE " * DESCRIPTION:\n";
	print C_FILE " *    Store the clusters information\n";
	print C_FILE " *\n";
	print C_FILE " *--------------------------------------------------------------------*/\n";
	print C_FILE "typedef struct {\n";
	print C_FILE "\tint master_x;\n";
	print C_FILE "\tint master_y;\n";
	print C_FILE "\tint leftbottom_x;\n";
	print C_FILE "\tint leftbottom_y;\n";
	print C_FILE "\tint topright_x;\n";
	print C_FILE "\tint topright_y;\n";
	print C_FILE "\tint free_resources;\n";
	print C_FILE "} ClusterInfo;\n";
	print C_FILE "\n";	
	#print C_FILE "#define TOTAL_PROCESSORS\t\t".$totalProcessors."\t/* Number of processors available in the platform */\n";
	print C_FILE "#define MAX_PROCESSORS\t\t".$slaveProcessors."\t/* Number of slave processors available in the platform */\n";
	print C_FILE "#define MAX_LOCAL_TASKS\t\t".$maxTasksSlave."\t/* Number of task which can be allocated simultaneously in one processor */\n";
	print C_FILE "#define MAX_CLUSTER_TASKS\t\t".$maxClusterTasks."\t/* Number of task which can be allocated simultaneously in one processor */\n";
	print C_FILE "#define MAX_GLOBAL_TASKS\tMAX_LOCAL_TASKS * MAX_PROCESSORS\t/* Number of task which can be allocated simultaneously in the platform */\n";
	print C_FILE "#define XDIMENSION\t\t".$x_dimensions."\n";
	print C_FILE "#define YDIMENSION\t\t".$y_dimensions."\n";
	print C_FILE "#define XCLUSTER\t\t".$x_cluster."\n";
	print C_FILE "#define YCLUSTER\t\t".$y_cluster."\n";
	#print C_FILE "#define MASTERADDRESS\t\t0x".$x_master_h.$y_master_h."\n";
	print C_FILE "#define CLUSTER_NUMBER\t\t".$localMastersCont."\n";
	print C_FILE "#define APP_NUMBER\t\t".$numberAPPs."\n";
	print C_FILE "#define TASK_NUMBER\t\t".$taskNumber."\n";
	print C_FILE "#define MAX_APP_SIZE\t\t".$max_app_size."\n";
	print C_FILE "#define APP_REPO_SIZE\t\t".$app_repo_size."\n";
	print C_FILE "\n";
	for($g=0; $g<$cont_app_new; $g++){
		print C_FILE "#define $application_new[$g] ".$g."\n";
	}
	print C_FILE "\n//Application id relation\n";	
	print C_FILE " int appstype[".$numberAPPs."] = {";

	for($i=0; $i<$numberAPPs; $i++){
			
		for($g=0; $g<=$cont_app_new; $g++){
			if($applications[$i] eq $application_new[$g]){
			print C_FILE "$application_new[$g],";
			last;
			}
		}
	}
	print C_FILE "};\n\n";
	

	print C_FILE " int proc_available = ".$maxClusterTasks.";\n";
	
	print C_FILE " int task_location[APP_NUMBER][MAX_APP_SIZE] = { ";	
	for($i=0; $i<$numberAPPs; $i++){
		print C_FILE "{";
		for($j=0; $j<$max_app_size; $j++){
			print C_FILE "-1, ";
		}
		print C_FILE "}, ";
	}
	print C_FILE "};\n";
	
	print C_FILE " int task_terminated[APP_NUMBER][MAX_APP_SIZE] = { ";	
	for($i=0; $i<$numberAPPs; $i++){
		print C_FILE "{";
		for($j=0; $j<$max_app_size; $j++){
			print C_FILE "-1, ";
		}
		print C_FILE "}, ";
	}
	print C_FILE "};\n\n";	

	print C_FILE "char proc_free_pages[XDIMENSION][YDIMENSION] = {";	
	for($i=1; $i<$x_dimensions; $i++){
		print C_FILE "{";
		for($j=1; $j<$y_dimensions; $j++){
			print C_FILE "MAX_LOCAL_TASKS, ";	
		}
		print C_FILE "MAX_LOCAL_TASKS}, ";	
	}
	print C_FILE "{";
	for($j=1; $j<$y_dimensions; $j++){
		print C_FILE "MAX_LOCAL_TASKS, ";
	}
	print C_FILE "MAX_LOCAL_TASKS}};\n";
	
	print C_FILE " int applications_terminated[APP_NUMBER] = {";
	for($i=1; $i<$numberAPPs; $i++){
		print C_FILE "-1, ";
	}
	print C_FILE "-1};\n";

	#print C_FILE " int clusters_ocupation[CLUSTER_NUMBER] = {";
	#for($i=1; $i<($localMastersCont); $i++){
	#	print C_FILE "0, ";
	#}
	#print C_FILE "0};\n";
	
	 print C_FILE " int proc_load_total[XDIMENSION][YDIMENSION] = {";	
	 for($i=1; $i<$x_dimensions; $i++){
		 print C_FILE "{";
		 for($j=1; $j<$y_dimensions; $j++){
			 print C_FILE "0, ";	
		 }
		 print C_FILE "0}, ";	
	 }
	 print C_FILE "{";
	 for($j=1; $j<$y_dimensions; $j++){
		 print C_FILE "0, ";
	 }
	 print C_FILE "0}};\n";
	
# # 	print C_FILE " int global_inst_aux[TOTAL_PROCESSORS] = {";	
	# for($i=0; $i<$totalProcessors; $i++){
			# print C_FILE "0, ";	
		# }
		# print C_FILE "};\n";	
	
# # 	
	# print C_FILE " int global_inst_per_cluster[CLUSTER_NUMBER] = {";
	# for($i=1; $i<($localMastersCont); $i++){
		# print C_FILE "0, ";
	# }
	# print C_FILE "0};\n";	
	
# # 	print C_FILE " int global_inst_dev_per_cluster[CLUSTER_NUMBER] = {";
	# for($i=1; $i<($localMastersCont); $i++){
		# print C_FILE "0, ";
	# }
	# print C_FILE "0};\n";

	print C_FILE " int clusters_load[CLUSTER_NUMBER] = {";
	for($i=1; $i<($localMastersCont); $i++){
		print C_FILE "0, ";
	}
	print C_FILE "0};\n";


	print C_FILE "ClusterInfo cluster_info[CLUSTER_NUMBER] = {\n";

	
	for($i=0; $i<($size_clusters); $i++){
		print C_FILE "\t{".$clusters[$i][4].",".$clusters[$i][5].",".$clusters[$i][0].",".$clusters[$i][1].",".$clusters[$i][2].",".$clusters[$i][3].",".$maxClusterTasks."},\n";
	}

	print C_FILE "};\n\n";
	print C_FILE "#endif\n";	

	close(C_FILE);
}

#################################################################################################
################################## Generates application IDs files ##############################
#################################################################################################

sub generate_app_id_files{
	
	for($i=0; $i<$numberAPPs; $i++){
		
		open( C_FILE, ">./$projectName/build/ids_$applications[$i]\.h" );
		for($j=0; $j<$size_apps[$i]; $j++){
			$name_aux = $applications_Tasks[$i][$j];
			$name_aux =~ s/\.c//ig;
			print C_FILE "#define $name_aux\t\t$applications_Tasks_id[$i][$j][0]\n";
		}
		
		close(C_FILE);
	}	
}

#################################################################################################
################################## Generates wave.do ############################################
#################################################################################################

sub generate_wave_do{
	
	open( C_FILE, ">./$projectName/wave.do" );

if ($procDescription eq "rtl"){
		print C_FILE "onerror {resume}\n"; 
		print C_FILE "quietly WaveActivateNextPane {} 0\n";
		print C_FILE "add wave /test_bench/hemps/clock\n";
		
		print C_FILE "add wave  -divider repository\n";
		print C_FILE "add wave  -radix hexadecimal /test_bench/ack_app\n";
		print C_FILE "add wave  -radix hexadecimal /test_bench/req_app\n";
		print C_FILE "add wave  -radix hexadecimal /test_bench/control_hemps_addr\n";
		print C_FILE "add wave  -radix hexadecimal /test_bench/control_hemps_data\n";
		print C_FILE "add wave  -divider Slaves\n";
		
		for($i=0; $i< ($x_dimensions*$y_dimensions); $i++){
			
				$x = 0; 
				$y = 0;
				
				$addr = $i;
				while ($addr - $x_dimensions >= 0){
					$addr -= $x_dimensions;
					$y = $y + 1;
				}
				$x = $addr;
				
				$is_cluster_x = $x;
				$is_cluster_y = $y;
				
				while($is_cluster_x > 0){
					$is_cluster_x = $is_cluster_x - $x_cluster;
				}
				while($is_cluster_y > 0){
					$is_cluster_y = $is_cluster_y - $y_cluster;
				}
				
				$pe_name = "slav/slave";
				
				if ($i == $masterAddress){
					$pe_name = "mas/master";
				} elsif ($is_cluster_x == 0 && $is_cluster_y == 0){
					$pe_name = "loc/slave";
				}
				
				#print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/address\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} /test_bench/HeMPS/proc($i)/".$pe_name."/clock\n";
				if ($pe_name eq "slave"){
					#print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} /test_bench/HeMPS/".$pe_name."$i/clock_hold\n";
					#print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} /test_bench/HeMPS/".$pe_name."$i/clock_aux\n";
				} elsif($pe_name eq "mas/master"){
					print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/ack_app\n";
					print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/req_app\n";
					print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/address\n";
					print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/data_read\n";
					print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/cpu_repo_access\n";
					print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/repo_FSM\n";
					
				}
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {ni $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/tx\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {ni $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/credit_i\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {ni $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/data_out\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/rx\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/credit_o\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/data_in\n";
				
				
				
				
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {config $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/operation\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {config $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/set_address\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {config $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/set_address_2\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {config $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/set_size\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {config $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/set_size_2\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {config $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/set_op\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {config $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/start\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {config $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/size\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {config $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/size_2\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {config $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/address\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {config $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/address_2\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {config $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/config_data\n";
				

				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {arb $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/ARB\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {arb $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/prio\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {arb $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/timer\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {arb $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/write_enable\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {arb $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/read_enable\n";

				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {send $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/DMNI_Send\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {send $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/send_address\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {send $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/mem_data_read\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {send $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/send_size\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {send $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/send_address_2\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {send $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/send_size_2\n";	

				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {receive $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/DMNI_Receive\n";		
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {receive $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/recv_address\n";		
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {receive $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/mem_data_write\n";		
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {receive $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/recv_size\n";		
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {receive $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/mem_byte_we\n";	
				
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {receive NoC $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/intr\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {receive NoC $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/intr_count\n";			
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {receive NoC $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/SR\n";	
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {receive NoC $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/payload_size\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {receive NoC $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/read_av\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {receive NoC $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/slot_available\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {receive NoC $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/first\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {receive NoC $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/last\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {receive NoC $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/add_buffer\n";
				

				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/mem_address\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/is_header\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/send_active\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/u3_dmni/receive_active\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {proc $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/current_page\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {proc $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/cpu_mem_address\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {proc $x$y} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/plasma/write_enable\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input LESTE} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/rx(0)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input LESTE} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/credit_o(0)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input LESTE} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/data_in(0)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input OESTE} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/rx(1)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input OESTE} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/credit_o(1)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input OESTE} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/data_in(1)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input NORTE} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/rx(2)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input NORTE} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/credit_o(2)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input NORTE} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/data_in(2)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input SUL} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/rx(3)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input SUL} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/credit_o(3)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input SUL} -radix hexadecimal /test_bench/HeMPS/proc($i)/".$pe_name."/PE_PLASMA/data_in(3)\n";
					
			
		}

		
		print C_FILE "TreeUpdate [SetDefaultTree]\n";
		print C_FILE "WaveRestoreCursors {{Cursor 1} {1627970253 ps} 0}\n";
		print C_FILE "configure wave -namecolwidth 190\n";
		print C_FILE "configure wave -valuecolwidth 100\n";
		print C_FILE "configure wave -justifyvalue left\n";
		print C_FILE "configure wave -signalnamewidth 1\n";
		print C_FILE "configure wave -snapdistance 10\n";
		print C_FILE "configure wave -datasetprefix 0\n";
		print C_FILE "configure wave -rowmargin 4\n";
		print C_FILE "configure wave -childrowmargin 2\n";
		print C_FILE "configure wave -gridoffset 0\n";
		print C_FILE "configure wave -gridperiod 1\n";
		print C_FILE "configure wave -griddelta 40\n";
		print C_FILE "configure wave -timeline 0\n";	
		print C_FILE "configure wave -timelineunits ps\n";
		print C_FILE "update\n";
		print C_FILE "WaveRestoreZoom {0 ps} {3198211064 ps}\n";

	}
	else
	{
	
		print C_FILE "onerror {resume}\n"; 
		print C_FILE "quietly WaveActivateNextPane {} 0\n";
		print C_FILE "add wave /test_bench/hemps/clock\n";
	
		print C_FILE "add wave  -divider repository\n";
		print C_FILE "add wave  -radix hexadecimal /test_bench/ack_app(0)\n";
		print C_FILE "add wave  -radix hexadecimal /test_bench/req_app(0)\n";
		print C_FILE "add wave  -radix hexadecimal /test_bench/address(0)\n";
		print C_FILE "add wave  -radix hexadecimal /test_bench/data_read(0)\n";
		print C_FILE "add wave  -divider Slaves\n";
	
		for($i=0; $i< ($x_dimensions*$y_dimensions); $i++){
		
				$x = 0; 
				$y = 0;
			
				$addr = $i;
				while ($addr - $x_dimensions >= 0){
					$addr -= $x_dimensions;
					$y = $y + 1;
				}
				$x = $addr;
			
				$is_cluster_x = $x;
				$is_cluster_y = $y;
			
				while($is_cluster_x > 0){
					$is_cluster_x = $is_cluster_x - $x_cluster;
				}
				while($is_cluster_y > 0){
					$is_cluster_y = $is_cluster_y - $y_cluster;
				}
			
				$pe_name = "slave";
			
				if ($i == $masterAddress){
					$pe_name = "master";
				} elsif ($is_cluster_x == 0 && $is_cluster_y == 0){
					$pe_name = "local";
				}
			
				#print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/address\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} /test_bench/hemps/".$pe_name."$i/clock\n";
				if ($pe_name eq "slave"){
					print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} /test_bench/hemps/".$pe_name."$i/tick_counter\n";
					print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} /test_bench/hemps/".$pe_name."$i/tick_counter_local\n";
					print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} /test_bench/hemps/".$pe_name."$i/tick_counter_local_nohold\n";

					print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} /test_bench/hemps/".$pe_name."$i/clock_hold\n";
					print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} /test_bench/hemps/".$pe_name."$i/clock_divider\n";
					print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} /test_bench/hemps/".$pe_name."$i/clock_reg\n";
	
				} elsif($pe_name eq "master"){
					print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} /test_bench/hemps/".$pe_name."$i/ack_app\n";
					print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} /test_bench/hemps/".$pe_name."$i/req_app\n";
					print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} /test_bench/hemps/".$pe_name."$i/address\n";
					print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} /test_bench/hemps/".$pe_name."$i/data_read\n";
					print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} /test_bench/hemps/".$pe_name."$i/cpu_repo_acess\n";
					print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} /test_bench/hemps/".$pe_name."$i/repo_FSM\n";
				
					print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} /test_bench/hemps/".$pe_name."$i/clock_hold\n";
					print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} /test_bench/hemps/".$pe_name."$i/clock_divider\n";
					print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} /test_bench/hemps/".$pe_name."$i/clock_reg\n";
					print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} /test_bench/hemps/".$pe_name."$i/tick_counter\n";
					print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} /test_bench/hemps/".$pe_name."$i/tick_counter_local\n";
					print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} /test_bench/hemps/".$pe_name."$i/tick_counter_local_nohold\n";

				}


				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {ni $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/tx_ni\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {ni $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/credit_i_ni\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {ni $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/data_out_ni\n";
			
			
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/clock\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/reset\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/tx\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/data_out\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/credit_i\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/clock_tx\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/rx\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/data_in\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/credit_o\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/clock_rx\n";

				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {config $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/operation\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {config $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/set_address\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {config $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/set_address_2\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {config $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/set_size\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {config $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/set_size_2\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {config $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/set_op\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {config $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/start\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {config $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/size\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {config $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/size_2\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {config $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/address\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {config $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/address_2\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {config $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/config_data\n";
			

				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {arb $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/ARB\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {arb $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/prio\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {arb $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/timer\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {arb $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/write_enable\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {arb $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/read_enable\n";

				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {send $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/send_buffer\n";	
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {send $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/s_read_av\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {send $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/s_slot_available\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {send $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/s_first\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {send $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/s_last\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {send $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/s_almost_full\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {send $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/s_almost_empty\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {send $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/s_add_buffer\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {send $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/s_remove_buffer_ni\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {send $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/s_add_buffer_dma\n";

				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {send DMA $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/DMNI_Send\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {send DMA $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/send_address\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {send DMA $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/mem_data_read\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {send DMA $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/send_size\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {send DMA $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/send_address_2\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {send DMA $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/send_size_2\n";	
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {send DMA $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/sending_dma\n";	

				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {send NoC $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/send_ni_state\n";	
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {send NoC $x$y} -color red -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/tentou_enviar_rede\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {send NoC $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/s_payload_size\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {send NoC $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/s_payload_size_2\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {send NoC $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/sending_ni\n";

				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {receive $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/read_av\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {receive $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/slot_available\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {receive $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/first\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {receive $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/last\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {receive $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/almost_full\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {receive $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/almost_empty\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {receive $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/add_buffer\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {receive $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/add_buffer_ni\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {receive $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/remove_buffer_dma\n";

				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {receive DMA $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/DMNI_Receive\n";		
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {receive DMA $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/recv_address\n";		
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {receive DMA $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/mem_data_write\n";		
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {receive DMA $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/mem_address\n";		
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {receive DMA $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/recv_size\n";		
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {receive DMA $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/mem_byte_we\n";	
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {receive DMA $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/receiving_dma\n";	
			
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {receive NoC $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/receive_buffer\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {receive NoC $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/intr\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {receive NoC $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/intr_count\n";			
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {receive NoC $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/SR\n";	
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {receive NoC $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/payload_size\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -group {receive NoC $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/receiving_ni\n";

				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/mem_address\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/is_header\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/send_active\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {dmni $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/dmni/receive_active\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {proc $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/current_page\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {proc $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/cpu_mem_address\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {proc $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/write_enable\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {proc $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/pending_service\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {proc $x$y} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/irq_status\n";

				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input LOCAL} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/free(4)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input LOCAL} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/rx(4)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input LOCAL} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/credit_o(4)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input LOCAL} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/credit_i(4)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input LOCAL} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/data_in(4)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input LOCAL} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/clock_tx(4)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input LOCAL} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/clock_rx(4)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input LOCAL} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/tx(4)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input LOCAL} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/data_out(4)\n";

				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input LOCAL} -group {fila LOCAL} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila4/counter_flit\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input LOCAL} -group {fila LOCAL} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila4/data\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input LOCAL} -group {fila LOCAL} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila4/data_av\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input LOCAL} -group {fila LOCAL} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila4/data_in\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input LOCAL} -group {fila LOCAL} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila4/h\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input LOCAL} -group {fila LOCAL} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila4/credit_o\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input LOCAL} -group {fila LOCAL} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila4/sender\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input LOCAL} -group {fila LOCAL} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila4/ack_h\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input LOCAL} -group {fila LOCAL} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila4/rx\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input LOCAL} -group {fila LOCAL} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila4/data_ack\n";


				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input LESTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/free(0)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input LESTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/rx(0)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input LESTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/credit_o(0)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input LESTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/credit_i(0)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input LESTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/data_in(0)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input LESTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/clock_tx(0)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input LESTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/clock_rx(0)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input LESTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/tx(0)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input LESTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/data_out(0)\n";

				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input LESTE} -group {fila LESTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila0/counter_flit\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input LESTE} -group {fila LESTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila0/data\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input LESTE} -group {fila LESTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila0/data_av\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input LESTE} -group {fila LESTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila0/data_in\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input LESTE} -group {fila LESTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila0/h\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input LESTE} -group {fila LESTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila0/credit_o\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input LESTE} -group {fila LESTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila0/sender\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input LESTE} -group {fila LESTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila0/ack_h\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input LESTE} -group {fila LESTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila0/rx\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input LESTE} -group {fila LESTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila0/data_ack\n";



				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input OESTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/free(1)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input OESTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/rx(1)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input OESTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/credit_o(1)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input OESTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/credit_i(1)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input OESTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/data_in(1)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input OESTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/clock_tx(1)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input OESTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/clock_rx(1)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input OESTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/tx(1)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input OESTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/data_out(1)\n";

				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input OESTE} -group {fila OESTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila1/counter_flit\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input OESTE} -group {fila OESTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila1/data\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input OESTE} -group {fila OESTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila1/data_av\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input OESTE} -group {fila OESTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila1/data_in\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input OESTE} -group {fila OESTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila1/h\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input OESTE} -group {fila OESTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila1/credit_o\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input OESTE} -group {fila OESTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila1/sender\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input OESTE} -group {fila OESTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila1/ack_h\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input OESTE} -group {fila OESTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila1/rx\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input OESTE} -group {fila OESTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila1/data_ack\n";



				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input NORTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/free(2)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input NORTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/rx(2)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input NORTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/credit_o(2)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input NORTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/credit_i(2)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input NORTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/data_in(2)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input NORTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/clock_tx(2)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input NORTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/clock_rx(2)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input NORTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/tx(2)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input NORTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/data_out(2)\n";

				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input NORTE} -group {fila NORTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila2/counter_flit\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input NORTE} -group {fila NORTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila2/data\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input NORTE} -group {fila NORTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila2/data_av\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input NORTE} -group {fila NORTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila2/data_in\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input NORTE} -group {fila NORTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila2/h\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input NORTE} -group {fila NORTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila2/credit_o\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input NORTE} -group {fila NORTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila2/sender\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input NORTE} -group {fila NORTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila2/rx\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input NORTE} -group {fila NORTE} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila2/data_ack\n";



				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input SUL} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/free(3)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input SUL} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/rx(3)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input SUL} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/credit_o(3)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input SUL} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/credit_i(3)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input SUL} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/data_in(3)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input SUL} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/clock_tx(3)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input SUL} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/clock_rx(3)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input SUL} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/tx(3)\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input SUL} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/data_out(3)\n";

				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input SUL} -group {fila SUL} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila3/counter_flit\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input SUL} -group {fila SUL} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila3/data\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input SUL} -group {fila SUL} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila3/data_av\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input SUL} -group {fila SUL} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila3/data_in\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input SUL} -group {fila SUL} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila3/h\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input SUL} -group {fila SUL} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila3/credit_o\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input SUL} -group {fila SUL} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila3/sender\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input SUL} -group {fila SUL} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila3/ack_h\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input SUL} -group {fila SUL} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila3/rx\n";
				print C_FILE "add wave  -group {".$pe_name." $x$y - ".$i."} -group {router $x$y input SUL} -group {fila SUL} -radix hexadecimal /test_bench/hemps/".$pe_name."$i/router/fila3/data_ack\n";

		}

	
		print C_FILE "TreeUpdate [SetDefaultTree]\n";
		print C_FILE "WaveRestoreCursors {{Cursor 1} {1627970253 ps} 0}\n";
		print C_FILE "configure wave -namecolwidth 190\n";
		print C_FILE "configure wave -valuecolwidth 100\n";
		print C_FILE "configure wave -justifyvalue left\n";
		print C_FILE "configure wave -signalnamewidth 1\n";
		print C_FILE "configure wave -snapdistance 10\n";
		print C_FILE "configure wave -datasetprefix 0\n";
		print C_FILE "configure wave -rowmargin 4\n";
		print C_FILE "configure wave -childrowmargin 2\n";
		print C_FILE "configure wave -gridoffset 0\n";
		print C_FILE "configure wave -gridperiod 1\n";
		print C_FILE "configure wave -griddelta 40\n";
		print C_FILE "configure wave -timeline 0\n";	
		print C_FILE "configure wave -timelineunits ps\n";
		print C_FILE "update\n";
		print C_FILE "WaveRestoreZoom {0 ps} {3198211064 ps}\n";	
	}
	close(C_FILE);
	
	
}

#################################################################################################
################################## Generates hemps_param.h ######################################
#################################################################################################

sub generate_hemps_param{
	open( C_FILE, ">./$projectName/hemps_param.h");
	print C_FILE "// Parametrizable Values";
	$aux=$pageSize*1024;
	print C_FILE "\n#define PAGESIZE\t\t\t".$aux."\n";	
	close(C_FILE);
}

#################################################################################################
################################## Generates sim.do #############################################
#################################################################################################

sub generate_sim_do{
	open( C_FILE, ">./$projectName/sim.do" );
	
	print C_FILE "vsim -novopt -t ps +notimingchecks work.test_bench\n"; 
	print C_FILE "\n";
	print C_FILE "do wave.do\n";
	print C_FILE "onerror {resume}\n";
	print C_FILE "radix hex\n";
	print C_FILE "set NumericStdNoWarnings 1\n";
	print C_FILE "set StdArithNoWarnings 1\n";
	print C_FILE "\n";
 	if($procDescription eq "rtl"){
        print C_FILE "when -label end_of_simulation { hemps/proc($masterAddress)/mas/master/PE_PLASMA/plasma/end_sim_reg == x\"00000000\" } {echo \"End of simulation\" ; quit ;}\n";
 	} else {
		print C_FILE "when -label end_of_simulation { hemps/master$masterAddress/end_sim_reg == x\"00000000\" } {echo \"End of simulation\" ; quit ;}\n";
 	}
 	
	close(C_FILE);

}

#################################################################################################
################################## Generates makefile hardware ##################################
#################################################################################################

sub generate_makefile_hardware{
	
	open( C_FILE, ">./$projectName/makefile" );
	
	print C_FILE "#############################################################\n";
	print C_FILE "# Makefile geral para simulacao da Hybrid HeMPS no ambiente Nupedee\n";
	print C_FILE "#############################################################\n";
	print C_FILE "HEMPS_PATH=~/srcs/7.2\n";
	print C_FILE "UNISIM_PATH=~/srcs/xilinx/src/hemps_unisim\n";
	print C_FILE "XILINX=~/srcs/xilinx\n";
	print C_FILE "LIB=wrklib\n";
	print C_FILE "CDS_INST_DIR=/home/tools/cadence/installs/INCISIVE152\n";
	print C_FILE "# this environment variable must point to the hemps path, where the hardware,\n# software and tools folders are located\n";
	print C_FILE "BASE_PATH=\$(HEMPS_PATH)\nHW_PATH=\$(BASE_PATH)/hardware\n\n";
	
	print C_FILE "#VHDL Files\n";
	print C_FILE "PKG_SRC=HeMPS_defaults.vhd\nPKG_DIR=\$(HW_PATH)/top\nPKG_PATH=\$(addprefix \$(PKG_DIR)/,\$(PKG_SRC))\n\n";
	
	print C_FILE "SCENARIO_SRC=HeMPS_PKG.vhd #repository.vhd\nSCENARIO_DIR=.\nSCENARIO_PATH=\$(addprefix \$(SCENARIO_DIR)/,\$(SCENARIO_SRC))\n\n";
	
	print C_FILE "MPACK_SRC=mlite_pack.vhd UartFile.vhd\nMPACK_DIR=\$(HW_PATH)/plasma/rtl\nMPACK_PATH=\$(addprefix \$(MPACK_DIR)/,\$(MPACK_SRC))\n\n";
	
	print C_FILE "MLITE_SRC=alu.vhd bus_mux.vhd control.vhd mem_ctrl.vhd mult.vhd pc_next.vhd pipeline.vhd reg_bank.vhd shifter.vhd mlite_cpu.vhd\nMLITE_DIR=\$(HW_PATH)/plasma/rtl\nMLITE_PATH=\$(addprefix \$(MLITE_DIR)/,\$(MLITE_SRC))\n\n";
	
	print C_FILE "DMNI_SRC=dmni.vhd\nDMNI_DIR=\$(HW_PATH)/dmni/rtl\nDMNI_PATH=\$(addprefix \$(DMNI_DIR)/,\$(DMNI_SRC))\n\n";
	
	print C_FILE "ROUTER_SRC=Hermes_buffer.vhd Hermes_crossbar.vhd Hermes_switchcontrol.vhd RouterCC.vhd\nROUTER_DIR=\$(HW_PATH)/router/rtl\nROUTER_PATH=\$(addprefix \$(ROUTER_DIR)/,\$(ROUTER_SRC))\n\n";

	print C_FILE "PLASMA_RAM_SRC=ram_master.vhd ram_plasma.vhd\nPLASMA_RAM_DIR=\$(SCENARIO_DIR)/plasma_ram/rtl\nPLASMA_RAM_PATH=\$(addprefix \$(PLASMA_RAM_DIR)/,\$(PLASMA_RAM_SRC))\n\n";
	
	print C_FILE "PLASMA_SRC=access_repository.vhd plasma.vhd\nPLASMA_DIR=\$(HW_PATH)/plasma/rtl\nPLASMA_PATH=\$(addprefix \$(PLASMA_DIR)/,\$(PLASMA_SRC))\n\n";
	
	print C_FILE "BUS_SRC_RR=bus_ctrl_hy.vhd rr_arbiter.vhd Bus_BridgeRR.vhd plasma_busRR.vhd #Bus_Wrapper.sv\nBUS_DIR_RR=\$(HW_PATH)/bus/bus_RR\nBUS_PATH_RR=\$(addprefix \$(BUS_DIR_RR)/,\$(BUS_SRC_RR))\n\n";
	
	print C_FILE "CROSS_SRC=bus_arb_gen.vhd crossbar_bridge.vhd crossgen.vhd plasma_cross.vhd #Crossbar_Wrapper.sv\nCROSS_DIR=\$(HW_PATH)/crossbar\nCROSS_PATH=\$(addprefix \$(CROSS_DIR)/,\$(CROSS_SRC))\n\n";
	
	print C_FILE "TOP_SRC=PE_injector.vhd processing_element.vhd HeMPS.vhd test_bench.vhd\nTOP_LOG=log_tb.vhd log_h_tb.vhd\nTB=tb_top_hybrid.sv tb_top_hybrid_HH.sv tb_top_hybrid_HH_comm.sv #if_logs_comm.sv\n";
	print C_FILE "TOP_LOCAL=if_plasma.sv Bus_Wrapper.sv Crossbar_Wrapper.sv hybrid_top_setup.sv\nTOP_DIR=\$(HW_PATH)/top\nTOP_PATH=\$(addprefix \$(TOP_DIR)/,\$(TOP_SRC))\n";
	print C_FILE "TB_PATH=\$(addprefix \$(TOP_DIR)/,\$(TB))\nTOP_LOCAL_PATH=\$(addprefix ./,\$(TOP_LOCAL))\nLOG=\$(addprefix \$(TOP_DIR)/,\$(TOP_LOG))\n\n";
	
	print C_FILE "#/////////////\n";
	print C_FILE "BLOCK_NAME=\nDEBUG_DIR=\n";
	if($bus_count>0 and $crossbar_count>0){
		print C_FILE "DUV_FILES= \$(SCENARIO_PATH) \$(PKG_PATH) \$(MPACK_PATH) \$(MLITE_PATH) \$(DMNI_PATH) \$(ROUTER_PATH) \$(PLASMA_RAM_PATH) \$(MBLITE_STD_PATH) \$(MBLITE_CORE_PATH) \$(MBLITE_RAM_PATH) \$(MBLITE_PATH) \$(PLASMA_PATH) \$(BUS_PATH_RR) \$(CROSS_PATH) \$(TOP_PATH)\n";
	}
	elsif($bus_count>0 and $crossbar_count==0){
		print C_FILE "DUV_FILES= \$(SCENARIO_PATH) \$(PKG_PATH) \$(MPACK_PATH) \$(MLITE_PATH) \$(DMNI_PATH) \$(ROUTER_PATH) \$(PLASMA_RAM_PATH) \$(MBLITE_STD_PATH) \$(MBLITE_CORE_PATH) \$(MBLITE_RAM_PATH) \$(MBLITE_PATH) \$(PLASMA_PATH) \$(BUS_PATH_RR) \$(TOP_PATH)\n";
	}
	else{
		print C_FILE "UV_FILES= \$(SCENARIO_PATH) \$(PKG_PATH) \$(MPACK_PATH) \$(MLITE_PATH) \$(DMNI_PATH) \$(ROUTER_PATH) \$(PLASMA_RAM_PATH) \$(MBLITE_STD_PATH) \$(MBLITE_CORE_PATH) \$(MBLITE_RAM_PATH) \$(MBLITE_PATH) \$(PLASMA_PATH) \$(CROSS_PATH) \$(TOP_PATH)\n";
	}
	print C_FILE "DUV_NAME=\nIP_FILES=\nTOP_NAME=HeMPS\nASSERT=\n\nIUS=irun\n";
	print C_FILE "########################## Command options #############################\n";
	print C_FILE "ELAB_OPTS=-message -LICQUEUE -timescale 1ns/1ns\nVLOG_OPTS= -sv\nVHDL_OPTS=-INITZERO -nobuiltin\nIRUN_OPTS=-assert -access +RW -mccodegen\nSIM_OPTS=\n\n";
	
	print C_FILE "##############################TAGS######################################\n";
	print C_FILE "echo:\n\t\@echo \$(DUV_FILES)\n\n";
	
	print C_FILE "compile:\n";
	print C_FILE "\t\@echo \"############################################################\"\n";
	print C_FILE "\t\@echo \"##################      COMPILE Designs   ##################\"\n";
	print C_FILE "\t\@echo \"############################################################\"\n";
	print C_FILE "\t#ncvhdl -messages -work unisim -smartorder\n\tncvlog \$(UNISIM_PATH)/glbl.v -vtimescale 1ns/1ps\n\tncvhdl -mess -v93 repository.vhd\n";
	print C_FILE "\tncvhdl -mess -v200X -list \$(DUV_FILES)\n\tncvhdl -mess -v200X -list \$(LOG)\n\tncvlog -mess -SV \$(TB_PATH) \$(TOP_LOCAL_PATH) -vtimescale 1ns/1ps\n\n";
	
	print C_FILE "unisim:\n";
	print C_FILE "\t\@echo \"############################################################\"\n";
	print C_FILE "\t\@echo \"##################    COMPILE UNISIM    ####################\"\n";
	print C_FILE "\t\@echo \"############################################################\"\n";
	print C_FILE "\tncvlog \$(UNISIM_PATH)/*.v -vtimescale 1ns/1ps\n\tncvhdl -work unisim -V200X \$(UNISIM_PATH)/vcomponents.vhd\n\n";
	
	print C_FILE "elab:\n";
	print C_FILE "\t\@echo \"############################################################\"\n";
	print C_FILE "\t\@echo \"################## ELABORATION  HeMPS  #####################\"\n";
	print C_FILE "\t\@echo \"############################################################\"\n";
	print C_FILE "\tncelab  -VHDLSYNC -disable_sem2009 -messages -nocopyright -libverbose -NOMXINDR -access +rwc work.test_bench work.glbl\n\n";
	
	print C_FILE "elabh:\n";
	print C_FILE "\t\@echo \"############################################################\"\n";
	print C_FILE "\t\@echo \"##################  ELABORATION HYBRID #####################\"\n";
	print C_FILE "\t\@echo \"############################################################\"\n";
	print C_FILE "\tncelab  -VHDLSYNC -disable_sem2009 -messages -nocopyright -libverbose -NOMXINDR -access +rwc work.hemps_hybrid_tb work.glbl\n\n";
	
	print C_FILE "sim:\n";
	print C_FILE "\t\@echo \"############################################################\"\n";
	print C_FILE "\t\@echo \"##################   SIMULATION HeMPS  #####################\"\n";
	print C_FILE "\t\@echo \"############################################################\"\n";
	print C_FILE "\tncsim -input input.in work.test_bench -gui\n\t\@cp -R log Log_HeMPS_`date +%a_%d-%m_%H:%M:%S_%Y`\n\n";
	
	print C_FILE "simh:\n";
	print C_FILE "\t\@echo \"############################################################\"\n";
	print C_FILE "\t\@echo \"##################   SIMULATION HYBRID #####################\"\n";
	print C_FILE "\t\@echo \"############################################################\"\n";
	print C_FILE "\tncsim -input input.in work.hemps_hybrid_tb -gui\n\t\@cp -R log Log_Hybrid`date +%a_%d-%m_%H:%M:%S_%Y`\n\n";
	
	print C_FILE "simnogui:\n";
	print C_FILE "\t\@echo \"#############################################################\"\n"; 
	print C_FILE "\t\@echo \"################## SIMULATION NO GUI HYBRID #################\"\n";
	print C_FILE "\t\@echo \"#############################################################\"\n";
	print C_FILE "\tncsim  work.hemps_hybrid_tb -input input_nogui.in\n\t\@cp -R log Log_Hybrid_`date +%a_%d-%m_%H:%M:%S_%Y`\n\n";
	
	print C_FILE "clean:\n";
	print C_FILE "\t\@rm -r log\n\t\@rm -rf wrklib/\n\t\@mkdir wrklib\n\t\@mkdir log\n\t\@cp ~/srcs/scripts_confs/hdl.var .\n\t\@cp ~/srcs/scripts_confs/cds.lib .\n";
	print C_FILE "\t\@cp ~/srcs/scripts_confs/input.in .\n\t\@cp ~/srcs/scripts_confs/input_nogui.in .\n\t\@cp ~/srcs/7.2/hardware/bus/bus_RR/Bus_Wrapper.sv .\n";
	print C_FILE "\t\@cp ~/srcs/7.2/hardware/crossbar/Crossbar_Wrapper.sv .\n\t\@rm -f *.key\n\t\@rm -f *.o\n\t\@rm -f *.log\n\t\@rm -f *~\n\n";
	
	print C_FILE "clean_unisim:\n\t\@rm -r ~/srcs/hemps_unisim/inca*";
	
	close(C_FILE);

 }

#################################################################################################
################################## Generates makefile software ##################################
#################################################################################################

sub generate_makefile_software{
	
	$pageSize_bytes = $pageSize *1024-1;
	$memorySize_bytes = $memorySize *1024-1;
	$kernelSize_bytes = $kernelSize *1024-1;
	$all="all: ";
	
	open( C_FILE, ">./$projectName/build/makefile" );
		
		
print C_FILE "
#this environment variable must point to the hemps path, where the hardware, software and tools folders are located

#Definition of Plasma toolchain
CFLAGS     = -Os -Wall -fms-extensions -c -s -std=c99 -G 0
CFLAGS_APP = -Os -Wall -fms-extensions -c -s -std=c99 -G 0
GCC_MIPS   = mips-elf-gcc \$(CFLAGS)
GCC_MIPS_APP   = mips-elf-gcc \$(CFLAGS_APP)
AS_MIPS    = mips-elf-as
LD_MIPS    = mips-elf-ld
DUMP_MIPS  = mips-elf-objdump
COPY_MIPS = mips-elf-objcopy -I elf32-bigmips -O binary
					
#Definition of MB-Lite toolchain
MB         = mb-gcc
AS         = mb-as
LD         = mb-ld
MB_OBJCOPY = mb-objcopy
MB_OBJDUMP = mb-objdump
XILFLAGS   =-mxl-soft-div -msoft-float -mxl-barrel-shift -mno-xl-soft-mul
CXXFLAGS   =-g -std=c99 -pedantic -Wall -O2
LNKFLAGS   =-Wl,-defsym -Wl,_STACK_SIZE=0x3000 -Wl,-defsym -Wl,_HEAP_SIZE=0x0000
LNKFLAGS2  =-Wl,-defsym -Wl,_STACK_SIZE=0x2000 -Wl,-defsym -Wl,_HEAP_SIZE=0x0000
MB_GCC     = \$(MB) \$(XILFLAGS) \$(CXXFLAGS) \$(LNKFLAGS2) \$(LIBFLAGS) \$(INCFLAGS) \$(CCFLAGS)

#TOOLS
BIN2MEM       = bin2mem
RAM_GENERATOR = ram_generator

INCLUDE       = \$(HEMPS_PATH)/software/include

#TASKS
";
	$cont_app_new2=0;
	$application_new2[0]=-1;													
	for($i=0; $i<$numberAPPs; $i++){
		$application_new2[$i]=-1;													

	}
	for($i=0; $i<$numberAPPs; $i++){
		$cont_aux=0;
		for($g=0; $g<=$cont_app_new2; $g++){
			if($applications[$i] eq $application_new2[$g]){
				$cont_aux=1;
			}
		}
		if($cont_aux == 0){
			$application_new2[$cont_app_new2]=$applications[$i];
		


		for($j=0; $j<$size_apps[$i]; $j++){


			$id_aux = ($cont_app_new2<<8) | $applications_Tasks_id[$i][$j][0];
			#sets task path
			print C_FILE "TASK";
			print C_FILE $id_aux;
			print C_FILE "_PATH = ../applications/$applications[$i]/$applications_Tasks[$i][$j]\n";
		
			# sets task include files
			print C_FILE "TASK";
			print C_FILE $id_aux;
			print C_FILE "_INCLUDE = ids_$application_new2[$cont_app_new2].h\n";
			
			# sets task source name
			$name_aux = $applications_Tasks[$i][$j];
			$name_aux =~ s/\.c//ig;
			print C_FILE "TASK";
			print C_FILE $id_aux;
			print C_FILE "_NAME = $name_aux\n";		
			
			# sets task ID
			print C_FILE "TASK";
			print C_FILE $id_aux;
			print C_FILE "_ID = $id_aux\n";	
					
			# sets task make target
			print C_FILE "TASK";
			print C_FILE $id_aux;
			print C_FILE "_TARGET = \$("."TASK".$id_aux."_NAME)_\$("."TASK".$id_aux."_ID)\n\n";		
		}
		$cont_app_new2++;

	}
	}
	
	print C_FILE "#tasks boot code for Plasma processor
BOOT_TASK_SRC     = \$(HEMPS_PATH)/software/include/bootTask.asm
BOOT_TASK         = bootTask

#kernel master source files
BOOT_MASTER_SRC   = \$(HEMPS_PATH)/software/kernel/master/boot.S
BOOT_MASTER       = boot_master
KERNEL_MASTER_SRC = \$(HEMPS_PATH)/software/kernel/master/kernel_master.c
KERNEL_MASTER     = kernel_master

#kernel slave plasma source files
BOOT_PLASMA_SRC   = \$(HEMPS_PATH)/software/kernel/slave/boot.S
BOOT_PLASMA       = boot_plasma
KERNEL_PLASMA_SRC = \$(HEMPS_PATH)/software/kernel/slave/kernel_slave.c
KERNEL_PLASMA     = kernel_plasma\n\n";

	#Task boot make target
	print C_FILE "bootTask:
\t\$(AS_MIPS) --defsym sp_addr=$pageSize_bytes -o \$(BOOT_TASK).o \$(BOOT_TASK_SRC)\n\n";
	$all = $all."bootTask ";
				
	#Kernel master make target
	print C_FILE "kernel_master:
\t\$(AS_MIPS) --defsym sp_addr=$memorySize_bytes -o \$(BOOT_MASTER).o \$(BOOT_MASTER_SRC)
\t\$(GCC_MIPS) -DHOP_NUMBER=$HOP_NUMBER_DEFINE -D$MPSOC_mapping -o \$(KERNEL_MASTER).o \$(KERNEL_MASTER_SRC) --include ids_master.h
\t\$(LD_MIPS) -Ttext 0 -eentry -Map \$(KERNEL_MASTER).map -s -N -o \$(KERNEL_MASTER).bin \$(BOOT_MASTER).o \$(KERNEL_MASTER).o
\t\$(LD_MIPS) -Ttext 0 -eentry -Map \$(KERNEL_MASTER)_debug.map -o \$(KERNEL_MASTER)_debug.bin  \$(BOOT_MASTER).o \$(KERNEL_MASTER).o
\t\$(DUMP_MIPS) -S \$(KERNEL_MASTER)_debug.bin > \$(KERNEL_MASTER).lst
\t\$(COPY_MIPS) \$(KERNEL_MASTER).bin \$(KERNEL_MASTER).dump
\thexdump -v -e '1/1 \"\%02x\" 1/1 \"\%02x\" 1/1 \"\%02x\" 1/1 \"\%02x\" \"\\n\"' \$(KERNEL_MASTER).dump > \$(KERNEL_MASTER).txt\n\n";
	$all = $all."kernel_master ";

	#Kernel slave make target - Plasma
	print C_FILE "kernel_plasma:
\t\$(AS_MIPS) --defsym sp_addr=$kernelSize_bytes -o \$(BOOT_PLASMA).o \$(BOOT_PLASMA_SRC)
\t\$(GCC_MIPS) -o \$(KERNEL_PLASMA).o \$(KERNEL_PLASMA_SRC) --include ids_slave.h -D PLASMA
\t\$(LD_MIPS) -Ttext 0 -eentry -Map \$(KERNEL_PLASMA).map -s -N -o \$(KERNEL_PLASMA).bin  \$(BOOT_PLASMA).o \$(KERNEL_PLASMA).o
\t\$(LD_MIPS) -Ttext 0 -eentry -Map \$(KERNEL_PLASMA)_debug.map -o \$(KERNEL_PLASMA)_debug.bin  \$(BOOT_PLASMA).o \$(KERNEL_PLASMA).o
\t\$(DUMP_MIPS) -S \$(KERNEL_PLASMA)_debug.bin > \$(KERNEL_PLASMA).lst
\t\$(COPY_MIPS) \$(KERNEL_PLASMA).bin \$(KERNEL_PLASMA).dump
\thexdump -v -e '1/1 \"\%02x\" 1/1 \"\%02x\" 1/1 \"\%02x\" 1/1 \"\%02x\" \"\\n\"' \$(KERNEL_PLASMA).dump > \$(KERNEL_PLASMA).txt\n\n";
	$all = $all."kernel_plasma ";

	#Generate the tasks make targets - tasks in processors
	$cont_app_new1=0;
	$application_new1[0]=-1;													
	for($i=0; $i<$numberAPPs; $i++){
		$application_new1[$i]=-1;													

	}
	for($i=0; $i<$numberAPPs; $i++){
		$cont_aux=0;
		for($g=0; $g<=$cont_app_new1; $g++){
			if($applications[$i] eq $application_new1[$g]){
				$cont_aux=1;
				last;
			}
		}
		if($cont_aux == 0){
			$application_new1[$cont_app_new1]=$applications[$i];
			
			for($j=0; $j<$size_apps[$i]; $j++){
				
			$id_aux = ($cont_app_new1<<8) | $applications_Tasks_id[$i][$j][0];
			
			$name_aux = $applications_Tasks[$i][$j];
			$name_aux =~ s/\.c//ig;
			$all = $all."$name_aux\_$id_aux ";

			$task_num_target = "\$(TASK"."$id_aux"."_TARGET)";
			$task_num_path = "\$(TASK"."$id_aux"."_PATH)";
			$task_num_include = "\$(TASK"."$id_aux"."_INCLUDE)";
			
			print C_FILE "$name_aux\_$id_aux:\n";
			print C_FILE "\t\$(GCC_MIPS_APP) $task_num_path -o $task_num_target.o --include $task_num_include -D PLASMA -I \$(INCLUDE)\n";				
			print C_FILE "\t\$(LD_MIPS) -Ttext 0 -eentry -Map $task_num_target.map -s -N -o $task_num_target.bin \$(BOOT_TASK).o $task_num_target.o\n";
			print C_FILE "\t\$(LD_MIPS) -Ttext 0 -eentry -Map $task_num_target\_debug.map -o $task_num_target\_debug.bin \$(BOOT_TASK).o $task_num_target.o\n";
			print C_FILE "\t\$(DUMP_MIPS) -S $task_num_target\_debug.bin > $task_num_target.lst\n";
			print C_FILE "\t\$(COPY_MIPS) $task_num_target.bin $task_num_target.dump\n";
			print C_FILE "\thexdump -v -e '1/1 \"\%02x\" 1/1 \"\%02x\" 1/1 \"\%02x\" 1/1 \"\%02x\" \"\\n\"' $task_num_target.dump > $task_num_target.txt\n";
		}
			$cont_app_new1++;
	
		}
	}
	
	print C_FILE "\nram_gen: ram_master ram_plasma\n\n";
	print C_FILE "ram_master:\n";
	print C_FILE "\t\$(RAM_GENERATOR) $memorySize -rtl kernel_master.txt > ram_master.vhd\n";
	print C_FILE "\tcp ram_master.vhd ../plasma_ram/rtl\n";
	print C_FILE "\t\$(RAM_GENERATOR) $memorySize -h kernel_master.txt > ram_master.h\n";
	print C_FILE "\tcp -rf \$(HEMPS_PATH)/hardware/sc_ram/ram_master.cpp ../plasma_ram/sc\n";	
	print C_FILE "\tcp ram_master.h ../plasma_ram/sc\n\n";

	print C_FILE "ram_plasma:\n";
	print C_FILE "\t\$(RAM_GENERATOR) $memorySize -rtl kernel_plasma.txt > ram_plasma.vhd\n";
	print C_FILE "\tcp ram_plasma.vhd ../plasma_ram/rtl\n";
	print C_FILE "\t\$(RAM_GENERATOR) $memorySize -h kernel_plasma.txt > ram_plasma.h\n";
	print C_FILE "\tcp -rf \$(HEMPS_PATH)/hardware/sc_ram/ram_plasma.cpp ../plasma_ram/sc\n";
	print C_FILE "\tcp ram_plasma.h ../plasma_ram/sc\n\n";				

	$all = $all."ram_gen";
	
	print C_FILE "clean:
\trm -rf *.bin
\trm -rf *.txt
\trm -rf *.mem
\trm -rf *.dump
\trm -rf *.lst
\trm -rf *.o
\trm -rf *.map
\trm -rf ram*.h
\trm -rf *.vhd
\trm -rf *.elf\n\n";

	print C_FILE $all;
	
	close(C_FILE);
	
	system("cd ./$projectName/build;make all > /dev/null ;cd -"); #2> /dev/null

}

#################################################################################################
################################## Generates HeMPS_PKG ##########################################
#################################################################################################

sub generate_Hemps_PKG{
	
	open( C_FILE_H, ">./$projectName/HeMPS_PKG.h" );
	open( C_FILE_VHD, ">./$projectName/HeMPS_PKG.vhd" );
		
	$kernelTypesNum = "$kernelTypesNum";
	$kernelTypesNum =~ s/\, \}\;/\,\}\;/ig;
	
	my @bus_position	   = @$bus_position;
	my @proc_per_bus	   = @$proc_per_bus;
	my @crossbar_position  = @$crossbar_position;
	my @proc_per_crossbar  = @$proc_per_crossbar;
	
# -------------------------------------------------------------------------------
# Addresses Functions -----------------------------------------------------------
# -------------------------------------------------------------------------------
	# Router, Bus Wrappers and Crossbar Wrappers Addresses
	for($i=0,$x=0,$y=0; $i<$y_dimensions*$x_dimensions; $i++){
		# Hexadecimal converter
		$x_aux2 = int($x/16);
		$y_aux2 = int($y/16);
		if($x%16>9 && $x%16<16){ # To Hexadecimal 10=A, 11=B, 12=C, 13=D, 14=E, 15=F
			if($x%16==10){$x_aux = "A";} 
			elsif($x%16==11){$x_aux = "B";}
			elsif($x%16==12){$x_aux = "C";}
			elsif($x%16==13){$x_aux = "D";}
			elsif($x%16==14){$x_aux = "E";}
			else{$x_aux = "F";}
		}
		else{
			$x_aux = $x%16;
		}
		if($y%16>9 && $y%16<16){ # To Hexadecimal 10=A, 11=B, 12=C, 13=D, 14=E, 15=F
			if($y%16==10){$y_aux = "A";}
			elsif($y%16==11){$y_aux = "B";}
			elsif($y%16==12){$y_aux = "C";}
			elsif($y%16==13){$y_aux = "D";}
			elsif($y%16==14){$y_aux = "E";}
			else{$y_aux = "F";}
		}
		else{
			$y_aux = $y%16;
		}
		# End Hexadecimal Converter
		#@router_addresses[$i]= "00000$x"."0$y"; # General Router Addresses
		@bus_flag[$i]=0;
		@crossbar_flag[$i]=0;
		for($j=0; $j<$bus_count; $j++){
			if($i == @$bus_position[$j]){
				@bus_flag[$i]=1;                      # 1 if there is a bus wrapper, 0 if Router
				@bus_addresses[$j] = "0000".$x_aux2."".$x_aux."".$y_aux2."".$y_aux.""; # Bus Wrapper Addresses
				$bus_proc_address[$j][0] = "0000".$x_aux2."".$x_aux."".$y_aux2."".$y_aux."";
			}
		}
		for($j=0; $j<$crossbar_count; $j++){
			if($i == @$crossbar_position[$j]){
				@crossbar_flag[$i]=1;
				@crossbar_addresses[$j] = "0000".$x_aux2."".$x_aux."".$y_aux2."".$y_aux."";
				$crossbar_proc_address[$j][0] = "0000".$x_aux2."".$x_aux."".$y_aux2."".$y_aux."";
			}
		}
		if($x<$x_dimensions-1){
			$x++;
		}
		else{
			$x = 0;
			$y++;
		}
	}
	# Generate Bus and Crossbar Processors Addresses for Hybrid NoC
	$x_dimensions_aux = $x_dimensions;
	$y_dimensions_aux = $y_dimensions;
	$x_bus = 0;
	$x_cross = 0;
	$y_bus = 1;
	$y_cross = 1;
	for($i=0, $x=0, $y=$y_dimensions; $i<$bus_proc_count+$crossbar_proc_count; $i++){
		# Hexadecimal converter
		$x_aux2 = int($x/16);
		$y_aux2 = int($y/16);
		if($x%16>9 && $x%16<16){ # To Hexadecimal 10=A, 11=B, 12=C, 13=D, 14=E, 15=F
			if($x%16==10){$x_aux = "A";} 
			elsif($x%16==11){$x_aux = "B";}
			elsif($x%16==12){$x_aux = "C";}
			elsif($x%16==13){$x_aux = "D";}
			elsif($x%16==14){$x_aux = "E";}
			else{$x_aux = "F";}
		}
		else{
			$x_aux = $x%16;
		}
		if($y%16>9 && $y%16<16){ # To Hexadecimal 10=A, 11=B, 12=C, 13=D, 14=E, 15=F
			if($y%16==10){$y_aux = "A";}
			elsif($y%16==11){$y_aux = "B";}
			elsif($y%16==12){$y_aux = "C";}
			elsif($y%16==13){$y_aux = "D";}
			elsif($y%16==14){$y_aux = "E";}
			else{$y_aux = "F";}
		}
		else{
			$y_aux = $y%16;
		}
		if($x_bus<$bus_count){ # Set the bus processors addresses, number of buses
			if($y_bus<@proc_per_bus[$x_bus]){ # Number of processors on each bus
				$bus_proc_address[$x_bus][$y_bus] = "0000".$x_aux2."".$x_aux."".$y_aux2."".$y_aux."";
				$y_bus++;
				$addr_flag=0;
			}
			else{ # new bus 
				$y_bus=1;
				$x_bus++;
				$addr_flag=1;
			}
		}
		else{ # Set the crossbar processors addresses
			if($x_cross<$crossbar_count){ # Number of crossbars
				if($y_cross<@proc_per_crossbar[$x_cross]){ # Number of processors on each crossbar
					$crossbar_proc_address[$x_cross][$y_cross] = "0000".$x_aux2."".$x_aux."".$y_aux2."".$y_aux."";
					$y_cross++;
					$addr_flag=0;
				}
				else{ # new crossbar
					$crossbar_proc_address[$x_cross][$y_cross] = "00000000"; # Fake Crossbar Wrapper Address
					$y_cross=1;
					$x_cross++;
					$addr_flag=1;
				}
			}
		}
		# Control the new NoC XY dimensions for extra addresses
		if($x<$x_dimensions_aux and $addr_flag==0){ # 
			$x++;
		}
		elsif($addr_flag==0){
			if($y>0){
				$y--;
			}
			else{
				$x_dimensions_aux++;
				$y_dimensions_aux++;
				$y = $y_dimensions_aux;
				$x = 0;
			}
		}
	}
	
	# Verfiry which bus and crossbar has more processors
	$largestbus = 0;
	$i=0;
	while($i<$bus_count){
		if($largestbus < @proc_per_bus[$i]){
			$largestbus = $proc_per_bus[$i];
		}
		$i++;
	}
	$largestcross = 0;
	$i=0;
	while($i<$crossbar_count){
		if($largestcross < @proc_per_crossbar[$i]){
			$largestcross = $proc_per_crossbar[$i];
		}
		$i++;
	}

	print C_FILE_VHD "\n";
	print C_FILE_VHD "--------------------------------------------------------------------------\n";
	print C_FILE_VHD "-- package com tipos basicos\n";
	print C_FILE_VHD "--------------------------------------------------------------------------\n";
	print C_FILE_VHD "library IEEE;\n";
	print C_FILE_VHD "use IEEE.Std_Logic_1164.all;\n";
	print C_FILE_VHD "use IEEE.std_logic_unsigned.all;\n";
	print C_FILE_VHD "use IEEE.std_logic_arith.all;\n";
	print C_FILE_VHD "\n";
	print C_FILE_VHD "package HeMPS_PKG is\n";
	print C_FILE_VHD "\n";
	print C_FILE_VHD "--------------------------------------------------------\n";
	print C_FILE_VHD "-- HEMPS CONSTANTS\n";
	print C_FILE_VHD "--------------------------------------------------------\n";
	print C_FILE_VHD "\t-- paging definitions\n";
	#print C_FILE_VHD "\tconstant PAGE_SIZE_H_INDEX\t: integer := ".$page_size_h_index.";\n";
	print C_FILE_VHD "\t-- Modified(?) for Hybrid, original PAGE_SIZE_H_INDEX is 11\n";
	print C_FILE_VHD "\tconstant PAGE_SIZE_H_INDEX\t: integer := 13;\n";
	print C_FILE_VHD "\tconstant PAGE_NUMBER_H_INDEX\t: integer := ".$page_number_h_index.";\n";
	print C_FILE_VHD "\n";
	print C_FILE_VHD "\t-- Hemps top definitions\n";
	print C_FILE_VHD "\tconstant NUMBER_PROCESSORS_X\t: integer := ".$x_dimensions."; \n";
	print C_FILE_VHD "\tconstant NUMBER_PROCESSORS_Y\t: integer := ".$y_dimensions."; \n";
	print C_FILE_VHD "\n";
	print C_FILE_VHD "\t--constant TAM_BUFFER\t\t: integer := ".$NoC_buffer_size.";\n";
	print C_FILE_VHD "\n";	
	print C_FILE_VHD "\tconstant MASTER_ADDRESS\t\t: integer := ".$masterAddress.";\n";
	print C_FILE_VHD "\tconstant NUMBER_PROCESSORS\t: integer := NUMBER_PROCESSORS_Y*NUMBER_PROCESSORS_X;\n";
	print C_FILE_VHD "\n";
	print C_FILE_VHD "\tsubtype core_str is string(1 to 6);\n";
	print C_FILE_VHD "\tsubtype kernel_str is string(1 to 3);\n";
	print C_FILE_VHD "\ttype core_type_type is array(0 to NUMBER_PROCESSORS-1) of core_str;\n"; 
	print C_FILE_VHD "\tconstant core_type : core_type_type := (";
	
	for($x=0; $x<$x_dimensions; $x++){
		for($y=0; $y<$y_dimensions; $y++){
			print C_FILE_VHD "\"plasma\"";
			if(($y != ($y_dimensions-1)) or ($x != ($x_dimensions-1))){
				print C_FILE_VHD ",";
			}
		}
	}
	
	print C_FILE_VHD ");\n";
	
	print C_FILE_VHD "\ttype kernel_type_type is array(0 to NUMBER_PROCESSORS-1) of kernel_str;\n";
	
	$kernelTypes =~ s/\,$//ig;
	
	print C_FILE_VHD "\tconstant kernel_type : kernel_type_type := (".$kernelTypes.");\n\n";
	
	print C_FILE_VHD "--------------------------------------------------------\n";
	print C_FILE_VHD "-- Hybrid HEMPS CONSTANTS\n";
	print C_FILE_VHD "--------------------------------------------------------\n";
	
	print C_FILE_VHD "\tconstant NUMBER_BUSES     : integer := ".$bus_count.";\n";
	print C_FILE_VHD "\tconstant NUMBER_CROSSBARS : integer := ".$crossbar_count.";\n";
	print C_FILE_VHD "\tconstant LARGESTBUS       : integer := ".$largestbus.";\n";
	print C_FILE_VHD "\tconstant LARGESTCROSSBAR  : integer := ".$largestcross.";\n\n";
	
	print C_FILE_VHD "\ttype Proc_Addresses is array(natural range <>) of std_logic_vector(31 downto 0);\n\n";
	
	# BUS DEFINITIONS ---------------------------------------------------------------------------------
	print C_FILE_VHD "\t-- Bus definitions\n";
	if($bus_count==1){
		print C_FILE_VHD "\tconstant NUMBER_PROCESSORS_BUS : integer := ".@proc_per_bus[0].";\n";
		print C_FILE_VHD "\tconstant BUS_POSITION          : integer := ".@bus_position[0].";\n";
		print C_FILE_VHD "\tconstant BUS_PROC_ADDR : Proc_Addresses(0 to LARGESTBUS-1) := (";
		for($j=0; $j<@proc_per_bus[0]; $j++){
			print C_FILE_VHD "x\"".$bus_proc_address[0][$j]."\"";
				if($j != @proc_per_bus[0]-1){
					print C_FILE_VHD ",";
				}
		}
		print C_FILE_VHD ");\n\n";
		
		print C_FILE_VHD "\t-- If NUMBER_BUSES = 1 this constant will not be used\n";
		print C_FILE_VHD "\ttype array_Proc_Bus_Addresses is array(0 to 1) of Proc_Addresses(0 to LARGESTBUS-1);\n";
		print C_FILE_VHD "\tconstant BUS_PROC_ADDRS : array_Proc_Bus_Addresses := (others=>(others=>(others=>'U')));\n";
	}
	elsif($bus_count>1){ # bus_count>1
		print C_FILE_VHD "\t-- If NUMBER_BUSES > 1 this constant will not be used but needs to be created\n";
		print C_FILE_VHD "\tconstant BUS_PROC_ADDR : Proc_Addresses(0 to LARGESTBUS-1) := (others=>(others=>'U'));\n\n";
		print C_FILE_VHD "\ttype array_BusInfo is array(0 to NUMBER_BUSES-1) of integer;\n";
		print C_FILE_VHD "\tconstant NUMBER_PROCESSORS_BUS : array_BusInfo := (";
		for($i=0;$i<$bus_count;$i++){
			print C_FILE_VHD "".@proc_per_bus[$i]."";
			if($i != $bus_count-1){
				print C_FILE_VHD ",";
			}
		}
		print C_FILE_VHD ");\n";
		print C_FILE_VHD "\tconstant BUS_POSITION          : array_BusInfo := (";
		for($i=0;$i<$bus_count;$i++){
			print C_FILE_VHD "".@bus_position[$i]."";
			if($i != $bus_count-1){
				print C_FILE_VHD ",";
			}
		}
		print C_FILE_VHD ");\n";
		print C_FILE_VHD "\ttype array_Proc_Bus_Addresses is array(0 to NUMBER_BUSES-1) of Proc_Addresses(0 to LARGESTBUS-1);\n";
		print C_FILE_VHD "\tconstant BUS_PROC_ADDRS : array_Proc_Bus_Addresses := ((";
		for($i=0; $i<$bus_count; $i++){
			for($j=0; $j<$largestbus; $j++){
				if($j<@proc_per_bus[$i]){
					print C_FILE_VHD "x\"".$bus_proc_address[$i][$j]."\"";
				}
				else{
					print C_FILE_VHD "x\"00000000\"";
				}
				if($j != $largestbus-1){
					print C_FILE_VHD ",";
				}
			}
			if($i != $bus_count-1){
				print C_FILE_VHD "),(";
			}
		}
		print C_FILE_VHD "));\n";
	}
	else{
		print C_FILE_VHD "\t-- No Buses\n";
	}
	
	# CROSSBAR DEFINITIONS ---------------------------------------------------------------------------------
	print C_FILE_VHD "\n\t-- Crossbar definitions\n";
	if($crossbar_count==1){
		print C_FILE_VHD "\t-- The Crossbar Address constants has an extra x\"00000000\" for a fake Crossbar Wrapper address\n";
		print C_FILE_VHD "\tconstant NUMBER_PROCESSORS_CROSSBAR : integer := ".$proc_per_crossbar[0].";\n";
		print C_FILE_VHD "\tconstant CROSSBAR_POSITION          : integer := ".$crossbar_position[0].";\n";
		print C_FILE_VHD "\tconstant Crossbar_Proc_Addr: Proc_Addresses(0 to LARGESTCROSSBAR) := (";
		for($j=0; $j<=@proc_per_crossbar[0]; $j++){
			print C_FILE_VHD "x\"".$crossbar_proc_address[0][$j]."\"";
				if($j != @proc_per_crossbar[0]){
					print C_FILE_VHD ",";
				}
		}
		print C_FILE_VHD ");\n\n";
		
		print C_FILE_VHD "\t-- If NUMBER_CROSSBARS = 1 this constant will not be used but needs to be created\n";
		print C_FILE_VHD "\ttype array_Proc_Crossbar_Addresses is array(0 to 1) of Proc_Addresses(0 to LARGESTCROSSBAR);\n";
		print C_FILE_VHD "\tconstant CROSSBAR_PROC_ADDRS : array_Proc_Crossbar_Addresses := (others=>(others=>(others=>'U')));\n";
	}
	elsif($crossbar_count>1){ # $crossbar_count>1
		print C_FILE_VHD "\t-- The Crossbar Address constants has an extra x\"00000000\" for a fake Crossbar Wrapper address\n";
		print C_FILE_VHD "\t-- If NUMBER_CROSSBARS > 1 this constant will not be used but needs to be created\n";
		print C_FILE_VHD "\tconstant CROSSBAR_PROC_ADDR : Proc_Addresses(0 to LARGESTCROSSBAR) := (others=>(others=>'U'));\n\n";
		print C_FILE_VHD "\ttype array_CrossbarInfo is array(0 to NUMBER_CROSSBARS-1) of integer;\n";
		print C_FILE_VHD "\tconstant NUMBER_PROCESSORS_CROSSBAR : array_CrossbarInfo := (";
		for($i=0;$i<$crossbar_count;$i++){
			print C_FILE_VHD "".@proc_per_crossbar[$i]."";
			if($i != $crossbar_count-1){
				print C_FILE_VHD ",";
			}
		}
		print C_FILE_VHD ");\n";
		print C_FILE_VHD "\tconstant CROSSBAR_POSITION          : array_CrossbarInfo := (";
		for($i=0;$i<$crossbar_count;$i++){
			print C_FILE_VHD "".@crossbar_position[$i]."";
			if($i != $crossbar_count-1){
				print C_FILE_VHD ",";
			}
		}
		print C_FILE_VHD ");\n";
		print C_FILE_VHD "\ttype array_Proc_Crossbar_Addresses is array(0 to NUMBER_CROSSBARS-1) of Proc_Addresses(0 to LARGESTCROSSBAR);\n";
		print C_FILE_VHD "\tconstant CROSSBAR_PROC_ADDRS : array_Proc_Crossbar_Addresses := ((";
		for($i=0; $i<$crossbar_count; $i++){
			for($j=0; $j<=$largestcross; $j++){
				if($j<@proc_per_crossbar[$i]){
					print C_FILE_VHD "x\"".$crossbar_proc_address[$i][$j]."\"";
				}
				else{
					print C_FILE_VHD "x\"00000000\"";
				}
				if($j != $largestcross){
					print C_FILE_VHD ",";
				}
			}
			if($i != $crossbar_count-1){
				print C_FILE_VHD "),(";
			}
		}
		print C_FILE_VHD "));\n";
	}
	else{
		print C_FILE_VHD "\t-- No Crossbars\n";
	}
	
	
	print C_FILE_VHD "\nend HeMPS_PKG;";

	
	print C_FILE_H "#ifndef _HeMPS_PKG\n";
	print C_FILE_H "#define _HeMPS_PKG\n\n";
	print C_FILE_H "#define N_PE_X ".$x_dimensions."\n";
	print C_FILE_H "#define N_PE_Y ".$y_dimensions."\n";
	print C_FILE_H "#define N_PE N_PE_Y*N_PE_X\n";
	print C_FILE_H "#define MASTER ".$masterAddress."\n\n";
	print C_FILE_H "const int kernel_type[N_PE] = {".$kernelTypesNum."};\n\n";
	print C_FILE_H "#endif";

	close(C_FILE_H);
	close(C_FILE_VHD);

}

#################################################################################################
################################## PARAMETERS MEMORY ############################################
#################################################################################################

sub parameters_memory{


	opendir(DIR, "./$projectName/build");
	(@aux)=readdir(DIR);
	@aux = sort @aux;
	closedir(DIR);
	
	$size=@aux;
	$max_size_task=0;
	$max_size_kernel=0;
	
	for($i=0; $i<$size; $i++){
		if(($aux[$i] =~ /.bin/) && ($aux[$i] !~ /kernel/)){
			$sizes_men= `mips-elf-size -t ./$projectName/build/$aux[$i]`;
			$sizes_men =~ s/\s+/ /ig;

			@size_max_task = split(/\s/,$sizes_men);
			
			if($max_size_task < $size_max_task[16]){
				($max_size_task) = $size_max_task[16];
			}
		}

		if(($aux[$i] =~ /.bin/) && ($aux[$i] =~ /kernel/)){
			$sizes_men= `mips-elf-size -t ./$projectName/build/$aux[$i]`;
			$sizes_men =~ s/\s+/ /ig;

			@size_max_task = split(/\s/,$sizes_men);
			
			if($max_size_kernel < $size_max_task[16]){
				($max_size_kernel) = $size_max_task[16];
			}
		}
		
	}
		
	use POSIX;
	$pageSize = 2 ** floor((log($max_size_task*2)/log(2))+1)/1024;
	$kernelSize = 2 ** floor((log($max_size_kernel*1.5)/log(2))+1)/1024;
	
	# Calculates Kernel Pages
	if($kernelSize % $pageSize == 0){
			$kernelPages = $kernelSize / $pageSize;
	}
	else{
		
		$kernelPages = floor($kernelSize / $pageSize + 1);
	}
	
	# Defines Maximum Tasks/slave
	$maxTasksSlave = $pagesPerPe;
	
	$memorySize = $pageSize * ($kernelPages + $pagesPerPe);

	if($memorySize <= 64){
		$memorySize = 64;
	}elsif($memorySize <= 128){
		$memorySize = 128;
	}elsif($memorySize <= 256){
		$memorySize = 256;
	}elsif($memorySize <= 512){
		$memorySize = 512;
	}elsif($memorySize <= 1024){
		$memorySize = 1024;
	}
	
	# Gets Page Size H Index
	$page_size_h_index = log($pageSize*1024)/log(2) -1;	
	
	# Gets Page Size H Index
	$page_number_h_index = log($memorySize/ $pageSize)/log(2) + $page_size_h_index;
	
}

#################################################################################################
################################## PARAMETERS MEMORY PER MEMORY SIZE ############################
#################################################################################################

sub parameters_memory_per_memory_size{

	
	# Calculates Kernel Pages
	if($kernelSize % $pageSize == 0){
			$kernelPages = $kernelSize / $pageSize;
	}
	else{
		$kernelPages = floor($kernelSize / $pageSize + 1);
	}
	
	# Defines Maximum Tasks/slave
	$maxTasksSlave = $memorySize / $pageSize - $kernelPages;
	
	
	# Gets Page Size H Index
	$page_size_h_index = log($pageSize*1024)/log(2) -1;	
	
	# Gets Page Size H Index
	$page_number_h_index = log($memorySize/ $pageSize)/log(2) + $page_size_h_index;
	
}

#################################################################################################
################################## PARAMETERS MEMORY FAKE #######################################
#################################################################################################

sub parameters_memory_fake{

	$pageSize = 32;
	$memorySize = 128;
	
	# Calculates Kernel Pages
	if($kernelSize % $pageSize == 0){
			$kernelPages = $kernelSize / $pageSize;
	}
	else{
		$kernelPages = floor($kernelSize / $pageSize + 1);
	}
	
	# Defines Maximum Tasks/slave
	$maxTasksSlave = $memorySize / $pageSize - $kernelPages;
	
	
	# Gets Page Size H Index
	$page_size_h_index = log($pageSize*1024)/log(2) -1;	
	
	# Gets Page Size H Index
	$page_number_h_index = log($memorySize/ $pageSize)/log(2) + $page_size_h_index;
	
}

#################################################################################################
################################### INITIAL TASKS ###############################################
#################################################################################################

sub initial_tasks {

	for($i=0; $i<$numberAPPs; $i++){
		$initCount=0;

		for($j=0; $j<$size_apps[$i]; $j++) {
			$initTasks[$i][$j][0]=-1;
		}

		open( C_FILE, "<./$projectName/applications/$applications[$i]/$applications[$i].cfg" );
		my @c_lines = <C_FILE>;
		close(C_FILE);

		$initial_ok = 0;
		$initial_reading = 0;
		$tagInitial = "<initialTasks>";
		foreach $c_line (@c_lines) {	# tarefas iniciais
			chomp $c_line;
			if ($c_line eq "<dependences>") {
				last;
			}
			if ($initial_reading == 1) {
				for($j=0; $j<$size_apps[$i]; $j++){
					if($c_line =~ /</ig){
						$initial_ok = 1;
						$initial_reading = 0;
					}
					elsif (($initial_ok eq 0) && ($c_line.".c" eq $applications_Tasks[$i][$j])) {
						$initTasks[$i][$j][0]=1;
					}
				}
			}

			if ($c_line eq $tagInitial) {
				$initial_reading = 1;
			}
		}
	}
}
#################################################################################################
################################## QUICKSORT ####################################################
#################################################################################################

sub quicksort {
    my @lista = @_;
    my (@menores, @iguais, @maiores);
 
    return @lista if @lista < 2;
    foreach (@lista) {
        if ($_ < $lista[0]) {
            push @menores, $_;
        }
        elsif ($_ == $lista[0]) {
            push @iguais, $_;
        }
        else {
            push @maiores, $_;
        }
    }
    return quicksort(@menores), @iguais, quicksort(@maiores);
}

#################################################################################################
################################## READ APPLICATIONS INFO #######################################
#################################################################################################

sub read_applications_info {

	$numberAPPs = @applications;

	@result = quicksort(@StartTimeApp);

	
	for($i=0; $i<$numberAPPs; $i++){									# ordena as aplicacoes em ordem de tempo de insersao no MPSoC

		for($j=0; $j<$numberAPPs; $j++){
			if(($StartTimeApp[$i] eq $result[$j])){
				($applications_new[$j])=$applications[$i];
				($StartTimeApp_new[$j])=$StartTimeApp[$i];
				$result[$j]=-1;
				last;
			}
		}
	}
	(@applications)=@applications_new;
	(@StartTimeApp)=@StartTimeApp_new;
		
	if($path_applications ne ""){
		$path_applications =~ s/\s//ig;
		$path_applications =~ s/\/$//ig;
		$path_applications = $path_applications."/";
		$max_app_size=0;
		$appID=0;
		$taskID=0;
		$taskNumber=0;
		

		for($i=0; $i<$numberAPPs; $i++){
			system("mkdir ./$projectName/applications/$applications[$i] 2> /dev/null");
			if(-d $path_applications.$applications[$i]){
				system("cp -rf $path_applications$applications[$i]/*.c   ./$projectName/applications/$applications[$i] 2> /dev/null");
				system("cp -rf $path_applications$applications[$i]/*.h   ./$projectName/applications/$applications[$i] 2> /dev/null");
				system("cp -rf $path_applications$applications[$i]/*.cfg ./$projectName/applications/$applications[$i] 2> /dev/null");
			}
			elsif(-d $applications[$i]){
				system("cp -rf $applications[$i]/*.c   ./$projectName/applications/$applications[$i] 2> /dev/null");
				system("cp -rf $applications[$i]/*.h   ./$projectName/applications/$applications[$i] 2> /dev/null");
				system("cp -rf $applications[$i]/*.cfg ./$projectName/applications/$applications[$i] 2> /dev/null");
			}
			else{
				system("cp -if(-d $path_applications.$applications[$i]){rf \$HEMPS_PATH/applications/$applications[$i]/*.c   ./$projectName/applications/$applications[$i] 2> /dev/null");
				system("cp -rf \$HEMPS_PATH/applications/$applications[$i]/*.h   ./$projectName/applications/$applications[$i] 2> /dev/null");
				system("cp -rf \$HEMPS_PATH/applications/$applications[$i]/*.cfg ./$projectName/applications/$applications[$i] 2> /dev/null");
			}

			opendir(DIR, "./$projectName/applications/$applications[$i]");
			(@aux)=readdir(DIR);
			@aux = sort @aux;
			closedir(DIR);

			$size_aux = @aux; 
			$cont_aux=0;
			$id=0;
						
			for ($j=0; $j<$size_aux; $j++) {	
					
				if ($aux[$j] =~ /[a-z]/ig and $aux[$j] =~ /\.c$/ig) {		# s\ufffd le osREAD APPLICATIONS INFO arquivos .c	
					
					$applications_Tasks[$i][$cont_aux]= $aux[$j];
					$applications_Tasks_id[$i][$cont_aux][0]= $id;			# insere o ID da tarefa
					$cont_aux++;
					$id++;
					$taskNumber++;
				}
			}
			($size_apps[$i])= $cont_aux;

			if ($max_app_size == 0 or $max_app_size < $cont_aux) {
				($max_app_size) = $cont_aux;
			}
			$appID++;
		}
		
		for ($i=0; $i<$numberAPPs; $i++) {
			($name_aux) = $applications[$i];
			$name_aux =~ s/\.c//ig;
			$name_aux2 = $name_aux.".cfg"; 
			
			open( TXT_FILE, "<$path_applications$applications[$i]/$name_aux2" ) or die("Could not open file $path_applications$applications[$i]/$name_aux2");
			@txt_lines_aux = <TXT_FILE>;
			$size_txt = @txt_lines_aux;
			close(TXT_FILE);

			for ($j=0; $j<$size_apps[$i]; $j++) {
					$name_task= $applications_Tasks[$i][$j];
					$name_task =~ s/\.c//ig;

					for($t=0; $t<$size_txt; $t++){

						$txt_lines_aux[$t] =~ s/\n//ig;
						if(($txt_lines_aux[$t] eq $name_task) && ($txt_lines_aux[$t-1] eq "<task>")){
							$txt_lines_aux[$t+2] =~ s/\n//ig;

							$load_Tasks[$i][$j]= $txt_lines_aux[$t+2]/100;
							$cont=0;
							$cont2=0;
							$txt_lines_aux[$t+4+$cont] =~ s/\n//ig;
							while($txt_lines_aux[$t+4+$cont] ne "<end task>"){
								for($g=0; $g<$size_apps[$i]; $g++){
									($name_aux3) = $applications_Tasks[$i][$g];
									$name_aux3 =~ s/\.c//ig;
									if($txt_lines_aux[$t+4+$cont] eq $name_aux3){
										$aux = $txt_lines_aux[$t+4+$cont+1];
										$depTasks_txt[$i][$j][$cont2] = $applications_Tasks_id[$i][$g][0];
										$aux =~ s/\n//ig;
										$depTasks_txt_load[$i][$j][$cont2][0] = $aux;
										$cont=$cont+2;

										$cont2++;

										last;
									}
								}
								$txt_lines_aux[$t+4+$cont] =~ s/\n//ig;
							}
						}
					}
					
				}
			}
	}
	else{
		$max_app_size = 0;
		$appID        = 0;
		$taskID   	  = 0;

		for($i=0; $i<$numberAPPs; $i++){
			system("mkdir ./$projectName/applications/$applications[$i] 2> /dev/null");
			
			if (-d $applications[$i]) {
				system("cp -rf $applications[$i]/*.c ./$projectName/applications/$applications[$i] 2> /dev/null");
				system("cp -rf $applications[$i]/*.h ./$projectName/applications/$applications[$i] 2> /dev/null");
				system("cp -rf $applications[$i]/*.cfg ./$projectName/applications/$applications[$i] 2> /dev/null");		
			} 
			else {	
				system("cp -rf \$HEMPS_PATH/applications/$applications[$i]/*.c ./$projectName/applications/$applications[$i] 2> /dev/null");
				system("cp -rf \$HEMPS_PATH/applications/$applications[$i]/*.h ./$projectName/applications/$applications[$i] 2> /dev/null");
				system("cp -rf \$HEMPS_PATH/applications/$applications[$i]/*.cfg ./$projectName/applications/$applications[$i] 2> /dev/null");
			}
			
			opendir(DIR, "./$projectName/applications/$applications[$i]");			
			(@aux)=readdir(DIR);
			@aux = sort @aux;
			closedir(DIR);

			$size_aux = @aux; 

			$cont_aux=0;
			$id=0;
			for($j=0; $j<$size_aux; $j++){
				if($aux[$j] =~ /[a-z]/ig and $aux[$j] =~ /\.c$/ig){				# s\ufffd le os arquivos .c

					$applications_Tasks[$i][$cont_aux]= $aux[$j];
					$applications_Tasks_id[$i][$cont_aux][0]= $id;				# insere o ID da tarefa
					
					$aux[$j]=NULL;
					$cont_aux++;
					$id++;
					$taskNumber++;
				}
			}
			($size_apps[$i])= $cont_aux;
			
			if($max_app_size == 0 or $max_app_size < $cont_aux){
				($max_app_size) = $cont_aux;
			}

			$appID++;
		}
	}
}

#################################################################################################
################################## CREATE CLUSTERS ##############################################
#################################################################################################

sub create_clusters{
	
	my $cluster_grid_x = $x_dimensions / $x_cluster;
	my $cluster_grid_y = $y_dimensions / $y_cluster;	
	
	my $cont = 0;
	$size_clusters = 0;
	
	$localMastersCont = ($x_dimensions * $y_dimensions) / ($x_cluster * $y_cluster);
	
	for($y=0; $y<$cluster_grid_y; $y++){
		for($x=0; $x<$cluster_grid_x; $x++){
		
			$clusters[$cont][0] = $x * $x_cluster;				# LEFTBOTTOM X
			$clusters[$cont][1] = $y * $y_cluster;				# LEFTBOTTOM Y
			$clusters[$cont][2] = (($x+1) * $x_cluster)-1;		# TOPRIGHT X
			$clusters[$cont][3] = (($y+1) * $y_cluster)-1;		# TOPRIGHT y
			
			if($mastersLocation =~ /LB/i){						# LB
				$clusters[$cont][4] = $x * $x_cluster;			# MASTER X
				$clusters[$cont][5] = $y * $y_cluster;			# MASTER Y
			}
			
			elsif($mastersLocation =~ /RB/i){					# RB
				$clusters[$cont][4] = (($x+1) * $x_cluster)-1;	# MASTER X
				$clusters[$cont][5] = $y * $y_cluster;			# MASTER Y
			}
			
			elsif($mastersLocation =~ /LT/i){					# LT
				$clusters[$cont][4] = $x * $x_cluster;			# MASTER X
				$clusters[$cont][5] = (($y+1) * $y_cluster)-1;	# MASTER Y
			}
			
			elsif($mastersLocation =~ /RT/i){					# RT
				$clusters[$cont][4] = (($x+1) * $x_cluster)-1;	# MASTER X
				$clusters[$cont][5] = (($y+1) * $y_cluster)-1;	# MASTER Y		
			}
			else {
				print "\nERROR: INVALID MASTER LOCATION\n\n";
				exit;
			}
			
			$cont++;
			$size_clusters++;
		}
	}
}

#################################################################################################
################################## SET PROCESSORS TYPE ##########################################
#################################################################################################

sub set_processors_type{
	
	$kernelTypesNum = "";
	$kernelTypes = "";
	
	for($i=0; $i<$size_clusters; $i++){

		if($i == $masterCluster){
			$processors[$clusters[$i][4]][$clusters[$i][5]] = "GMP";

			$x_master = $clusters[$i][4];
			$y_master = $clusters[$i][5];

			$x_master_h= sprintf("%x", $x_master);
			$y_master_h= sprintf("%x", $y_master);
			$masterAddress = $y_master * $x_dimensions + $x_master;
		}
		
		else {
			$processors[$clusters[$i][4]][$clusters[$i][5]] = "LMP";
		}
	}
	
	for($x=0; $x<$x_dimensions; $x++){
		for($y=0; $y<$y_dimensions; $y++){
			if($processors[$x][$y] eq "GMP"){

				$kernelTypesNum = $kernelTypesNum . "2, ";
				$kernelTypes = $kernelTypes . "\"mas\",";
			}
			elsif($processors[$x][$y] eq "LMP"){
				$kernelTypesNum = $kernelTypesNum. "1, ";
				$kernelTypes = $kernelTypes. "\"loc\",";
			}
			else{
				$kernelTypesNum = $kernelTypesNum. "0, ";
				$kernelTypes = $kernelTypes. "\"sla\",";
			}
		}
	}
	
	#for($x=0; $x<$bus_dimensions; $x++){
	#	$kernelTypesNum = $kernelTypesNum. "0, ";
	#	$kernelTypes = $kernelTypes. "\"sla\",";
	#}
}

#################################################################################################
################################## CREATE PROJECT ###############################################
#################################################################################################

sub create_project{
	
	system("mkdir $projectName 2> /dev/null");
	system("mkdir $projectName/plasma_ram 2> /dev/null");
	system("mkdir $projectName/plasma_ram/sc 2> /dev/null");
	system("mkdir $projectName/plasma_ram/rtl 2> /dev/null");
	system("mkdir $projectName/build 2> /dev/null");
	system("mkdir $projectName/debug 2> /dev/null");
	system("mkdir $projectName/log 2> /dev/null");
	system("mkdir $projectName/applications 2> /dev/null");
	

}

#################################################################################################
################################## Generates platform.cfg and services.cfg ######################
######################################### to the debugger software ##############################
#################################################################################################
sub generate_debugger_files{

	
	open( C_FILE, ">./$projectName/debug/platform.cfg" );
		print C_FILE "router_addressing XY\n";
		print C_FILE "channel_number 1\n";
		print C_FILE "mpsoc_x $x_dimensions\n";
		print C_FILE "mpsoc_y $y_dimensions\n";
		print C_FILE "cluster_x $x_cluster\n";
		print C_FILE "cluster_y $y_cluster\n";
		print C_FILE "manager_position_x 0\n";
		print C_FILE "manager_position_y 0\n";
		print C_FILE "global_manager_cluster 0\n";
		print C_FILE "flit_size 32\n";
		print C_FILE "clock_period_ns 10\n";
		print C_FILE "BEGIN_task_name_relation\n";
	
	
		for($i=0; $i<$numberAPPs; $i++){
			
			for($j=0; $j<$size_apps[$i]; $j++){
				$name_aux = $applications_Tasks[$i][$j];
				$name_aux =~ s/\.c//ig;
				$id_temp = $i<<8 | $applications_Tasks_id[$i][$j][0];
				print C_FILE "$name_aux $id_temp\n";
			}
		}	
		print C_FILE "END_task_name_relation\n";

	close(C_FILE);

	open( C_FILE, ">./$projectName/debug/services.cfg" );
		print C_FILE "MESSAGE_REQUEST 10\n";
                    print C_FILE "MESSAGE_DELIVERY 20\n";
                    print C_FILE "TASK_ALLOCATION 40\n";
                    print C_FILE "TASK_ALLOCATED 50\n";
                    print C_FILE "TASK_REQUEST 60\n";
                    print C_FILE "TASK_TERMINATED 70\n";
                    print C_FILE "TASK_DEALLOCATED 80\n";
                    print C_FILE "LOAN_PROCESSOR_RELEASE 90\n";
                    print C_FILE "DEBUG_MESSAGE 100\n";
                    print C_FILE "LOCATION_REQUEST 120\n";
                    print C_FILE "NEW_TASK 130\n";
                    print C_FILE "APP_TERMINATED 140\n";
                    print C_FILE "NEW_APP 150\n";
                    print C_FILE "INITIALIZE_CLUSTER 160\n";
                    print C_FILE "INITIALIZE_SLAVE 170\n";
                    print C_FILE "TASK_TERMINATED_OTHER_CLUSTER 180\n";
                    print C_FILE "LOAN_PROCESSOR_REQUEST 190\n";
                    print C_FILE "LOAN_PROCESSOR_DELIVERY 200\n";
            		print C_FILE "TASK_MIGRATION 210\n";
					print C_FILE "MIGRATION_CODE 220\n";
					print C_FILE "MIGRATION_TCB 221\n";
					print C_FILE "MIGRATION_TASK_LOCATION 222\n";
					print C_FILE "MIGRATION_MSG_REQUEST 223\n";
					print C_FILE "MIGRATION_STACK 224\n";
					print C_FILE "MIGRATION_DATA_BSS 225\n";
					print C_FILE "UPDATE_TASK_LOCATION 230\n";
					print C_FILE "TASK_MIGRATED 235\n";
					print C_FILE "DFS_CHANGE 300\n";
            
            
                    print C_FILE "\n";
                    print C_FILE "\$TASK_ALLOCATION_SERVICE 40 221\n";
                    print C_FILE "\$TASK_TERMINATED_SERVICE 70 221";
		
	close(C_FILE);

	#system("mkdir ../hardware/router/sc/debug/ 2> error.txt");

}

#################################################################################################
################################## READ HMP FILE CONFIGURATION ##################################
#################################################################################################

sub read_hmp_file{

	open( HMP_FILE, "<$_[0]" ) or die("Could not open file $_[0].");
	my @hmp_lines_aux = <HMP_FILE>;
	close(HMP_FILE);
	my $size_hmp = @hmp_lines_aux;
	$j=0;
	$cont_app=0;
	$cont_app_old=$cont_app;
	$first_app=0;
	$pagesPerPe=0;
	$cont_static=0;
	$start_static=0;
	
	for($i=0;$i<$size_hmp;$i++){											# tira todas as linhas em branco
		$hmp_lines_aux[$i] =~ s/\n//ig; 									# retira "nova linha"
		$hmp_lines_aux[$i] =~ s/\s+/ /ig; 									# substitui multiplos espa\ufffdos por apenas um
		$hmp_lines_aux[$i] =~ s/^\s+//ig;

		if($hmp_lines_aux[$i] ne ''){
			($hmp_lines[$j])= $hmp_lines_aux[$i];
			$j++;
		}
	}
	my $size_hmp = @hmp_lines;

	for($i=0;$i<$size_hmp;$i++){											# le linha a linha do arquivo HMP
		($hmp_line) = $hmp_lines[$i];
		if($hmp_line =~ /\[.*\]/ || $start_static != 0){					# linhas com "[]"
			
			if($hmp_line =~ /project name/i){								# le o nome do projeto
				($projectName_aux) = $hmp_lines[$i+1];
				$start_static = 0;
				next;
			}

			if($hmp_line =~ /tasks per pe/i){								# le o numero de paginas por PE
				($pagesPerPe_aux) = $hmp_lines[$i+1];
				$start_static = 0;
				next;
			}
			
			if($hmp_line =~ /memory size/i){								# le o tamanho da mem\ufffdria de cada PE
				($memorySize_aux) = $hmp_lines[$i+1];
				$start_static = 0;
				next;
			}			
			if($hmp_line =~ /page size/i){									# le o tamanho da p\ufffdgina
				($pageSize_aux) = $hmp_lines[$i+1];
				$start_static = 0;
				next;
			}
			
			if($hmp_line =~ /processor description/i){						# le a descri\ufffd\ufffdo do processador
				($procDescription_aux) = $hmp_lines[$i+1];
				$start_static = 0;
				next;
			}
			if($hmp_line =~ /noc buffer size/ig){						# le o tamanho do buffer
				($NoC_buffer_size) = $hmp_lines[$i+1];
				$start_static = 0;
				next;
			}			
			if($hmp_line =~ /noc routing algorithm/ig){						# le o algoritmo de roteamento
				($NoC_routing_algorithm) = $hmp_lines[$i+1];
				$start_static = 0;
				next;
			}
			if($hmp_line =~ /mapping/ig){						# le o algoritmo de mapeamento
				($MPSOC_mapping) = $hmp_lines[$i+1];
				$start_static = 0;
				next;
			}
			
			if($hmp_line =~ /dimensions/i){									# le a dimensao do MPSoC
				($x_dimensions_aux) = $hmp_lines[$i+1];
				($y_dimensions_aux) = $hmp_lines[$i+2];
				$start_static = 0;
				next;
			}
			
			if($hmp_line =~ /cluster size/i){								# le o tamanho do cluster
				($x_cluster_aux) = $hmp_lines[$i+1];
				($y_cluster_aux) = $hmp_lines[$i+2];
				$start_static = 0;
				next;
			}
			
			if($hmp_line =~ /injectors/ig){						# le o algoritmo de mapeamento
				($injector) = $hmp_lines[$i+1];
				$start_static = 0;
				next;
			}
			
			if($hmp_line =~ /bus count/i){            # le a quantidade de barramentos na NoC
				($bus_count_aux) = $hmp_lines[$i+1];
				$start_static = 0;
				next;
			}
			
			if($hmp_line =~ /proc per bus/i){                         # le a quantidade de processadores por barramento
				for($k=0; $k<$bus_count_aux; $k++){	
					($proc_per_bus_aux[$k]) = $hmp_lines[$i+$k+1];
				}
				next;
			}
			
			if($hmp_line =~ /bus position/i){                # le a localizacao do barramento na NoC
				for($k=0; $k<$bus_count_aux; $k++){	
					($bus_position_aux[$k]) = $hmp_lines[$i+$k+1];
				}
				$start_static = 0;
				next;
			}
			
			if($hmp_line =~ /crossbar count/i){            # le a quantidade de crossbar na NoC
				($crossbar_count_aux) = $hmp_lines[$i+1];
				$start_static = 0;
				next;
			}
			
			if($hmp_line =~ /proc per crossbar/i){                         # le a quantidade de processadores por crossbar
				for($k=0; $k<$crossbar_count_aux; $k++){	
					($proc_per_crossbar_aux[$k]) = $hmp_lines[$i+$k+1];
				}
				next;
			}
			
			if($hmp_line =~ /crossbar position/i){                # le a localizacao da crossbar na NoC
				for($k=0; $k<$crossbar_count_aux; $k++){	
					($crossbar_position_aux[$k]) = $hmp_lines[$i+$k+1];
				}
				$start_static = 0;
				next;
			}
			
			if($hmp_line =~ /masters location/i){							# le a localizacao dos mestres (LB, RB, LT, RT);
				($mastersLocation_aux) = $hmp_lines[$i+1];
				$start_static = 0;
				next;
			}
			
			if($hmp_line =~ /master cluster/i){								# le em qual cluster ficara o mestre global
				$start_static = 0;
				($masterCluster_aux) = $hmp_lines[$i+1];
				next;
			}

			if(($hmp_line =~ /application/i && $hmp_line !~ /end/i) || ($hmp_line =~ /start time/i) || ($hmp_line =~ /static/i) || ($start_static ne 0)){	# le as aplica\ufffd\ufffdes
			
				if($hmp_line =~ /application/i || $hmp_line =~ /end/i || $hmp_line =~ /start time/i) {
					$start_static = 0;
				}
				if(($hmp_line =~ /static/i || $start_static ne 0)){							
					if($start_static > 1){
						$start_static--;
					}
					else{
						($static_app[$cont_app][$cont_static]) = $hmp_lines[$i+1];
						$cont_static++;
						($static_app[$cont_app][$cont_static]) = (($hmp_lines[$i+2]<<8)+$hmp_lines[$i+3]);
						$cont_static++;
						($static_app[$cont_app][$cont_static]) = -1;
						$start_static=3;
					}
				}
				else{
					if($hmp_line =~ /start time/i){
						$start_static = 0;
						($auxTime) = $hmp_lines[$i+1];
						if($auxTime =~ /fs/){									# femtosecond
							$auxTime =~ s/[a-z]//ig;
							$auxTime =~ s/\s//ig;
							$auxTime = $auxTime / 1000000000000;						
						}
						elsif($auxTime =~ /ps/){								# picosecond
							$auxTime =~ s/[a-z]//ig;
							$auxTime =~ s/\s//ig;
							$auxTime = $auxTime / 1000000000;
						}
						elsif($auxTime =~ /ns/){								# nanosecond
							$auxTime =~ s/[a-z]//ig;
							$auxTime =~ s/\s//ig;
							$auxTime = $auxTime / 1000000;
						}
						elsif($auxTime =~ /us/){								# microsecond
							$auxTime =~ s/[a-z]//ig;
							$auxTime =~ s/\s//ig;
							$auxTime = $auxTime / 1000;
						}
						elsif($auxTime =~ /ms/){								# millisecond
							$auxTime =~ s/[a-z]//ig;
							$auxTime =~ s/\s//ig;
						}
						elsif($auxTime =~ /cs/){								# centisecond
							$auxTime =~ s/[a-z]//ig;
							$auxTime =~ s/\s//ig;
							$auxTime = $auxTime * 10;
						}
						elsif($auxTime =~ /ds/){								# decisecond
							$auxTime =~ s/[a-z]//ig;
							$auxTime =~ s/\s//ig;
							$auxTime = $auxTime * 100;
						}
						elsif($auxTime =~ /s/){								    # second
							$auxTime =~ s/[a-z]//ig;
							$auxTime =~ s/\s//ig;
							$auxTime = $auxTime * 1000;
						}
						else{													# Default millisecond
							$auxTime =~ s/[a-z]//ig;
							$auxTime =~ s/\s//ig;
						}
						
						($StartTimeApp[$cont_app]) = $auxTime;

					}
					else{
						$start_static = 0;
						if($first_app == 0){
							($applications[$cont_app]) = $hmp_lines[$i+1];
							($StartTimeApp[$cont_app]) = 0;
							$first_app=1;
						}
						else{
							if($cont_app_old == $cont_app){
								$cont_app++;
							}
							($cont_app_old) = $cont_app;

							($applications[$cont_app]) = $hmp_lines[$i+1];
							($StartTimeApp[$cont_app]) = 0;
							($static_app[$cont_app][0]) = -1;

						}
					}
					next;
				}
			}
		}
	}

	use Math::Complex;

	$HOP_NUMBER_DEFINE = sqrt($x_cluster_aux*$y_cluster_aux)/2;

	use POSIX;
	$HOP_NUMBER_DEFINE = floor($HOP_NUMBER_DEFINE);

	#print "gui gui gui $HOP_NUMBER_DEFINE\n\n\n";

	return $projectName_aux, $pagesPerPe_aux, $memorySize_aux, $pageSize_aux, $procDescription_aux,
	       $x_dimensions_aux, $y_dimensions_aux, $x_cluster_aux, $y_cluster_aux, $injector,
		   $bus_count_aux, \@proc_per_bus_aux, \@bus_position_aux,
		   $crossbar_count_aux, \@proc_per_crossbar_aux, \@crossbar_position_aux,
		   $mastersLocation_aux, $masterCluster_aux;
}
