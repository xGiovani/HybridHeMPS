import HeMPS_defaults::*;

interface logs_plasma_s_noc #( NUMBERPENOC=4) (
  input rel,
  input reset,  
  //HEMPS
  input logic [NUMBERPENOC - 1:0]   rx_p,
  input logic [NUMBERPENOC - 1:0]   tx_p,
  input regflit [NUMBERPENOC-1:0] data_in_p,
  input regflit [NUMBERPENOC- 1:0] data_out_p
); 

  
     
  integer count_cycles_rx_comm [NUMBERPENOC- 1: 0]; 
  integer time_comm_10_start [NUMBERPENOC- 1: 0];
  integer time_comm_10_fineshed [NUMBERPENOC- 1: 0];
  integer delta_rx [NUMBERPENOC- 1: 0];
  
  integer count_cycles_tx_comm [NUMBERPENOC- 1: 0];
  integer time_comm_20_start [NUMBERPENOC- 1: 0];
  integer time_comm_20_fineshed [NUMBERPENOC- 1: 0];
  integer delta_tx [NUMBERPENOC- 1: 0];

  logic [NUMBERPENOC- -1:0] [15:0] taskid_10_src, taskid_20_src, taskid_10_dst, taskid_20_dst;
  
  integer task70_finished [NUMBERPENOC- 1:0];
  integer comm_10 [NUMBERPENOC- 1:0];
  integer comm_20 [NUMBERPENOC- 1:0];
  string files [NUMBERPENOC- 1:0] ;
  string serv [2:0]= {"Serv10","Serv20","Serv70"};
  string slaves [NUMBERPENOC - 1:0] ;
  string slave_aux="0", str;
  integer DEBUG;

  initial begin
        slaves[0] ={"_"};
	  slaves[1] ={"log/Slave_Hemps_1_"};
	  slaves[2] ={"log/Slave_Hemps_2_"};
	  slaves[3] ={"log/Slave_Hemps_3_"};
	  slaves[4] ={"log/Slave_Hemps_4_"};
	  slaves[5] ={"log/Slave_Hemps_5_"};
	  slaves[6] ={"log/Slave_Hemps_6_"};
	  slaves[7] ={"log/Slave_Hemps_7_"};
	  slaves[8] ={"log/Slave_Hemps_8_"};
	  slaves[9] ={"log/Slave_Hemps_9_"};
	  slaves[10] ={"log/Slave_Hemps_10_"};
	  slaves[11] ={"log/Slave_Hemps_11_"};
	  slaves[12] ={"log/Slave_Hemps_12_"};
	  slaves[13] ={"log/Slave_Hemps_13_"};
	  slaves[14] ={"log/Slave_Hemps_14_"};
	  slaves[15] ={"log/Slave_Hemps_15_"};
	  slaves[16] ={"log/Slave_Hemps_16_"};
	  slaves[17] ={"log/Slave_Hemps_17_"};
	  slaves[18] ={"log/Slave_Hemps_18_"};
	  slaves[19] ={"log/Slave_Hemps_19_"}; 
    for (int j=1; j<= (NUMBERPENOC-1); j++ )begin  
        slave_aux ={slaves[j],serv[2],".tx"};
        comm_10[j] = $fopen(slave_aux,"w");
        slave_aux ={slaves[j],serv[1],".tx"};
        comm_20[j] = $fopen(slave_aux,"w");
	      slave_aux ={slaves[j],serv[0],".tx"};
        task70_finished[j] = $fopen(slave_aux,"w");
	      count_cycles_rx_comm[j]=0;
	      count_cycles_tx_comm[j]=0;
    end
    //_aux ={slaves[1],serv[2],".tx"};
    //DEBUG = $fopen(slave_aux,"w");	      
  end
  
  always @(posedge rel) begin
    @tx_p;    
    for (int j=1; j<= (NUMBERPENOC-1); j++ )begin
      if (tx_p[j] == 1 )begin
        Serv_tx(j);
      end 
    end    
  end
  always @(posedge rel) begin
    @rx_p;
    $display("RX_P %t", $time);
    for (int j=1; j<= (NUMBERPENOC-1); j++ )begin
      if (rx_p[j] == 1 )begin
        $display("RX_P[%d] datain: %h %t", j,data_in_p[j] ,$time);
        Serv_rx(j);
      end 
    end    
  end

 task Serv_rx( input integer index);
    time_comm_20_start[index]=$realtime;
    repeat(2)@(posedge rel);
    count_cycles_rx_comm[index]+=4;
    if (data_in_p[index][15:0] == 16'h0020) begin  
      @(posedge rel);
      taskid_20_dst[index]=data_in_p[index][15:0];
      @(posedge rel);
      taskid_20_src[index]=data_in_p[index][15:0];
      while (rx_p[index] == 1'b1) begin            
        @(posedge rel);
        count_cycles_rx_comm[index]++;
      end
      time_comm_20_fineshed[index]=$realtime;
      if (rx_p[index] == 1'b0)begin
        repeat(20)@(posedge rel); 
        delta_rx[index] = time_comm_20_fineshed[index] - time_comm_20_start[index]; 
        $fwrite( comm_20[index] ,"Taskid_dst: %h, Taskid_src: %h, Start: %t, Finished: %t, Delta: %t, Cycles:%d \n", taskid_20_dst[index], taskid_20_src[index], time_comm_20_start[index], time_comm_20_fineshed[index], delta_rx[index], count_cycles_rx_comm[index]);
      end
    end   
  endtask

  task Serv_tx ( input integer index);             
    time_comm_10_start[index]=$realtime;
    repeat(2)@(posedge rel);
    $display("To aqui no Serv_tx 1, INDEx:%d data:%h %t", index, data_out_p[index][15:0],$time); 
    count_cycles_tx_comm[index]+=4;
    if (data_out_p[index][15:0] == 16'h0010) begin 
      $display("To aqui no Serv_tx 2, INDEx:%d data:%h %t", index, data_out_p[index][15:0],$time); 
      @(posedge rel);
      taskid_10_dst[index]=data_out_p[index][15:0];
      @(posedge rel);
      taskid_10_src[index]=data_out_p[index][15:0];
      while (tx_p[index] == 1'b1) begin            
        @(posedge rel);
        count_cycles_tx_comm[index]++;
      end
      time_comm_10_fineshed[index]=$realtime;
      if (tx_p[index] == 1'b0)begin
        repeat(10)@(posedge rel); 
        delta_tx[index] = time_comm_10_fineshed[index] - time_comm_10_start[index]; 
        $fwrite( comm_10[index] ,"Taskid_dst: %h, Taskid_src: %h, Start: %t, Finished: %t, Delta: %t, Cycles:%d \n", taskid_10_dst[index], taskid_10_src[index], time_comm_10_start[index], time_comm_10_fineshed[index], delta_tx[index], count_cycles_tx_comm[index]);
      end
    end
    else if(data_out_p[index][15:0] == 16'h0070) begin
      @(posedge rel);
      $fwrite( task70_finished[index] ,"Task Finalizada = %d - %h | %t\n", data_out_p[index][15:0], data_out_p[index][15:0] ,$realtime);
    end    
  endtask
  
 
endinterface: logs_plasma_s_noc 
