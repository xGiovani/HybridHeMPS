//------------------------------------------------------------------------------------------------
//
//  DISTRIBUTED HEMPS  - version 5.0
//
//  Research group: GAPH-PUCRS    -    contact   fernando.moraes@pucrs.br
//
//  Distribution:  September 2013
//
//  Source name:  plasma_slave.cpp
//
//  Brief description:  This source manipulates the memory mapped registers.
//
//------------------------------------------------------------------------------------------------

#include "plasma.h"

void plasma::repo_to_mem_access(){

	if (reset.read() == 1){
		repo_FSM.write(WAIT);
		cpu_repo_acess.write(0);
	} else {

		switch (repo_FSM.read()) {
			case WAIT:
				if (cpu_mem_address.read()(30,28) == 1){
					cpu_repo_acess.write(1);
					repo_FSM.write(COPY_FROM_REP);
				}
			break;

			case COPY_FROM_REP:
				repo_FSM.write(WAIT);
				cpu_repo_acess.write(0);
			break;
		}
	}
}


void plasma::mem_mapped_registers(){
	
	sc_uint <32 > l_cpu_mem_address_reg = cpu_mem_address_reg.read();
	
	if(l_cpu_mem_address_reg.range(30,28 ) == 1){

		cpu_mem_data_read.write(data_read.read());

	} else{

		switch(l_cpu_mem_address_reg){
			case IRQ_MASK:
				cpu_mem_data_read.write(irq_mask_reg.read());
			break;
			case IRQ_STATUS_ADDR:
				cpu_mem_data_read.write(irq_status.read());
			break;
			case TIME_SLICE_ADDR:
				cpu_mem_data_read.write(time_slice.read());
			break;
			case NET_ADDRESS:
				cpu_mem_data_read.write(router_address);
			break;
			case TICK_COUNTER_ADDR:
				cpu_mem_data_read.write(tick_counter.read());
			break;
			case REQ_APP_REG:
				cpu_mem_data_read.write(req_app.read());
			break;
			case DMA_SEND_ACTIVE:
				cpu_mem_data_read.write(dmni_send_active_sig.read());
			break;
			case DMA_RECEIVE_ACTIVE:
				cpu_mem_data_read.write(dmni_receive_active_sig.read());
			break;
			default:
				cpu_mem_data_read.write(data_read_ram.read());
			break;
		}
	}
}


void plasma::comb_assignments(){
	sc_uint<8 > l_irq_status;
	sc_uint <32 > new_mem_address;

	new_mem_address = cpu_mem_address.read();

	//Esse IF faz com que seja editado o valor de endereço de memoria usado pela CPU. Inserindo na parte
	//alta do endereco o valor correto de referencia a pagina. Este valor esta presente em current_page
	//que deve ser inserido na parte alta do endereco de memoria.
	//Esse IF faz com que a mascara 0xF000..(FFF..32-shift_mem_page) seja colocada no endereco para a memoria
	//Isso porque a migracao de tarefas a pilha acaba guardando informacao de offset da pagina origem, o que corrompe o retorno de fucoes
	if (current_page.read() && ((0xFFFFFFFF << shift_mem_page) & new_mem_address)){
		new_mem_address &= (0xF0000000 | (0xFFFFFFFF >> (32-shift_mem_page)));
		new_mem_address |= current_page.read() * PAGESIZE;//OFFSET
	}

	addr_a.write(new_mem_address.range(31, 2));
	addr_b.write(dmni_mem_address.read()(31,2));
	
	cpu_mem_pause.write(cpu_repo_acess.read());
	irq.write((((irq_status.read() & irq_mask_reg.read()) != 0x00)) ? 1  : 0 );
	cpu_set_size.write((((cpu_mem_address_reg.read() == DMA_SIZE) && (write_enable.read() == 1))) ? 1  : 0 );
	cpu_set_address.write((((cpu_mem_address_reg.read() == DMA_ADDR) && (write_enable.read() == 1))) ? 1  : 0 );
	cpu_set_size_2.write((((cpu_mem_address_reg.read() == DMA_SIZE_2) && (write_enable.read() == 1))) ? 1  : 0 );
	cpu_set_address_2.write((((cpu_mem_address_reg.read() == DMA_ADDR_2) && (write_enable.read() == 1))) ? 1  : 0 );
	cpu_set_op.write((((cpu_mem_address_reg.read() == DMA_OP) && (write_enable.read() == 1))) ? 1  : 0 );
	cpu_start.write((((cpu_mem_address_reg.read() == START_DMA) && (write_enable.read() == 1))) ? 1  : 0 );
	dmni_data_read.write( cpu_mem_data_write_reg.read());
	dmni_mem_data_read.write( (dmni_enable_internal_ram.read() == 1) ? mem_data_read.read()  : data_read.read() );
	write_enable.write(((cpu_mem_write_byte_enable_reg.read() != 0)) ? 1  : 0 );
	cpu_enable_ram.write(((cpu_mem_address.read()(30,28 ) == 0)) ? 1  : 0 );
	dmni_enable_internal_ram.write(((dmni_mem_address.read()(30,28 ) == 0)) ? 1  : 0 );
	end_sim_reg.write((((cpu_mem_address_reg.read() == END_SIM) && (write_enable.read() == 1))) ? 0x00000000 : 0x00000001);	

	if (cpu_repo_acess.read() == 1){
		address.write(cpu_mem_address.read());
	} else if (dmni_mem_address.read()(30,28 ) == 1){
		address.write(dmni_mem_address.read());
	}

	l_irq_status[7] = 0;
	l_irq_status[6] = 0;
	l_irq_status[5] = ni_intr.read();
	l_irq_status[4] = 0;
	l_irq_status[3] = (time_slice.read() == 1) ? 1  : 0;
	l_irq_status[2] = 0;
	l_irq_status[1] = 0;
	l_irq_status[0] = (!dmni_send_active_sig.read() && pending_service.read());
	
	irq_status.write(l_irq_status);
}

