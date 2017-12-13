----------------------------------------------------------------------------------
-- Company: UFSM
-- Engineer: Julia Grando
-- 
-- Create Date:    16:30:04 04/27/2017 
-- Design Name: 
-- Module Name:    BUS_ARB - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use ieee.std_logic_1164.all;
use IEEE.math_real.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.HeMPS_PKG.all;
use work.HeMPS_defaults.all;

entity bus_arb_gen is
    generic(
    	NUMBER_PROC_CROSSBAR : integer := 2);
    Port( 
        reset : in  STD_LOGIC;
	REQ : in  STD_LOGIC_VECTOR(NUMBER_PROC_CROSSBAR downto 0);
        GRANT : out  STD_LOGIC_VECTOR(NUMBER_PROC_CROSSBAR downto 0));
end bus_arb_gen;

architecture bus_arb_gen of bus_arb_gen is
begin
	process(REQ, reset)
	begin
	for i in 0 to NUMBER_PROC_CROSSBAR loop	
		if reset = '1' then
			GRANT <= (others=>'0');
			GRANT(0) <= '1';
		elsif REQ(i) = '0' then
			GRANT(i) <= '0';		
		elsif REQ(i) = '1' then
			GRANT <= (others=>'0');
			GRANT(i) <= '1';
			exit;
		end if;
	end loop;
	end process;
		
end bus_arb_gen;

