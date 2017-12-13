//------------------------------------------------------------------------------------------------
//
//  DISTRIBUTED HEMPS -  5.0
//
//  Research group: GAPH-PUCRS    -    contact   fernando.moraes@pucrs.br
//
//  Distribution:  September 2013
//
//  Source name:  test_bench.h
//
//  Brief description: Testbench debugger
//
//------------------------------------------------------------------------------------------------

#include <systemc.h>
#include <iostream>
#include <string>

using namespace std;

#include "hemps.h"
#include <repository.h>

SC_MODULE(test_bench) {
	
	sc_signal< bool >	clock;
	sc_signal< bool >	reset;
		
	void read_repository();
	void ClockGenerator();
	void resetGenerator();
	void debug_output();
	void log_gen();
	void new_app();
	
	hemps *MPSoC;

	//Tasks repository interface
	sc_signal<sc_uint<30> >		address[N_PE];
	sc_signal<sc_uint<32> > 	data_read[N_PE];
	
	//Dynamic Insertion of Applications
	sc_signal<bool > 			ack_app[N_PE];
    sc_signal<sc_uint<32> >     req_app[N_PE];
    
	char aux[255];
	FILE *fp;
	int pe_count;
	
	SC_HAS_PROCESS(test_bench);
	test_bench(sc_module_name name_, char *filename_= "output_master.txt") :
    sc_module(name_), filename(filename_)
    {
		
		MPSoC = new hemps("hemps");
		MPSoC->clock(clock);
		MPSoC->reset(reset);

		for(int i =0; i<N_PE; i++){
			MPSoC->mem_addr[i](address[i]);
			MPSoC->data_read[i](data_read[i]);
			MPSoC->ack_app[i](ack_app[i]);
			MPSoC->req_app[i](req_app[i]);
		}
		
		
		SC_METHOD(read_repository);
		sensitive << address[0];
		
		SC_THREAD(new_app);
		sensitive << reset;
		
		SC_THREAD(ClockGenerator);

		SC_THREAD(resetGenerator);
		
	}
	~test_bench(){

		//Store in aux the c's string way, in address how many char were builded
		sprintf(aux, "log_energy.txt");
		// Open a file called aux deferred on append mode
		fp = fopen (aux, "w+");
		fclose (fp);	

		for(int j=0;j<N_PE;j++){
			//Store in aux the c's string way, in address how many char were builded
			sprintf(aux, "log_energy.txt");
			// Open a file called aux deferred on append mode
			fp = fopen (aux, "a");
			
			sprintf(aux, "router %d port EAST flits %d ", j, MPSoC-> slave[j] ->router->wire_EAST);
			fprintf(fp,"%s",aux);
			sprintf(aux, "port WEST flits %d ",MPSoC-> slave[j] ->router->wire_WEST);
			fprintf(fp,"%s",aux);
			sprintf(aux, "port NORTH flits %d ",MPSoC-> slave[j] ->router->wire_NORTH);
			fprintf(fp,"%s",aux);
			sprintf(aux, "port SOUTH flits %d ",MPSoC-> slave[j] ->router->wire_SOUTH);
			fprintf(fp,"%s",aux);
			sprintf(aux, "port LOCAL flits %d ",MPSoC-> slave[j] ->router->wire_LOCAL);
			fprintf(fp,"%s",aux);
			sprintf(aux, "TOTAL flits %d ",MPSoC-> slave[j] ->router->total_flits);
			fprintf(fp,"%s",aux);
			sprintf(aux, "NUMBER pck %d ",MPSoC-> slave[j] ->router->mySwitchControl->number_pck);
			fprintf(fp,"%s",aux);


			sprintf(aux, "fluxo 0 = %d ", MPSoC-> slave[j]  ->router->fluxo_0);
			fprintf(fp,"%s",aux);
			sprintf(aux, "fluxo 1 = %d ",MPSoC-> slave[j]->router->fluxo_1);
			fprintf(fp,"%s",aux);
			sprintf(aux, "fluxo 2 =  %d ",MPSoC-> slave[j]->router->fluxo_2);
			fprintf(fp,"%s",aux);
			sprintf(aux, "fluxo 3 = %d ",MPSoC-> slave[j]->router->fluxo_3);
			fprintf(fp,"%s",aux);
			sprintf(aux, "fluxo 4 = %d ",MPSoC-> slave[j]->router->fluxo_4);
			fprintf(fp,"%s",aux);
			sprintf(aux, "fluxo 5 = %d\n",MPSoC-> slave[j]->router->fluxo_5);
			fprintf(fp,"%s",aux);
			fclose (fp);
					
		}
		
		for(int j=0;j<N_PE;j++)
		{
			
			//Store in aux the c's string way, in address how many char were builded
			sprintf(aux, "log_energy.txt");
			// Open a file called aux deferred on append mode
			fp = fopen (aux, "a");

			sprintf(aux, "PROC %d Arithmetic_tasks %lu ",j, MPSoC-> slave[j] ->cpu->arith_inst_tasks);
			fprintf(fp,"%s",aux);
			sprintf(aux, "Load-Store_tasks %lu ", MPSoC-> slave[j] ->cpu->load_inst_tasks); 
			fprintf(fp,"%s",aux);
			sprintf(aux, "Logical_tasks %lu ",MPSoC-> slave[j] ->cpu->logical_inst_tasks); 
			fprintf(fp,"%s",aux);
			sprintf(aux, "Move_tasks %lu ",MPSoC-> slave[j] ->cpu->move_inst_tasks); 
			fprintf(fp,"%s",aux);
			sprintf(aux, "Shift_tasks %lu ",MPSoC-> slave[j] ->cpu->shift_inst_tasks); 
			fprintf(fp,"%s",aux);
			sprintf(aux, "Jump_tasks %lu ",MPSoC-> slave[j] ->cpu->jump_inst_tasks); 
			fprintf(fp,"%s",aux);				
			sprintf(aux, "Branch_tasks %lu ",MPSoC-> slave[j] ->cpu->branch_inst_tasks); 
			fprintf(fp,"%s",aux);				
			sprintf(aux, "Nop_tasks %lu ",MPSoC-> slave[j] ->cpu->nop_inst_tasks); 
			fprintf(fp,"%s",aux);				
			sprintf(aux, "Mult-Div_tasks %lu ",MPSoC-> slave[j] ->cpu->mult_div_inst_tasks); 
			fprintf(fp,"%s",aux);
			sprintf(aux, "Other_tasks %lu ",MPSoC-> slave[j] ->cpu->other_inst_tasks);
			fprintf(fp,"%s",aux);

			sprintf(aux, "Arithmetic_kernel %lu ",MPSoC-> slave[j] ->cpu->arith_inst_kernel);
			fprintf(fp,"%s",aux);
			sprintf(aux, "Load-Store_kernel %lu ", MPSoC-> slave[j] ->cpu->load_inst_kernel); 
			fprintf(fp,"%s",aux);
			sprintf(aux, "Logical_kernel %lu ",MPSoC-> slave[j] ->cpu->logical_inst_kernel); 
			fprintf(fp,"%s",aux);
			sprintf(aux, "Move_kernel %lu ",MPSoC-> slave[j] ->cpu->move_inst_kernel); 
			fprintf(fp,"%s",aux);
			sprintf(aux, "Shift_kernel %lu ",MPSoC-> slave[j] ->cpu->shift_inst_kernel); 
			fprintf(fp,"%s",aux);
			sprintf(aux, "Jump_kernel %lu ",MPSoC-> slave[j] ->cpu->jump_inst_kernel); 
			fprintf(fp,"%s",aux);				
			sprintf(aux, "Branch_kernel %lu ",MPSoC-> slave[j] ->cpu->branch_inst_kernel); 
			fprintf(fp,"%s",aux);				
			sprintf(aux, "Nop_kernel %lu ",MPSoC-> slave[j] ->cpu->nop_inst_kernel); 
			fprintf(fp,"%s",aux);				
			sprintf(aux, "Mult-Div_kernel %lu ",MPSoC-> slave[j] ->cpu->mult_div_inst_kernel); 
			fprintf(fp,"%s",aux);
			sprintf(aux, "Other_kernel %lu ",MPSoC-> slave[j] ->cpu->other_inst_kernel);
			fprintf(fp,"%s",aux);

			sprintf(aux, "Kernel %lu ",MPSoC-> slave[j] ->cpu->global_inst_kernel);
			fprintf(fp,"%s",aux);
			sprintf(aux, "Task %lu ",MPSoC-> slave[j] ->cpu->global_inst_tasks);
			fprintf(fp,"%s",aux);
			sprintf(aux, "TOTAL %lu\n",MPSoC-> slave[j] ->cpu->global_inst);
			fprintf(fp,"%s",aux);
			fclose (fp);

		}
					
	}
	private:
		char *filename;
};


#ifndef MTI_SYSTEMC

int sc_main(int argc, char *argv[]){
	int time_to_run=0;
	int i;
	char *filename = "output_master.txt";
	if(argc<3){
		cout << "Sintax: " << argv[0] << " -c <milisecons to execute> [-o <output filename>]" << endl;
		exit(EXIT_FAILURE);
	}
	
	for (i = 1; i < argc; i++){/* Check for a switch (leading "-"). */
		if (argv[i][0] == '-') {/* Use the next character to decide what to do. */
			switch (argv[i][1]){
				case 'c':
					time_to_run = atoi(argv[++i]);
				break;
				case 'o':
					filename = argv[++i];
					cout << filename << endl;
				break;
				default:
					cout << "Sintax: " << argv[0] << "-c <milisecons to execute> [-o <output name file>]" << endl;
					exit(EXIT_FAILURE);
				break;
			}
		}
	}
	
	
	test_bench tb("testbench",filename);
	sc_start(time_to_run,SC_MS);
  	return 0;
}
#endif
