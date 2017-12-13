---------------------------------------------
-- Implementation of HeMPS Bus
---------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.HeMPS_defaults.all;
use work.HeMPS_PKG.all;

entity bus_ctrl_hy is
	generic(
		BusID           : integer := 0;
		NUMBER_PROC_BUS : integer
	);
	port(	 
		-- Input to bus
		tx         : in std_logic_vector(NUMBER_PROC_BUS downto 0);
		data_out   : in arrayNregflit(0 to NUMBER_PROC_BUS);
		credit_o   : in std_logic_vector(NUMBER_PROC_BUS downto 0);
		-- Bus Data to processors
		bus_data   : out regflit;
		bus_rx     : out std_logic_vector(NUMBER_PROC_BUS downto 0);
		bus_credit : out std_logic;
		-- Control Signals
		using_bus  : in std_logic_vector(NUMBER_PROC_BUS downto 0);
		tx_addr    : in arrayNregflit(0 to NUMBER_PROC_BUS)
	);
end bus_ctrl_hy;

architecture bus_ctrl_hy of bus_ctrl_hy is
	signal source, target: integer range NUMBER_PROC_BUS downto 0;
	signal tmp: UNSIGNED(NUMBER_PROC_BUS downto 0) := (others=>'0');
	signal Proc_Addr: Proc_Addresses(0 to NUMBER_PROC_BUS-1);
begin
	-- Processors's Addresses 
	Proc_Addr <= Bus_Proc_Addr when NUMBER_BUSES = 1 else 
		     Bus_Proc_Addrs(BusID)(0 to NUMBER_PROC_BUS-1);

	-- Data from source processor
	bus_data <= data_out(source);
	-- Source processor receives credit from target processor
	bus_credit <= credit_o(target);

	-- Source/Target processor
	process(using_bus)
	begin
	-- Source processor
	for i in 0 to NUMBER_PROC_BUS loop
		if using_bus(i) = '1' then
			source <= i;
			exit;
		end if;
	end loop;
	end process;

	tmp(0) <= '1';
	-- Activate the correct rx
	bus_rx <= (others=>'0') when tx = (NUMBER_PROC_BUS downto 0 => '0') else std_logic_vector(tmp sll target);

	--Targer Processor
	process(tx_addr,source)
	variable toWrapper : std_logic := '0'; -- variable to indicate if the target element is a processor on the bus or the wrapper
	begin
	toWrapper := '1';
	for i in 0 to NUMBER_PROC_BUS-1 loop
		if tx_addr(source)(15 downto 0) = Proc_Addr(i)(15 downto 0)  then -- Compare the first flit with the proc. addresses on this bus
			target <= i;
			toWrapper := '0';
		end if;
	end loop;
		if toWrapper = '1' then
			target <= NUMBER_PROC_BUS; -- Activate wrapper rx
		end if;
	end process;

end bus_ctrl_hy;
