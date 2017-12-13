---------------------------------------------
-- Implementation of Daisy Chain Arbiter
---------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use work.HeMPS_defaults.all;

entity daisy_chain is
	port(	  
	    request   : in std_logic_vector(NUMBER_PE_BUS-1 downto 0);
	    grant     : out std_logic;
	    using_bus : in std_logic_vector(NUMBER_PE_BUS-1 downto 0)
	);
end entity daisy_chain;

architecture arbiter of daisy_chain is
begin
	-- Grant Signal <= '1' when someone requested the bus and the same is not been used
	process(request, using_bus)
	begin
		if request /= (NUMBER_PE_BUS-1 downto 0 => '0') and using_bus = (NUMBER_PE_BUS-1 downto 0 => '0') then 
			grant <= '1';
		else 
			grant <= '0';
		end if;
	end process;
  
end architecture arbiter;
