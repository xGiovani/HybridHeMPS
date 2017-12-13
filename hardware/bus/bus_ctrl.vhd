---------------------------------------------
-- Implementation of HeMPS Bus
---------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.HeMPS_defaults.all;

entity bus_ctrl is
	port(	 
		-- Input to bus
		tx         : in std_logic_vector(NUMBER_PROCESSORS_BUS-1 downto 0);
		data_out   : in arrayNregflit;
		credit_o   : in std_logic_vector(NUMBER_PROCESSORS_BUS-1 downto 0);
		-- Bus Data to processors
		bus_data   : out regflit;
		bus_rx     : out std_logic_vector(NUMBER_PROCESSORS_BUS-1 downto 0);
		bus_credit : out std_logic;
		-- Control Signals
		using_bus  : in std_logic_vector(NUMBER_PROCESSORS_BUS-1 downto 0);
		tx_addr    : in arrayNregflit
	);
end bus_ctrl;

architecture bus_ctrl of bus_ctrl is
	signal source, target: integer range NUMBER_PROCESSORS_BUS-1 downto 0;
	signal target4: integer range 3 downto 0;
  signal target6: integer range 5 downto 0;
	signal target9: integer range 8 downto 0;
	signal target12: integer range 11 downto 0;
	signal target16: integer range 15 downto 0;


	signal tmp: UNSIGNED(NUMBER_PROCESSORS_BUS-1 downto 0) := (0 => '1', others=>'0');
begin

	bus_data <= data_out(source);
	bus_credit <= credit_o(target);

	-- Source processor
	process(using_bus)
	begin
	for i in 0 to NUMBER_PROCESSORS_BUS-1 loop
		if using_bus(i) = '1' then
			source <= i;
			exit;
		end if;
	end loop;
	end process;

	bus_rx <= (others=>'0') when tx = (NUMBER_PROCESSORS_BUS-1 downto 0 => '0') else std_logic_vector(tmp sll target);
	
	target <= target4 when NUMBER_PROCESSORS_BUS = 4 else
      target6 when NUMBER_PROCESSORS_BUS = 6 else
		  target9 when NUMBER_PROCESSORS_BUS = 9 else
      target12 when NUMBER_PROCESSORS_BUS = 12 else
		  target16; -- 16

---- TARGETS ---------------------------------------------------
	-- HeMPS 2x2
	target4 <= 0 when tx_addr(source) = x"00000000" else
	 	   1 when tx_addr(source) = x"00000100" else
		   2 when tx_addr(source) = x"00000001" else
		   3; -- x"000000101
  -- HeMPS 3x2
	target6 <= 0 when tx_addr(source) = x"00000000" else
	     1 when tx_addr(source) = x"00000100" else
		   2 when tx_addr(source) = x"00000200" else
		   3 when tx_addr(source) = x"00000001" else
		   4 when tx_addr(source) = x"00000101" else
		   5 ;

	-- HeMPS 3x3
	target9 <= 0 when tx_addr(source) = x"00000000" else
	           1 when tx_addr(source) = x"00000100" else
		   2 when tx_addr(source) = x"00000200" else
		   3 when tx_addr(source) = x"00000001" else
		   4 when tx_addr(source) = x"00000101" else
		   5 when tx_addr(source) = x"00000201" else
		   6 when tx_addr(source) = x"00000002" else
		   7 when tx_addr(source) = x"00000102" else
		   8; --"00000202"
  -- HeMPS 3x4
	target12 <= 0 when tx_addr(source) = x"00000000" else
		    1 when tx_addr(source) = x"00000100" else
		    2 when tx_addr(source) = x"00000200" else
		    3 when tx_addr(source) = x"00000300" else
		    4 when tx_addr(source) = x"00000001" else
		    5 when tx_addr(source) = x"00000101" else
		    6 when tx_addr(source) = x"00000201" else
		    7 when tx_addr(source) = x"00000301" else
		    8 when tx_addr(source) = x"00000002" else
		    9 when tx_addr(source) = x"00000102" else
		    10 when tx_addr(source) = x"00000202" else
		    11 ;

	-- HeMPS 4x4
	target16 <= 0 when tx_addr(source) = x"00000000" else
		    1 when tx_addr(source) = x"00000100" else
		    2 when tx_addr(source) = x"00000200" else
		    3 when tx_addr(source) = x"00000300" else
		    4 when tx_addr(source) = x"00000001" else
		    5 when tx_addr(source) = x"00000101" else
		    6 when tx_addr(source) = x"00000201" else
		    7 when tx_addr(source) = x"00000301" else
		    8 when tx_addr(source) = x"00000002" else
		    9 when tx_addr(source) = x"00000102" else
		    10 when tx_addr(source) = x"00000202" else
		    11 when tx_addr(source) = x"00000302" else
		    12 when tx_addr(source) = x"00000003" else
		    13 when tx_addr(source) = x"00000103" else
		    14 when tx_addr(source) = x"00000203" else
		    15; -- x"00000303"

end bus_ctrl;

