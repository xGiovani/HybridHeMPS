------------------------------------------------------------------------------------------------
--
--  DISTRIBUTED HEMPS  - version 5.0
--
--  Research group: GAPH-PUCRS    -    contact   fernando.moraes@pucrs.br
--
--  Distribution:  September 2013
--
--  Source name:  test_benchRR.vhd
--
--  Brief description:  Test bench.
--
------------------------------------------------------------------------------------------------

library IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use std.textio.all;

use work.memory_pack.all;
use work.HeMPS_PKG.all;

--! @file
--! @ingroup vhdl_group
--! @{
--! @}

--! @brief entity brief description
 
--! @detailed detailed description
entity test_benchRR is
        generic(
                  log_file            : string := "output_master.txt"; --! port description
                  MAX_LINE_SIZE       : integer := 231;                --! port description
                  mlite_description   : string := "RTL";
                  ram_description     : string := "RTL";
                  router_description  : string := "RTL"
        );
end;

architecture test_benchRR of test_benchRR is
        signal clock            : std_logic := '0';
        signal clock_200        : std_logic := '1';
        signal reset            : std_logic;

        signal control_write_enable_debug      : std_logic;
        signal control_data_out_debug          : std_logic_vector(31 downto 0);
        signal control_busy_debug              : std_logic;

        signal control_hemps_addr              : std_logic_vector(29 downto 0);
        signal control_hemps_data              : std_logic_vector(31 downto 0);

        type state is (LER, WAIT_DDR, WR_HEMPS, START);
        signal EA                                              : state;
        
        type state2 is (S0, S1);
        signal CS: state2;
        
        signal counter                                                  : integer :=0;
        
        signal ack_app                 : std_logic;
        signal req_app                 : std_logic_vector(31 downto 0);
        signal debug                   :  integer;
        
begin

       reset <= '1', '0' after 100 ns;

       -- 100 MHz
       clock <= not clock after 5 ns;
       
       -- 200 MHz
       clock_200 <= not clock_200 after 1.25 ns;

       --
       --  access the repository considering that the HeMPS and the external memory are running at different frequencies
       --
       -- process(clock_200, reset)
       -- begin
       --         if reset = '1' then
       --                 control_hemps_data_valid <= '0';
       --                 EA <= START;
       --         elsif rising_edge(clock_200) then
       --                 case EA is
       --                         when START  =>   if control_hemps_read_req_ant = '1' then
       --                                                 EA <= LER;
       --                                         else
       --                                                 EA <= START;
       --                                         end if;
                                               
       --                         when LER     =>  control_hemps_data_valid <= '0';
       --                                          EA <= WAIT_DDR;
                                                
       --                         when WAIT_DDR => EA <= WR_HEMPS;
                               
       --                         when WR_HEMPS =>  control_hemps_data_valid <= '1';
       --                                           if control_hemps_read_req_ant = '0' then
       --                                                   EA <= START;
       --                                           else
       --                                                   EA <= WR_HEMPS;
       --                                           end if;
       --                 end case;
       --                 control_hemps_read_req_ant <= control_hemps_read_req;
       --         end if;
       -- end process;
       
       control_hemps_data <= memory(CONV_INTEGER(control_hemps_addr(23 downto 2)));
       debug <= (CONV_INTEGER(control_hemps_addr(23 downto 2)));
       control_busy_debug <= '0';

       --
       --  HeMPS instantiation 
       --
       HeMPS: entity work.HeMPS_busRR
        generic map(
                mlite_description               => mlite_description,
                ram_description                 => ram_description,
                router_description              => router_description
        )
        port map(
                clock                   => clock,
                reset                   => reset,
                --repository
                mem_addr                => control_hemps_addr,
                data_read               => control_hemps_data,
                --debug
                write_enable_debug              => control_write_enable_debug,
                data_out_debug                  => control_data_out_debug,
                busy_debug                              => control_busy_debug,
                ack_app        => ack_app,
                req_app        => req_app     
        );
        
        
        
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

end test_benchRR;
