module hemps_hybrid_tb_HH_comm();

import memory_pack::*;
import HeMPS_defaults::*;

  // Oscillator generation  12MHz
  reg clock;
  reg clock_200;
  reg reset;

  // in reg out wire
  reg[29:0] control_hemps_addr;
  reg[31:0] control_hemps_data;
  //reg[29:0] control_hemps_addrb;
  //reg[31:0] control_hemps_datab;
  
  // debug
  logic control_write_enable_debug;
  logic [31:0]control_data_out_debug;
  logic control_busy_debug;

  logic ack_app;
  logic [31:0] req_app;
  integer y;

   // Slave 1
  integer r3;
  regflit teste,teste2;
  logic clockrx, clocktx, credit, rx;
  logic [31:0]log1;
  logic log2, log3, log4; 
  logic [31:0]log5;
  localparam NUMBERPENOC=20;
  int x;
  
  logic   [19:0] rx_plasmas_noc;
  logic   [19:0] tx_plasmas_noc;
  regflit [19:0] data_in_plasmas_noc;
  regflit [19:0] data_out_plasmas_noc;

  initial begin
    clock =  1'b0;
    clock_200 =  1'b1;
    reset = 1'b0;
    reset = #5 1'b1;
    reset = #100ns 1'b0;
    //$display("tchwe",memory[0]);
    //control_busy_debug = 1'b0;
    rx_plasmas_noc[0]      = 1'h0;
	  tx_plasmas_noc[0]      = 10'h0;
	  data_in_plasmas_noc[0] = 32'h0;
	  data_out_plasmas_noc[0]= 32'h0;
  end

    // Analog Model instance
  HeMPS hemps_inst(
    .clock (clock),
    .reset (reset),
    //repository
    .mem_addr            (control_hemps_addr),
    .data_read           (control_hemps_data),
    //debug
    .write_enable_debug  (control_write_enable_debug),
    .data_out_debug      (control_data_out_debug),
    .busy_debug          (control_busy_debug),
    .ack_app             (ack_app),
    .req_app             (req_app)
  );

  Hybrid_top hemps_hybrid_inst(
    .clock(clock),
    .reset(reset)
  );

  log_tb LOG_HeMPS(
    .reset(reset),
    .control_data_out_debug(control_data_out_debug),
    .control_write_enable_debug(control_write_enable_debug),
    .busy_debug(control_busy_debug),
    .ack_app(ack_app),
    .req_app(req_app)
  );
  
  log_h_tb LOG_HeMPS_Hybrid(
    .reset(reset),
    .control_data_out_debug(hemps_hybrid_tb_HH_comm.hemps_hybrid_inst.if_m.dod),
    .control_write_enable_debug(hemps_hybrid_tb_HH_comm.hemps_hybrid_inst.if_m.wed),
    .busy_debug(hemps_hybrid_tb_HH_comm.hemps_hybrid_inst.if_m.bd),
    .ack_app(hemps_hybrid_tb_HH_comm.hemps_hybrid_inst.if_m.aa),
    .req_app(hemps_hybrid_tb_HH_comm.hemps_hybrid_inst.if_m.ra)
  );

  logs_plasma_s_noc #(NUMBERPENOC) Log_Plasmas_noc (
    .rel(clock), 
    .reset(reset),   
    .rx_p(rx_plasmas_noc),
    .tx_p(tx_plasmas_noc),
    .data_in_p(data_in_plasmas_noc),
    .data_out_p(data_out_plasmas_noc)
  );

  always @ (reset, posedge clock) begin
    //$display("Always ",$time);     
    if (reset) begin
     control_hemps_data = memory[0];          
     @control_hemps_addr;
    end
    else begin
      //control_hemps_data = memory[x]; 
      //$display("addr %h",control_hemps_addr," Interacao:%d",x,$time);     
      @control_hemps_addr;  
      y=control_hemps_addr[23:2];     
      control_hemps_data = memory[y];      
      //$display("data[%d] %h",x,control_hemps_data," Interacao:%d",x,$time);         
    end
  end

  // Hybrid
   always @ (posedge reset, posedge clock) begin
    if (reset) begin
     hemps_hybrid_tb_HH_comm.hemps_hybrid_inst.if_m.dr = memory[0]; 
     @hemps_hybrid_tb_HH_comm.hemps_hybrid_inst.if_m.address;
    end
    else begin
      @hemps_hybrid_tb_HH_comm.hemps_hybrid_inst.if_m.address;
      y=hemps_hybrid_tb_HH_comm.hemps_hybrid_inst.if_m.address[23:2];     
      hemps_hybrid_tb_HH_comm.hemps_hybrid_inst.if_m.dr = memory[y]; 
    end
  end


  // 100 MHz
  always #5ns clock = ~clock;
  // 200 MHz
  always #1.25ns clock_200 = ~clock_200;
    
  always @ ( posedge clock) begin    
    rx_plasmas_noc[1]      = hemps_hybrid_tb_HH_comm.hemps_inst.proc[1].slav.slave.PE_PLASMA.plasma.rx;
    tx_plasmas_noc[1]      = hemps_hybrid_tb_HH_comm.hemps_inst.proc[1].slav.slave.PE_PLASMA.plasma.tx;
    data_in_plasmas_noc[1] = hemps_hybrid_tb_HH_comm.hemps_inst.proc[1].slav.slave.PE_PLASMA.plasma.data_in;
    data_out_plasmas_noc[1]= hemps_hybrid_tb_HH_comm.hemps_inst.proc[1].slav.slave.PE_PLASMA.plasma.data_out;
    rx_plasmas_noc[2]      = hemps_hybrid_tb_HH_comm.hemps_inst.proc[2].slav.slave.PE_PLASMA.plasma.rx;
    tx_plasmas_noc[2]      = hemps_hybrid_tb_HH_comm.hemps_inst.proc[2].slav.slave.PE_PLASMA.plasma.tx;
    data_in_plasmas_noc[2] = hemps_hybrid_tb_HH_comm.hemps_inst.proc[2].slav.slave.PE_PLASMA.plasma.data_in;
    data_out_plasmas_noc[2]= hemps_hybrid_tb_HH_comm.hemps_inst.proc[2].slav.slave.PE_PLASMA.plasma.data_out;
    rx_plasmas_noc[3]      = hemps_hybrid_tb_HH_comm.hemps_inst.proc[3].slav.slave.PE_PLASMA.plasma.rx;
    tx_plasmas_noc[3]      = hemps_hybrid_tb_HH_comm.hemps_inst.proc[3].slav.slave.PE_PLASMA.plasma.tx;
    data_in_plasmas_noc[3] = hemps_hybrid_tb_HH_comm.hemps_inst.proc[3].slav.slave.PE_PLASMA.plasma.data_in;
    data_out_plasmas_noc[3]= hemps_hybrid_tb_HH_comm.hemps_inst.proc[3].slav.slave.PE_PLASMA.plasma.data_out;
    rx_plasmas_noc[4]      = hemps_hybrid_tb_HH_comm.hemps_inst.proc[4].slav.slave.PE_PLASMA.plasma.rx;
    tx_plasmas_noc[4]      = hemps_hybrid_tb_HH_comm.hemps_inst.proc[4].slav.slave.PE_PLASMA.plasma.tx;
    data_in_plasmas_noc[4] = hemps_hybrid_tb_HH_comm.hemps_inst.proc[4].slav.slave.PE_PLASMA.plasma.data_in;
    data_out_plasmas_noc[4]= hemps_hybrid_tb_HH_comm.hemps_inst.proc[4].slav.slave.PE_PLASMA.plasma.data_out;
    rx_plasmas_noc[5]      = hemps_hybrid_tb_HH_comm.hemps_inst.proc[5].slav.slave.PE_PLASMA.plasma.rx;
    tx_plasmas_noc[5]      = hemps_hybrid_tb_HH_comm.hemps_inst.proc[5].slav.slave.PE_PLASMA.plasma.tx;
    data_in_plasmas_noc[5] = hemps_hybrid_tb_HH_comm.hemps_inst.proc[5].slav.slave.PE_PLASMA.plasma.data_in;
    data_out_plasmas_noc[5]= hemps_hybrid_tb_HH_comm.hemps_inst.proc[5].slav.slave.PE_PLASMA.plasma.data_out;
    rx_plasmas_noc[6]      = hemps_hybrid_tb_HH_comm.hemps_inst.proc[6].slav.slave.PE_PLASMA.plasma.rx;
    tx_plasmas_noc[6]      = hemps_hybrid_tb_HH_comm.hemps_inst.proc[6].slav.slave.PE_PLASMA.plasma.tx;
    data_in_plasmas_noc[6] = hemps_hybrid_tb_HH_comm.hemps_inst.proc[6].slav.slave.PE_PLASMA.plasma.data_in;
    data_out_plasmas_noc[6]= hemps_hybrid_tb_HH_comm.hemps_inst.proc[6].slav.slave.PE_PLASMA.plasma.data_out;
    rx_plasmas_noc[7]      = hemps_hybrid_tb_HH_comm.hemps_inst.proc[7].slav.slave.PE_PLASMA.plasma.rx;
    tx_plasmas_noc[7]      = hemps_hybrid_tb_HH_comm.hemps_inst.proc[7].slav.slave.PE_PLASMA.plasma.tx;
    data_in_plasmas_noc[7] = hemps_hybrid_tb_HH_comm.hemps_inst.proc[7].slav.slave.PE_PLASMA.plasma.data_in;
    data_out_plasmas_noc[7]= hemps_hybrid_tb_HH_comm.hemps_inst.proc[7].slav.slave.PE_PLASMA.plasma.data_out;
    rx_plasmas_noc[8]      = hemps_hybrid_tb_HH_comm.hemps_inst.proc[8].slav.slave.PE_PLASMA.plasma.rx;
    tx_plasmas_noc[8]      = hemps_hybrid_tb_HH_comm.hemps_inst.proc[8].slav.slave.PE_PLASMA.plasma.tx;
    data_in_plasmas_noc[8] = hemps_hybrid_tb_HH_comm.hemps_inst.proc[8].slav.slave.PE_PLASMA.plasma.data_in;
    data_out_plasmas_noc[8]= hemps_hybrid_tb_HH_comm.hemps_inst.proc[8].slav.slave.PE_PLASMA.plasma.data_out;
    rx_plasmas_noc[9]      = hemps_hybrid_tb_HH_comm.hemps_inst.proc[9].slav.slave.PE_PLASMA.plasma.rx;
    tx_plasmas_noc[9]      = hemps_hybrid_tb_HH_comm.hemps_inst.proc[9].slav.slave.PE_PLASMA.plasma.tx;
    data_in_plasmas_noc[9] = hemps_hybrid_tb_HH_comm.hemps_inst.proc[9].slav.slave.PE_PLASMA.plasma.data_in;
    data_out_plasmas_noc[9]= hemps_hybrid_tb_HH_comm.hemps_inst.proc[9].slav.slave.PE_PLASMA.plasma.data_out;    
    rx_plasmas_noc[10]      = hemps_hybrid_tb_HH_comm.hemps_inst.proc[10].slav.slave.PE_PLASMA.plasma.rx;
    tx_plasmas_noc[10]      = hemps_hybrid_tb_HH_comm.hemps_inst.proc[10].slav.slave.PE_PLASMA.plasma.tx;
    data_in_plasmas_noc[10] = hemps_hybrid_tb_HH_comm.hemps_inst.proc[10].slav.slave.PE_PLASMA.plasma.data_in;
    data_out_plasmas_noc[10]= hemps_hybrid_tb_HH_comm.hemps_inst.proc[10].slav.slave.PE_PLASMA.plasma.data_out;
    rx_plasmas_noc[11]      = hemps_hybrid_tb_HH_comm.hemps_inst.proc[11].slav.slave.PE_PLASMA.plasma.rx;
    tx_plasmas_noc[11]      = hemps_hybrid_tb_HH_comm.hemps_inst.proc[11].slav.slave.PE_PLASMA.plasma.tx;
    data_in_plasmas_noc[11] = hemps_hybrid_tb_HH_comm.hemps_inst.proc[11].slav.slave.PE_PLASMA.plasma.data_in;
    data_out_plasmas_noc[11]= hemps_hybrid_tb_HH_comm.hemps_inst.proc[11].slav.slave.PE_PLASMA.plasma.data_out;
    rx_plasmas_noc[12]      = hemps_hybrid_tb_HH_comm.hemps_inst.proc[12].slav.slave.PE_PLASMA.plasma.rx;
    tx_plasmas_noc[12]      = hemps_hybrid_tb_HH_comm.hemps_inst.proc[12].slav.slave.PE_PLASMA.plasma.tx;
    data_in_plasmas_noc[12] = hemps_hybrid_tb_HH_comm.hemps_inst.proc[12].slav.slave.PE_PLASMA.plasma.data_in;
    data_out_plasmas_noc[12]= hemps_hybrid_tb_HH_comm.hemps_inst.proc[12].slav.slave.PE_PLASMA.plasma.data_out;
    rx_plasmas_noc[13]      = hemps_hybrid_tb_HH_comm.hemps_inst.proc[13].slav.slave.PE_PLASMA.plasma.rx;
    tx_plasmas_noc[13]      = hemps_hybrid_tb_HH_comm.hemps_inst.proc[13].slav.slave.PE_PLASMA.plasma.tx;
    data_in_plasmas_noc[13] = hemps_hybrid_tb_HH_comm.hemps_inst.proc[13].slav.slave.PE_PLASMA.plasma.data_in;
    data_out_plasmas_noc[13]= hemps_hybrid_tb_HH_comm.hemps_inst.proc[13].slav.slave.PE_PLASMA.plasma.data_out;
    rx_plasmas_noc[14]      = hemps_hybrid_tb_HH_comm.hemps_inst.proc[14].slav.slave.PE_PLASMA.plasma.rx;
    tx_plasmas_noc[14]      = hemps_hybrid_tb_HH_comm.hemps_inst.proc[14].slav.slave.PE_PLASMA.plasma.tx;
    data_in_plasmas_noc[14] = hemps_hybrid_tb_HH_comm.hemps_inst.proc[14].slav.slave.PE_PLASMA.plasma.data_in;
    data_out_plasmas_noc[14]= hemps_hybrid_tb_HH_comm.hemps_inst.proc[14].slav.slave.PE_PLASMA.plasma.data_out;
    rx_plasmas_noc[15]      = hemps_hybrid_tb_HH_comm.hemps_inst.proc[15].slav.slave.PE_PLASMA.plasma.rx;
    tx_plasmas_noc[15]      = hemps_hybrid_tb_HH_comm.hemps_inst.proc[15].slav.slave.PE_PLASMA.plasma.tx;
    data_in_plasmas_noc[15] = hemps_hybrid_tb_HH_comm.hemps_inst.proc[15].slav.slave.PE_PLASMA.plasma.data_in;
    data_out_plasmas_noc[15]= hemps_hybrid_tb_HH_comm.hemps_inst.proc[15].slav.slave.PE_PLASMA.plasma.data_out;
    rx_plasmas_noc[16]      = hemps_hybrid_tb_HH_comm.hemps_inst.proc[16].slav.slave.PE_PLASMA.plasma.rx;
    tx_plasmas_noc[16]      = hemps_hybrid_tb_HH_comm.hemps_inst.proc[16].slav.slave.PE_PLASMA.plasma.tx;
    data_in_plasmas_noc[16] = hemps_hybrid_tb_HH_comm.hemps_inst.proc[16].slav.slave.PE_PLASMA.plasma.data_in;
    data_out_plasmas_noc[16]= hemps_hybrid_tb_HH_comm.hemps_inst.proc[16].slav.slave.PE_PLASMA.plasma.data_out;
    rx_plasmas_noc[17]      = hemps_hybrid_tb_HH_comm.hemps_inst.proc[17].slav.slave.PE_PLASMA.plasma.rx;
    tx_plasmas_noc[17]      = hemps_hybrid_tb_HH_comm.hemps_inst.proc[17].slav.slave.PE_PLASMA.plasma.tx;
    data_in_plasmas_noc[17] = hemps_hybrid_tb_HH_comm.hemps_inst.proc[17].slav.slave.PE_PLASMA.plasma.data_in;
    data_out_plasmas_noc[17]= hemps_hybrid_tb_HH_comm.hemps_inst.proc[17].slav.slave.PE_PLASMA.plasma.data_out;
    rx_plasmas_noc[18]      = hemps_hybrid_tb_HH_comm.hemps_inst.proc[18].slav.slave.PE_PLASMA.plasma.rx;
    tx_plasmas_noc[18]      = hemps_hybrid_tb_HH_comm.hemps_inst.proc[18].slav.slave.PE_PLASMA.plasma.tx;
    data_in_plasmas_noc[18] = hemps_hybrid_tb_HH_comm.hemps_inst.proc[18].slav.slave.PE_PLASMA.plasma.data_in;
    data_out_plasmas_noc[18]= hemps_hybrid_tb_HH_comm.hemps_inst.proc[18].slav.slave.PE_PLASMA.plasma.data_out;
    rx_plasmas_noc[19]      = hemps_hybrid_tb_HH_comm.hemps_inst.proc[19].slav.slave.PE_PLASMA.plasma.rx;
    tx_plasmas_noc[19]      = hemps_hybrid_tb_HH_comm.hemps_inst.proc[19].slav.slave.PE_PLASMA.plasma.tx;
    data_in_plasmas_noc[19] = hemps_hybrid_tb_HH_comm.hemps_inst.proc[19].slav.slave.PE_PLASMA.plasma.data_in;
    data_out_plasmas_noc[19]= hemps_hybrid_tb_HH_comm.hemps_inst.proc[19].slav.slave.PE_PLASMA.plasma.data_out;	 
  end



//  assign hemps_hybrid_tb_HH_comm.hemps_hybrid_inst.if_m.rar = control_hemps_data;
  //assign hemps_hybrid_tb_HH_comm.hemps_hybrid_inst.if_m.ra = req_app;
  

endmodule: hemps_hybrid_tb_HH_comm



