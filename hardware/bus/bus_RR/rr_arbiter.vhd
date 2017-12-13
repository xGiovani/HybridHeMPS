-- http://www.krll.de/portfolio/vhdl-round-robin-arbiter/
-- Round Robin Arbiter
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.HeMPS_defaults.all;

entity rr_arbiter is
	generic(
		NUMBER_PROC_BUS : integer := 2
	);
	port (
		clock   : in  std_logic;
		reset   : in  std_logic;
		ack     : in  std_logic;
		request : in  std_logic_vector(NUMBER_PROC_BUS downto 0);
		grant   : out std_logic_vector(NUMBER_PROC_BUS downto 0)
	);
end;

architecture rr_arbiter of rr_arbiter is
	signal grant_q  : std_logic_vector(NUMBER_PROC_BUS downto 0) := (others => '0');
	signal pre_req  : std_logic_vector(NUMBER_PROC_BUS downto 0) := (others => '0');
	signal sel_gnt  : std_logic_vector(NUMBER_PROC_BUS downto 0) := (others => '0');
	signal isol_lsb : std_logic_vector(NUMBER_PROC_BUS downto 0) := (others => '0');
	signal mask_pre : std_logic_vector(NUMBER_PROC_BUS downto 0) := (others => '0');
	signal win      : std_logic_vector(NUMBER_PROC_BUS downto 0) := (others => '0');
begin
	grant <= grant_q;
	mask_pre <= request and not (std_logic_vector(unsigned(pre_req) - 1) or pre_req); -- Mask off previous winners
	sel_gnt  <= mask_pre and std_logic_vector(unsigned(not(mask_pre)) + 1);           -- Select new winner
	isol_lsb <= request and std_logic_vector(unsigned(not(request)) + 1);             -- Isolate least significant set bit.
	win <= sel_gnt when mask_pre /= (NUMBER_PROC_BUS downto 0 => '0') else isol_lsb;

	process (clock, reset)
	begin
	if reset = '1' then
		pre_req <= (others => '0');
		grant_q <= (others => '0');
	elsif clock'event and clock='1' then
		grant_q <= grant_q;
		pre_req <= pre_req;
		if grant_q = (NUMBER_PROC_BUS downto 0 => '0') or ack = '1' then
			if win /= (NUMBER_PROC_BUS downto 0 => '0') then
				pre_req <= win;
			end if;
			grant_q <= win;
		end if;
	end if;
	end process;

end rr_arbiter;
