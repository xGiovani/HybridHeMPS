//------------------------------------------------------------------------------------------------
//
//  DISTRIBUTED HEMPS  - version 5.0
//
//  Research group: GAPH-PUCRS    -    contact   fernando.moraes@pucrs.br
//
//  Distribution:  September 2013
//
//  Source name:  plasma_slave.h
//
//  Brief description:  This source manipulates the signals of module plasma_slave
//
//------------------------------------------------------------------------------------------------
/***
*	Plasma
***/
#ifndef _plasma_h
#define _plasma_h

#include "systemc.h"

#include "../../plasma/sc/mlite_cpu.h"
#include <packet.h>
#include <router_cc.h>

#include <ram_plasma.h>
#include <ram_master.h>

#include "../../dmni/sc/dmni.h"

// Memory map constants.
#define DEBUG 0x20000000
#define IRQ_MASK 0x20000010
#define IRQ_STATUS_ADDR 0x20000020
#define TIME_SLICE_ADDR 0x20000060
#define CLOCK_HOLD 0x20000090
#define END_SIM 0x20000080
#define NET_ADDRESS 0x20000140

// DMA mapping.
#define DMA_SIZE 0x20000200
#define DMA_ADDR 0x20000210
#define DMA_SIZE_2 0x20000205
#define DMA_ADDR_2 0x20000215
#define DMA_OP 0x20000220
#define START_DMA 0x20000230
#define DMA_ACK 0x20000240
#define DMA_SEND_ACTIVE 0x20000250
#define DMA_RECEIVE_ACTIVE	0x20000260
#define SCHEDULING_REPORT	0x20000270
#define TICK_COUNTER_ADDR 0x20000300
#define REQ_APP_REG 0x20000350
#define ACK_APP_REG 0x20000360

//Kernel pending service FIFO
#define PENDING_SERVICE_INTR	0x20000400

