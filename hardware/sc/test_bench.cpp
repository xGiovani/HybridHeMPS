//------------------------------------------------------------------------------------------------
//
//  DISTRIBUTED HEMPS -  5.0
//
//  Research group: GAPH-PUCRS    -    contact   fernando.moraes@pucrs.br
//
//  Distribution:  September 2013
//
//  Source name:  test_bench.cpp
//
//  Brief description: Testbench debugger
//
//------------------------------------------------------------------------------------------------

#include "test_bench.h"

#ifdef MTI_SYSTEMC
SC_MODULE_EXPORT(test_bench);
#endif

void test_bench::read_repository(){

	unsigned int index = (unsigned int)address[0].read()(25,0);

	index = index / 4;

	if (index < REPO_SIZE){
		data_read[0].write(repository[index]);
	}
}

void test_bench::new_app(){
	
		int j = 0;
		
		if (reset.read() == 1) 
		{
			req_app[0].write(0);
		}
		else
		{
			for(j=0;j<NUMBER_OF_APPS;j++)
			{
				wait(appstime[j], SC_MS);
				req_app[0].write(j | 0x80000000);
				cout << "Pediu a aplicacao " << j << endl;
				wait(ack_app[0].posedge_event());
				cout << "Recebeu ack!" << endl;
				req_app[0].write(0);
				wait(ack_app[0].negedge_event());
			}
		}
}

void test_bench::ClockGenerator(){
	while(1){
		clock.write(0);
		wait (5, SC_NS);					//Allow signals to set
		clock.write(1);
		wait (5, SC_NS);					//Allow signals to set
	}
}
	
void test_bench::resetGenerator(){
	reset.write(1);
	wait (70, SC_NS);
	reset.write(0);
}

	
