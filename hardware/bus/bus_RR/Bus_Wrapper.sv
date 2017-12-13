import HeMPS_defaults::*;

module Bus_Wrapper #(
	parameter[15:0] router_address = 16'h0000)
(
	input clock,
	input reset,
	input [4:0] rx,
	input [4:0] clock_rx,
	input [4:0] credit_i,
	input regflit [4:0] data_in,
	output [4:0] tx,
	output [4:0] clock_tx,
	output [4:0] credit_o,
	output regflit [4:0] data_out,
	//Bus
	input rx_b,
	input credit_i_b,
	input regflit data_in_b,
	output tx_b,
	output regflit tx_addr_b,
	output credit_o_b,
	output regflit data_out_b,
	//Bus Arbiter Interface
	output ack,
	input grant,
	output request,
	output using_bus
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

 // Bridge to Bus
 Bus_BridgeRR NoC_BBRR(
	.clock(clock),
	.reset(reset),
	// Router X
	.rx(tx[4]),
	.data_in(data_out[4]),
	.credit_o(credit_i[4]),
	// bus
	.data_out(data_out_b),
	.credit_i(credit_i_b),
	.tx(tx_b),
	.tx_addr(tx_addr_fake),
	 // Arbiter
	.ack(ack),
	.grant(grant),
	.request(request),
	.using_bus(using_bus),
	.tx_change_flit(tx_change_flit)
 );

 always @ (posedge tx[4]) begin
	data_out[4][15:0] = data_out[4][31:16];
	data_out[4][31:16] = 16'h00;
	tx_addr_b = data_out[4];
	@(posedge clock);
 end

 assign rx[4]        = rx_b;
 assign data_in[4]   = data_in_b;
 assign clock_rx[4]  = clock;
 assign credit_o_b   = credit_o[4];

endmodule: Bus_Wrapper
