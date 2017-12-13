//------------------------------------------------------------------------------------------------
//
//  DISTRIBUTED HEMPS -  5.0
//
//  Research group: GAPH-PUCRS    -    contact   fernando.moraes@pucrs.br
//
//  Distribution:  September 2013
//
//  Source name:  logfilegen.cpp
//
//  Brief description: Function of log files generation.
//
//------------------------------------------------------------------------------------------------

#include "logfilegen.h"

void logfilegen::debug_output(){
	sc_uint<32 >  l_data_log;
	char c;
	static bool str_end = false;
	int i;
	
	l_data_log = data_log.read();
	
	if(data_av.read() == 1)
	{
		str_end = false;
		for(i=0;i<4;i++){
			c = l_data_log.range(31-i*8,24-i*8);
			//Writes a string in the line
			if(c != 10 && c != 0 && !(str_end)){
				str_out += c;
			}
			//Detects the string end
			else if(c == 0){
				str_end = true;
			}
			//Line feed detected. Writes the line in the file
			else if(c == 10){
				str_out += c;
			}
		}
	}
}
