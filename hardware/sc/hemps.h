//------------------------------------------------------------------------------------------------
//
//  DISTRIBUTED HEMPS -  5.0
//
//  Research group: GAPH-PUCRS    -    contact   fernando.moraes@pucrs.br
//
//  Distribution:  September 2013
//
//  Source name:  hemps.h
//
//  Brief description: Control of intefaces.
//
//------------------------------------------------------------------------------------------------

#include <systemc.h>

#include <HeMPS_PKG.h>
#include "../plasma/sc/plasma.h"

#define BL 0
#define BC 1
#define BR 2
#define CL 3
#define CC 4
#define CRX 5
#define TL 6
#define TC 7
#define TR 8



SC_MODULE(hemps) {
	
	sc_in< bool >			clock;
	sc_in< bool >			reset;

	//Tasks repository interface
	sc_out<sc_uint<30> >	mem_addr[N_PE];
	sc_in<sc_uint<32> >		data_read[N_PE];
	
	//Dynamic Insertion of Applications
	sc_out<bool >			ack_app[N_PE];
	sc_in<sc_uint<32> >		req_app[N_PE];
	
	// NoC Interface
	sc_signal<bool >		clock_tx[N_PE][NPORT-1];
	sc_signal<bool >		tx[N_PE][NPORT-1];
	sc_signal<regflit >		data_out[N_PE][NPORT-1];
	sc_signal<bool >		credit_i[N_PE][NPORT-1];
	
	sc_signal<bool >		clock_rx[N_PE][NPORT-1];
	sc_signal<bool > 		rx[N_PE][NPORT-1];
	sc_signal<regflit >		data_in[N_PE][NPORT-1];
	sc_signal<bool >		credit_o[N_PE][NPORT-1];
		
	plasma  *slave[N_PE];//store slaves PEs
	
	sc_signal<sc_uint<4> > 	pos[N_PE];
	
	int i,j;
	
	int RouterPosition(int router);
	regaddress RouterAddress(int router);
 	void pes_interconnection();
 	
	char temp[20];
	char logfile[20];
	SC_CTOR(hemps){
		
		for(j=0;j<N_PE;j++){
			printf("creating PE:%dX%d\n",j%N_PE_X,j/N_PE_X);
		}
		for(j=0;j<N_PE;j++){

			if(kernel_type[j]==2) {
				printf("creating MASTER: %d\n",j);
				memset(temp, 0, sizeof(temp)); sprintf(temp,"master%d",j);
				memset(logfile, 0, sizeof(logfile)); sprintf(logfile,"log%d.txt",j);
				slave[j] = new plasma(temp,RouterAddress(j),logfile, 1);

			} else if(kernel_type[j]==1) {

				printf("creating LOCAL: %d\n",j);
				memset(temp, 0, sizeof(temp)); sprintf(temp,"local%d",j);
				memset(logfile, 0, sizeof(logfile)); sprintf(logfile,"log%d.txt",j);
				slave[j] = new plasma(temp,RouterAddress(j),logfile, 1);

			} else {

				printf("creating SLAVE: %d\n",j);
				memset(temp, 0, sizeof(temp)); sprintf(temp,"slave%d",j);
				memset(logfile, 0, sizeof(logfile)); sprintf(logfile,"log%d.txt",j);
				slave[j] = new plasma(temp,RouterAddress(j),logfile, 0);
			}

			slave[j]->clock(clock);
			slave[j]->reset(reset);
			slave[j]->address(mem_addr[j]);
			slave[j]->data_read(data_read[j]);
			slave[j]->ack_app(ack_app[j]);
			slave[j]->req_app(req_app[j]);

			for(i=0;i<NPORT-1;i++){
				slave[j]->clock_tx	[i]	(clock_tx	[j][i]);
				slave[j]->tx		[i]	(tx			[j][i]);
				slave[j]->data_out	[i]	(data_out	[j][i]);
				slave[j]->credit_i	[i]	(credit_i	[j][i]);
				slave[j]->clock_rx	[i]	(clock_rx	[j][i]);
				slave[j]->data_in	[i]	(data_in	[j][i]);
				slave[j]->rx		[i]	(rx			[j][i]);
				slave[j]->credit_o	[i]	(credit_o	[j][i]);
			}
		}
	 		SC_METHOD(pes_interconnection);
			for(j=0;j<N_PE;j++){
				for(i=0;i<NPORT-1;i++){
					sensitive << clock_tx	[j][i];
					sensitive << tx			[j][i];
					sensitive << data_out	[j][i];
					sensitive << credit_i	[j][i];
					sensitive << clock_rx	[j][i];
					sensitive << data_in	[j][i];
					sensitive << rx			[j][i];
					sensitive << credit_o	[j][i];
				}
			}
				
	}
};

