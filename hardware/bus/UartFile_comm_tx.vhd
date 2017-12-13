--http://www.stefanvhdl.com/vhdl/html/file_write.html

library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;
use ieee.std_logic_textio.all;
use work.txt_util.all;
use std.textio.all;

entity UartFileC_tx is
	generic(
		log_file : string := "UNUSED"
	);
	port(
		reset	             : in std_logic;
    ctrl	             : in std_logic;
    taskid_dst         : in std_logic_vector(31 downto 0);
		taskid_src         : in std_logic_vector(31 downto 0);
		time_comm_start    : in std_logic_vector(31 downto 0);
		time_comm_fineshed : in std_logic_vector(31 downto 0);
    delta              : in std_logic_vector(31 downto 0);
    cycles             : in std_logic_vector(31 downto 0)
	);
	end;

architecture logic of UartFile_tx is 
begin
	process(ctrl,reset)
	file store_file : text open write_mode is log_file;
	variable file_line : line;
  begin
		if falling_edge(reset) then
			write(file_line,string'("Taskid Dst, Taskid Src, Start, Finished, DELTA , Cycles"));
			writeline(store_file, file_line);
			write(file_line,string'("0,0,0,0,0,0"));
   		writeline(store_file, file_line);
		end if;
		if ctrl = '1' then
      write(file_line, str(to_integer(unsigned(taskid_dst)))&","&str(to_integer(unsigned(taskid_src)))&","&str(to_integer(unsigned(time_comm_start)+9))&"5,"&str(to_integer(unsigned(time_comm_fineshed)+9))&"5,"&str(to_integer(unsigned(delta)+9))&"5,"&str(to_integer(unsigned(cycles))));
   		writeline(store_file, file_line);
		end if;
	end process;
end; 
