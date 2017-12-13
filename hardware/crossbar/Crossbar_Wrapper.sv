import HeMPS_defaults::*;

module Crossbar_Wrapper #(
	parameter[15:0] router_address = 16'h0000)
(
  input clock,
  input reset,
  input [4:0] rx,
  input [4:0] clock_rx,
  input [4:0] credit_i,
  input regflit[4:0] data_in,
  output [4:0] tx,
  output [4:0] clock_tx,
  output [4:0] credit_o,
  output regflit[4:0] data_out,
  // Crossbar 
  input rx_c,
  input credit_i_c,
  input regflit data_in_c,
  output tx_c,
  output regflit tx_addr_c,
  output credit_o_c,
  output regflit data_out_c,
  // Crossbar Arbiter Interface
  input grant,
  output request
);

  wire regflit tx_addr_fake;
  wire tx_change_flit;

  // Bridge to NoC
  RouterCC#(
    .address(router_address)
  ) Rx(
    .clock(clock),
    .reset(reset),
    .clock_tx(clock_tx),
    .clock_rx(clock_rx),
    .tx(tx),
    .rx(rx),
    .data_in(data_in),
    .data_out(data_out),
    .credit_i(credit_i),
    .credit_o(credit_o)
  );

  // Bridge to Crossbar
  Crossbar_bridge Noc_BBRR(
    .clock(clock),
    .reset(reset),
    // Router X 
    .rx(tx[4]),
    .data_in(data_out[4]),
    .credit_o(credit_i[4]),
    // Crossbar
    .data_out(data_out_c),
    .credit_i(credit_i_c),
    .tx(tx_c),
    .tx_addr(tx_addr_fake), //out
	.tx_change_flit(tx_change_flit),
    .grant(grant),
    .request(request)
  );

  always @ (posedge tx[4]) begin
    data_out[4][15:0] = data_out[4][31:16];
    data_out[4][31:16] = 16'h00;
    tx_addr_c = data_out[4];
    @(posedge clock);
  end

  assign rx[4]        = rx_c;
  assign data_in[4]   = data_in_c;
  assign clock_rx[4]  = clock;
  assign credit_o_c   = credit_o[4];
  
endmodule: Crossbar_Wrapper
