library IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use std.textio.all;
use work.memory_pack.all;
use work.HeMPS_PKG.all;



entity log_tb is port(
    reset     : in    std_logic;
    control_data_out_debug : in std_logic_vector(31 downto 0);
    control_write_enable_debug : in std_logic;
    busy_debug : out std_logic;
    ack_app   : in std_logic;
    req_app   : out std_logic_vector(31 downto 0)
    
  );
end;
architecture log_tb of log_tb is
   type state is (LER, WAIT_DDR, WR_HEMPS, START);
        signal EA : state;
        
        type state2 is (S0, S1);
        signal CS: state2;
        
        signal counter  : integer :=0;
        constant  log_file : string := "log/output_master.txt"; --! port                 

begin


        


  process
              variable j : integer := 0;
        begin
                if reset = '1' then
                        req_app <= (others=>'0');
                        j:=0;
                else
                        loop1: while j<NUMBER_OF_APPS loop
                                wait for appstime(j);
                                req_app <= CONV_STD_LOGIC_VECTOR(j, 32) or x"80000000";
                                wait until ack_app'event and ack_app= '1';
                                req_app <= (others=>'0');
                                wait until ack_app'event and ack_app= '0';
                                j:= j + 1;
                        end loop loop1;
                        wait;
                end if;
        end process;
        
     --
     -- creates the output file 
     --
     process(control_write_enable_debug,reset)
       file store_file : text open write_mode is log_file;
       variable file_line : line;
       variable line_type: character;
       variable line_length : natural := 0;
       variable str: string (1 to 4);
       variable str_end: boolean;
     begin
        if reset = '1' then
                str_end := false;
                CS <= S0;      
        elsif rising_edge(control_write_enable_debug) then
                case CS is
                  when S0 =>
                          -- Reads the incoming string
                          line_type := character'val(conv_integer(control_data_out_debug(7 downto 0)));
                          
                          -- Verifies if the string is from Echo()
                          if line_type = '$' then 
                                  write(file_line, line_type);
                                  line_length := line_length + 1;
                                  CS <= S1;
                          
                          -- Writes the string to the file
                          else                                                                    
                                  str(4) := character'val(conv_integer(control_data_out_debug(7 downto 0)));
                                  str(3) := character'val(conv_integer(control_data_out_debug(15 downto 8)));
                                  str(2) := character'val(conv_integer(control_data_out_debug(23 downto 16)));
                                  str(1) := character'val(conv_integer(control_data_out_debug(31 downto 24)));
                                  
                                  str_end := false;
                                  
                                  for i in 1 to 4 loop                                                            
                                          -- Writes a string in the line
                                          if str(i) /= lf and str(i) /= nul and not str_end then
                                                  write(file_line, str(i));
                                                  line_length := line_length + 1;
                                  
                                          -- Detects the string end
                                          elsif str(i) = nul then
                                                  str_end := true;
                                          
                                          -- Line feed detected. Writes the line in the file
                                          elsif str(i) = lf then                                                              
                                                  writeline(store_file, file_line);
                                                  line_length := 0;
                                          end if;
                                  end loop;
                          end if;
                                                                  
                  -- Receives from plasma the source processor, source task and writes them to the file
                  when S1 =>
                          write(file_line, ',');
                          write(file_line, conv_integer(control_data_out_debug(7 downto 0)));                                                             
                          line_length := line_length + 1;
                          
                          if line_length = 3 then 
                                  write(file_line, ',');
                                  CS <= S0;
                          else
                                  CS <= S1;
                          end if;
               end case;
        end if;
      end process;

end;