void plasma::reset_n_attr(){
	reset_n.write(!reset.read());
}

void plasma::sequential_attr(){

	char string_out[100];
	FILE *fp;
	char c, end;

	if (reset.read() == 1) {
		cpu_mem_address_reg.write(0);
		cpu_mem_data_write_reg.write(0);
		cpu_mem_write_byte_enable_reg.write(0);
		irq_mask_reg.write(0);
		time_slice.write(0);
		tick_counter.write(0);
		pending_service.write(0);
	} else {

		if(cpu_mem_pause.read() == 0) {
			cpu_mem_address_reg.write(cpu_mem_address.read());
			
			cpu_mem_data_write_reg.write(cpu_mem_data_write.read());
			
			cpu_mem_write_byte_enable_reg.write(cpu_mem_write_byte_enable.read());
			
			if(cpu_mem_address_reg.read()==IRQ_MASK && write_enable.read()==1){
				irq_mask_reg.write(cpu_mem_data_write_reg.read()(7,0));
			}

			//if (current_page.read() != 0) {
					// Decrements the time slice when executing a task (current_page /= x"00") or handling a syscall (syscall = '1')
				if (time_slice.read() > 1) {
					time_slice.write(time_slice.read() - 1);
				}
			//}

			//************** pending service implementation *******************
			if (cpu_mem_address_reg.read() == PENDING_SERVICE_INTR && write_enable.read() == 1){
				if (cpu_mem_data_write_reg.read() == 0){
					pending_service.write(0);
				} else {
					pending_service.write(1);
				}
			}
			//*********************************************************************

		}

		//************** simluation-time debug implementation *******************
		if (cpu_mem_address_reg.read() == DEBUG && write_enable.read() == 1){
			sprintf(aux, "log/log%dx%d.txt", (unsigned int) router_address.range(15,8), (unsigned int) router_address.range(7,0));
			fp = fopen (aux, "a");

			end = 0;
			for(int i=0;i<4;i++) {
				c = cpu_mem_data_write_reg.read().range(31-i*8,24-i*8);

				//Writes a string in the line
				if(c != 10 && c != 0 && !end){
					fprintf(fp,"%c",c);
				}
				//Detects the string end
				else if(c == 0){
					end = true;
				}
				//Line feed detected. Writes the line in the file
				else if(c == 10){
					fprintf(fp,"%c",c);
				}
			}

			fclose (fp);
		}
		//*********************************************************************

		if ((cpu_mem_address_reg.read() == SCHEDULING_REPORT) and (write_enable.read()==1) ) {

			sprintf(aux, "debug/scheduling_report.txt");
			fp = fopen (aux, "a");
			sprintf(aux, "%d\t%d\t%d\n", (unsigned int)router_address, (unsigned int)cpu_mem_data_write_reg.read(), (unsigned int)tick_counter.read());
			fprintf(fp,"%s",aux);
			fclose (fp);
		}

		if ((cpu_mem_address_reg.read() == TIME_SLICE_ADDR) and (write_enable.read()==1) ) {
			time_slice.write(cpu_mem_data_write_reg.read());
  		}
  		
		if (cpu_mem_address_reg.read() == ACK_APP_REG) {
			ack_app.write(1);
		} else if (req_app.read()[31] == 0) {
			ack_app.write(0);
		}

  		tick_counter.write((tick_counter.read() + 1) );

	}
}

