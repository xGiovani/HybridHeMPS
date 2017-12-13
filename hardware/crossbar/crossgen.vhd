----------------------------------------------------------------------------------
-- Company: UFSM
-- Engineer: Julia Grando
-- 
-- Create Date:    15:25:32 04/30/2017 
-- Design Name: 
-- Module Name:    crossw2 - Behavioral 
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
library ieee;
use ieee.std_logic_1164.all;
use IEEE.math_real.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.HeMPS_PKG.all;
use work.HeMPS_defaults.all;

entity crossgen is
	generic(
		CrossbarID : integer := 0;
		NUMBER_PROC_CROSSBAR : integer := 2
	); 
    Port( 
	   clock    : in std_logic;
	   reset    : in std_logic;
	   data_in  : out arrayNregflit(0 to NUMBER_PROC_CROSSBAR);
           data_out : in  arrayNregflit(0 to NUMBER_PROC_CROSSBAR);
           tx       : in std_logic_vector(NUMBER_PROC_CROSSBAR downto 0);
	   rx 	    : out std_logic_vector(NUMBER_PROC_CROSSBAR downto 0);
	   credit_i : out std_logic_vector(NUMBER_PROC_CROSSBAR downto 0);
	   credit_o : in std_logic_vector(NUMBER_PROC_CROSSBAR downto 0);
           tx_addr  : in  arrayNregflit(0 to NUMBER_PROC_CROSSBAR);
	   grant    : out std_logic_vector(NUMBER_PROC_CROSSBAR downto 0);
	   request  : in std_logic_vector(NUMBER_PROC_CROSSBAR downto 0)
    );
end crossgen;

architecture STRUCT of crossgen is
	type array_NumProc is array(0 to NUMBER_PROC_CROSSBAR) of std_logic_vector(NUMBER_PROC_CROSSBAR downto 0);
	signal RQ, GR: array_NumProc;

	signal Proc_Addr: Proc_Addresses(0 to NUMBER_PROC_CROSSBAR);

	component BUS_ARB_GEN
		generic(
			NUMBER_PROC_CROSSBAR : integer := 2);
		port(
			reset : in STD_LOGIC;
			REQ   : in  STD_LOGIC_VECTOR(NUMBER_PROC_CROSSBAR downto 0);
			GRANT : out std_logic_vector(NUMBER_PROC_CROSSBAR downto 0));
	end component; 
		
begin
	-- Generate Crossbar Processors Addresses
	Proc_Addr <= Crossbar_Proc_Addr when NUMBER_CROSSBARS = 1 else 
		     Crossbar_Proc_Addrs(CrossbarID)(0 to NUMBER_PROC_CROSSBAR);

	-- Crossbar Arbiter
	ENB:for i in 0 to NUMBER_PROC_CROSSBAR generate
		GB:BUS_ARB_GEN 
			generic map(
				NUMBER_PROC_CROSSBAR => NUMBER_PROC_CROSSBAR)
 			port map(
				reset,
				RQ(i),
				GR(i));
	end generate;

	crossbar: process(all)
	variable toWrapper : std_logic := '0'; -- variable to indicate if the target element is a processor or the wrapper
	variable target, target_j : integer := 0;
	begin
	toWrapper := '1';
	for i in 0 to NUMBER_PROC_CROSSBAR loop
		for aux in 0 to NUMBER_PROC_CROSSBAR-1 loop
			if tx_addr(i)(15 downto 0)  = Proc_Addr(aux)(15 downto 0)  then
				target := aux;
				toWrapper := '0';
			end if;
		end loop;
		if toWrapper = '1' then
			target := NUMBER_PROC_CROSSBAR; -- Activate wrapper rx
		end if;
		rx(i) <= '0';
		grant(i) <= '0';
		toWrapper := '1';
		for j in 0 to NUMBER_PROC_CROSSBAR loop
			for aux in 0 to NUMBER_PROC_CROSSBAR-1 loop
				if tx_addr(j)(15 downto 0)  = Proc_Addr(aux)(15 downto 0)  then
					target_j := aux;
					toWrapper := '0';
				end if;
			end loop;
			if toWrapper = '1' then
				target_j := NUMBER_PROC_CROSSBAR; -- Activate wrapper rx
			end if;
			-- Handles Request
			 if request(i)='1' and tx_addr(i)(15 downto 0)  = Proc_Addr(j)(15 downto 0)  then
				 RQ(j)(i) <= '1';
			 elsif request(i)='1' and target = NUMBER_PROC_CROSSBAR then -- Crossbar Wrapper
				 RQ(NUMBER_PROC_CROSSBAR)(i) <= '1';
			 else
				 RQ(j)(i) <= '0';
			 end if;
			-- Data output
			if (i/=j and GR(j)(i) = '1') then
				data_in(j) <= data_out(i);
			end if;
			-- Activates Rx
			if tx(j)='1' and tx_addr(j)(15 downto 0)  = Proc_Addr(i)(15 downto 0)  then
				rx(i) <= '1';
			elsif tx(j)= '1' and target_j = NUMBER_PROC_CROSSBAR then -- Crossbar Wrapper
				rx(NUMBER_PROC_CROSSBAR) <= '1';
			--else
				--rx(i) <= '0';
			end if;
			-- Handles Credit
			if GR(j)(i) = '1' then
				grant(i) <= '1';
				credit_i(j) <= credit_o(i);
			--else
				--grant(i) <= '0';
			end if;
		end loop;
	end loop;
	end process crossbar;
end STRUCT; 