SC_MODULE(plasma) {
	
	sc_in< bool >		clock;
	sc_in< bool >		reset;
	sc_signal < bool > 	clock_hold;
	bool 				clock_aux;

	// NoC Interface
	sc_out<bool >		clock_tx[NPORT-1];
	sc_out<bool >		tx[NPORT-1];
	sc_out<regflit >	data_out[NPORT-1];
	sc_in<bool >		credit_i[NPORT-1];
	
	sc_in<bool >		clock_rx[NPORT-1];
	sc_in<bool > 		rx[NPORT-1];
	sc_in<regflit >		data_in[NPORT-1];
	sc_out<bool >		credit_o[NPORT-1];
	
	//Dynamic Insertion of Applications
	sc_out<bool >				ack_app;
	sc_in<sc_uint<32> >			req_app;

	// External Memory
	sc_out< sc_uint<30> >		address;
	sc_in< sc_uint<32> > 		data_read;

	//signals
	sc_signal < sc_uint <32 > > cpu_mem_address_reg;
	sc_signal < sc_uint <32 > > cpu_mem_data_write_reg;
	sc_signal < sc_uint <4 > > 	cpu_mem_write_byte_enable_reg;
	sc_signal < sc_uint <8 > > 	irq_mask_reg;
	sc_signal < sc_uint <8 > > 	irq_status;
	sc_signal < bool > 			irq;
	sc_signal < sc_uint <32 > > time_slice;
	sc_signal < bool > 			write_enable;
	sc_signal < sc_uint <32 > > tick_counter_local;
	sc_signal < sc_uint <32 > > tick_counter;
	sc_signal < sc_uint <8 > > 	current_page;
	//cpu
	sc_signal < sc_uint <32 > > cpu_mem_address;
	sc_signal < sc_uint <32 > > cpu_mem_data_write;
	sc_signal < sc_uint <32 > > cpu_mem_data_read;
	sc_signal < sc_uint <4 > > 	cpu_mem_write_byte_enable;
	sc_signal < bool > 			cpu_mem_pause;
	sc_signal < bool > 			cpu_enable_ram;
	sc_signal < bool > 			cpu_set_size;
	sc_signal < bool > 			cpu_set_address;
	sc_signal < bool > 			cpu_set_size_2;
	sc_signal < bool > 			cpu_set_address_2;
	sc_signal < bool > 			cpu_set_op;
	sc_signal < bool > 			cpu_start;
	sc_signal < bool > 			cpu_ack;

	//ram
	sc_signal < sc_uint <32 > > data_read_ram;
	sc_signal < sc_uint <32 > > mem_data_read;
	//network interface
	sc_signal < bool > 			ni_intr;
	// NoC Interface
	sc_signal< bool > 			clock_tx_ni;
	sc_signal< bool > 			tx_ni;
	sc_signal< regflit > 		data_out_ni;
	sc_signal< bool > 			credit_i_ni;
	sc_signal< bool > 			clock_rx_ni;
	sc_signal< bool > 			rx_ni;
	sc_signal< regflit > 		data_in_ni;
	sc_signal< bool > 			credit_o_ni;
	//dmni
	sc_signal < sc_uint <32 > > dmni_mem_address;
	sc_signal < sc_uint <32 > > dmni_mem_addr_ddr;
	sc_signal < bool > 			dmni_mem_ddr_read_req;
	sc_signal < bool > 			mem_ddr_access;
	sc_signal < sc_uint <4 > > 	dmni_mem_write_byte_enable;
	sc_signal < sc_uint <32 > > dmni_mem_data_write;
	sc_signal < sc_uint <32 > > dmni_mem_data_read;
	sc_signal < sc_uint <32 > > dmni_data_read;
	sc_signal < bool > 			dmni_enable_internal_ram;
	sc_signal < bool > 			dmni_send_active_sig;
	sc_signal < bool > 			dmni_receive_active_sig;
	sc_signal < sc_uint <30 > > address_mux;
	sc_signal < sc_uint <32 > > cpu_mem_address_reg2;
	sc_signal < sc_uint <30 > > addr_a;
	sc_signal < sc_uint <30 > > addr_b;
	sc_signal <	bool> 			cpu_repo_acess;
	//pending service signal
	sc_signal < bool > 			pending_service;
	//router signals
	//not reset for router 
	sc_signal < bool > reset_n;

	sc_signal < sc_uint <32 > > end_sim_reg;

	enum repo_state				{WAIT, COPY_FROM_REP};
	sc_signal<repo_state >		repo_FSM;


	unsigned char shift_mem_page;

	mlite_cpu *cpu;
	ram_master *ram_mas;
	ram_plasma *ram_sla;
	dmni *dm_ni;
	router_cc *router;


	unsigned long int log_interaction;
	unsigned long int instant_instructions;
	unsigned long int aux_instant_instructions;
	
	unsigned long int logical_instant_instructions;
	unsigned long int jump_instant_instructions;
	unsigned long int branch_instant_instructions;
	unsigned long int move_instant_instructions;
	unsigned long int other_instant_instructions;
	unsigned long int arith_instant_instructions;
	unsigned long int load_instant_instructions;
	unsigned long int shift_instant_instructions;
	unsigned long int nop_instant_instructions;
	unsigned long int mult_div_instant_instructions;


	char aux[255];
	FILE *fp;

	//logfilegen *log;
	
	void sequential_attr();
	void log_process();
	void comb_assignments();
	void mem_mapped_registers();
	void reset_n_attr();
	void clock_stop();
	void end_of_simulation();
	void repo_to_mem_access();
	
	SC_HAS_PROCESS(plasma);
	plasma(sc_module_name name_, regaddress address_ = 0x00, char *logfile_= "log.txt", bool is_master_ = 0) :
	sc_module(name_), router_address(address_), logfile(logfile_), is_master(is_master_)
	{

		end_sim_reg.write(0x00000001);

		shift_mem_page = log10(PAGESIZE)/log10(2);
	
		cpu = new mlite_cpu("mlite", router_address);
		cpu->clk(clock_hold);
		cpu->reset_in(reset);
		cpu->intr_in(irq);
		cpu->mem_address(cpu_mem_address);
		cpu->mem_data_w(cpu_mem_data_write);
		cpu->mem_data_r(cpu_mem_data_read);
		cpu->mem_byte_we(cpu_mem_write_byte_enable);
		cpu->mem_pause(cpu_mem_pause);
		cpu->current_page(current_page);
		
		if (is_master){
			ram_mas = new ram_master("ram_master");
			ram_mas->clk(clock);
			ram_mas->enable_a(cpu_enable_ram);
			ram_mas->wbe_a(cpu_mem_write_byte_enable);
			ram_mas->address_a(addr_a);
			ram_mas->data_write_a(cpu_mem_data_write);
			ram_mas->data_read_a(data_read_ram);
			ram_mas->enable_b(dmni_enable_internal_ram);
			ram_mas->wbe_b(dmni_mem_write_byte_enable);
			ram_mas->address_b(addr_b);
			ram_mas->data_write_b(dmni_mem_data_write);
			ram_mas->data_read_b(mem_data_read);
		} else {
			ram_sla = new ram_plasma("ram_plasma");
			ram_sla->clk(clock);
			ram_sla->enable_a(cpu_enable_ram);
			ram_sla->wbe_a(cpu_mem_write_byte_enable);
			ram_sla->address_a(addr_a);
			ram_sla->data_write_a(cpu_mem_data_write);
			ram_sla->data_read_a(data_read_ram);
			ram_sla->enable_b(dmni_enable_internal_ram);
			ram_sla->wbe_b(dmni_mem_write_byte_enable);
			ram_sla->address_b(addr_b);
			ram_sla->data_write_b(dmni_mem_data_write);
			ram_sla->data_read_b(mem_data_read);
		}
		
		dm_ni = new dmni("dmni", router_address);
		dm_ni->clock(clock);
		dm_ni->reset(reset);

		dm_ni->set_address(cpu_set_address);
		dm_ni->set_address_2(cpu_set_address_2);
		dm_ni->set_size(cpu_set_size);
		dm_ni->set_size_2(cpu_set_size_2);
		dm_ni->set_op(cpu_set_op);
		dm_ni->start(cpu_start);

		dm_ni->config_data(dmni_data_read);
		dm_ni->intr(ni_intr);
		dm_ni->send_active(dmni_send_active_sig);
		dm_ni->receive_active(dmni_receive_active_sig);

		dm_ni->mem_address(dmni_mem_address);
		dm_ni->mem_data_write(dmni_mem_data_write);
		dm_ni->mem_data_read(dmni_mem_data_read);
		dm_ni->mem_byte_we(dmni_mem_write_byte_enable);

		dm_ni->clock_tx(clock_tx_ni);
		dm_ni->tx(tx_ni);
		dm_ni->data_out(data_out_ni);
		dm_ni->credit_i(credit_i_ni);
		dm_ni->clock_rx(clock_rx_ni);
		dm_ni->rx(rx_ni);
		dm_ni->data_in(data_in_ni);
		dm_ni->credit_o(credit_o_ni);

		router = new router_cc("router",router_address);
		router->clock(clock);
		router->reset_n(reset_n);
		router->clock_tx[EAST] (clock_tx[EAST] );
		router->clock_tx[WEST] (clock_tx[WEST] );
		router->clock_tx[NORTH](clock_tx[NORTH]);
		router->clock_tx[SOUTH](clock_tx[SOUTH]);
		router->clock_tx[LOCAL](clock_rx_ni);
		router->tx[EAST](tx[EAST]);
		router->tx[WEST](tx[WEST]);
		router->tx[NORTH](tx[NORTH]);
		router->tx[SOUTH](tx[SOUTH]);
		router->tx[LOCAL](rx_ni);
		router->credit_o[EAST](credit_o[EAST]);
		router->credit_o[WEST](credit_o[WEST]);
		router->credit_o[NORTH](credit_o[NORTH]);
		router->credit_o[SOUTH](credit_o[SOUTH]);
		router->credit_o[LOCAL](credit_i_ni);
		router->data_out[EAST](data_out[EAST]);
		router->data_out[WEST](data_out[WEST]);
		router->data_out[NORTH](data_out[NORTH]);
		router->data_out[SOUTH](data_out[SOUTH]);
		router->data_out[LOCAL](data_in_ni);
		router->rx[EAST](rx[EAST]);
		router->rx[WEST](rx[WEST]);
		router->rx[NORTH](rx[NORTH]);
		router->rx[SOUTH](rx[SOUTH]);
		router->rx[LOCAL](tx_ni);
		router->credit_i[EAST](credit_i[EAST]);
		router->credit_i[WEST](credit_i[WEST]);
		router->credit_i[NORTH](credit_i[NORTH]);
		router->credit_i[SOUTH](credit_i[SOUTH]);
		router->credit_i[LOCAL](credit_o_ni);
		router->data_in[EAST](data_in[EAST]);
		router->data_in[WEST](data_in[WEST]);
		router->data_in[NORTH](data_in[NORTH]);
		router->data_in[SOUTH](data_in[SOUTH]);
		router->data_in[LOCAL](data_out_ni);
		router->clock_rx[EAST] (clock_rx[EAST]);
		router->clock_rx[WEST] (clock_rx[WEST]);
		router->clock_rx[NORTH](clock_rx[NORTH]);
		router->clock_rx[SOUTH](clock_rx[SOUTH]);
		router->clock_rx[LOCAL](clock_tx_ni);
		router->tick_counter(tick_counter);
		
		SC_METHOD(reset_n_attr);
		sensitive << reset;
		
		SC_METHOD(sequential_attr);
		sensitive << clock.pos() << reset.pos();
		
		SC_METHOD(log_process);
		sensitive << clock.pos() << reset.pos();
		
		SC_METHOD(comb_assignments);
		sensitive << cpu_mem_address << dmni_mem_address << cpu_mem_address_reg << write_enable;
		sensitive << cpu_mem_data_write_reg << data_read << irq_mask_reg << irq_status;
		sensitive << time_slice << tick_counter_local;
		sensitive << dmni_send_active_sig << dmni_receive_active_sig << data_read_ram;
		sensitive << cpu_set_op << cpu_set_size << cpu_set_address << cpu_set_address_2 << cpu_set_size_2 << dmni_enable_internal_ram;
		sensitive << mem_data_read << cpu_enable_ram << cpu_mem_write_byte_enable_reg << dmni_mem_write_byte_enable;
		sensitive << dmni_mem_data_write << ni_intr;
		
		SC_METHOD(mem_mapped_registers);
		sensitive << cpu_mem_address_reg;
		sensitive << tick_counter_local;
		sensitive << data_read_ram;
		sensitive << time_slice;
		sensitive << irq_status;
		
		SC_METHOD(end_of_simulation);
		sensitive << end_sim_reg;

		SC_METHOD(clock_stop);
		sensitive << clock << reset.pos();	
		
		SC_METHOD(repo_to_mem_access);
		sensitive << clock.pos();
		sensitive << reset;

	}
	
	public:
		regaddress router_address;
		char *logfile;
		bool is_master;
};


#endif