void plasma::end_of_simulation(){
    if (end_sim_reg.read() == 0x00000000){
        cout << "END OF ALL APPLICATIONS!!!" << endl;
        cout << "Simulation time: " << (float) ((tick_counter.read() * 10.0f) / 1000.0f / 1000.0f) << "ms" << endl;
        sc_stop();
    }
}

void plasma::log_process(){
	if (reset.read() == 1) {
		log_interaction=1;
		instant_instructions = 0;		
		aux_instant_instructions = 0;

		logical_instant_instructions = 0;
		jump_instant_instructions = 0;
		branch_instant_instructions = 0;
		move_instant_instructions = 0;
		other_instant_instructions = 0;
		arith_instant_instructions = 0;
		load_instant_instructions = 0;
		shift_instant_instructions = 0;
		nop_instant_instructions = 0;
		mult_div_instant_instructions = 0;

	} else {

		if(tick_counter.read() == 100000*log_interaction) {
			

			fp = fopen ("log_tasks.txt", "a+");
			
			aux_instant_instructions = cpu->global_inst - instant_instructions;

			sprintf(aux, "%d,%lu,%lu,%lu\n",  (int)router_address,cpu->global_inst,aux_instant_instructions,100000*log_interaction);

			instant_instructions = cpu->global_inst;

		
			fprintf(fp,"%s",aux);
		
			fclose(fp); 
			fp = NULL;


			fp = fopen ("log_tasks_full.txt", "a+");


			fprintf(fp,"%d ",(int)router_address);

			aux_instant_instructions = cpu->logical_inst - logical_instant_instructions;

			fprintf(fp,"%lu ",aux_instant_instructions);
			
			logical_instant_instructions = cpu->logical_inst;

			aux_instant_instructions = cpu->jump_inst - jump_instant_instructions;

			fprintf(fp,"%lu ",aux_instant_instructions);

			jump_instant_instructions = cpu->jump_inst;

			aux_instant_instructions = cpu->branch_inst - branch_instant_instructions;

			fprintf(fp,"%lu ",aux_instant_instructions);

			branch_instant_instructions = cpu->branch_inst;

			aux_instant_instructions = cpu->move_inst - move_instant_instructions;

			fprintf(fp,"%lu ",aux_instant_instructions);

			move_instant_instructions = cpu->move_inst;

			aux_instant_instructions = cpu->other_inst - other_instant_instructions;

			fprintf(fp,"%lu ",aux_instant_instructions);

			other_instant_instructions = cpu->other_inst;

			aux_instant_instructions = cpu->arith_inst - arith_instant_instructions;

			fprintf(fp,"%lu ",aux_instant_instructions);

			arith_instant_instructions = cpu->arith_inst;

			aux_instant_instructions = cpu->load_inst - load_instant_instructions;

			fprintf(fp,"%lu ",aux_instant_instructions);

			load_instant_instructions = cpu->load_inst;

			aux_instant_instructions = cpu->shift_inst - shift_instant_instructions;

			fprintf(fp,"%lu ",aux_instant_instructions);

			shift_instant_instructions = cpu->shift_inst;

			aux_instant_instructions = cpu->nop_inst - nop_instant_instructions;

			fprintf(fp,"%lu ",aux_instant_instructions);

			nop_instant_instructions = cpu->nop_inst;

			aux_instant_instructions = cpu->mult_div_inst - mult_div_instant_instructions;

			fprintf(fp,"%lu ",aux_instant_instructions);
			
			mult_div_instant_instructions = cpu->mult_div_inst;

			fprintf(fp,"%lu",100000*log_interaction);
			fprintf(fp,"\n");
		
		
			fclose(fp); 
			fp = NULL;


			log_interaction++;
		}
	}
}




void plasma::clock_stop(){

	if (reset.read() == 1) {
		tick_counter_local.write(0);
		clock_aux = true;
	}

	if((cpu_mem_address_reg.read() == CLOCK_HOLD) && (write_enable.read() == 1)){
		clock_aux = false;

	} else if((rx_ni.read() == 1 || ni_intr.read() == 1)){
		clock_aux = true;
	}

	if((clock and clock_aux) == true){
		tick_counter_local.write((tick_counter_local.read() + 1) );
	}

	clock_hold.write(clock and clock_aux);

}

