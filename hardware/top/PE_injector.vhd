library ieee;
use work.HeMPS_defaults.all;
use ieee.std_logic_1164.all;

entity PE_injector is
	generic(
		source_address          : std_logic_vector(15 downto 0):= (others=>'0');
		target_address		: std_logic_vector(15 downto 0):= (others=>'0'));
	port(
		clock                   : in  std_logic;
		reset                   : in  std_logic;
		-- Router Local port Connection
		clock_tx                : out std_logic;
		tx                      : out std_logic;
		data_out                : out regflit;
		credit_i                : in std_logic;
		clock_rx                : in std_logic;
		rx			: in std_logic;
		data_in			: in regflit;
		credit_o		: out std_logic);
end PE_injector;

architecture PE_injector of PE_injector is
	signal header_inj, service_inj: regflit;
	type Estado IS (SendHeader, SendService, SendPayload, SWait, SendSize, SCredit); -- Tipo Enumerado para -- definir os Estados
	signal S, S_ant : Estado;
	signal inj_clk	   : std_logic;
begin

	clock_tx <= clock;

	credit_o <= '1';

	Flit_Inj:process(clock, reset)
	variable countPL: integer range 0 to 500;
	begin
		if reset = '1' then
			countPL := 0;
			S <= SWait;
			S_ant <= Swait;
			tx <= '0';
			data_out <= x"00000000";
		elsif rising_edge(clock) then
			if credit_i = '0' and S /= SCredit then
				S_ant <= S;
				S <= SCredit; 
			else
				case S is
				when SendHeader =>
					data_out <= header_inj;
					tx <= '1';
					S <= SendSize;
				when SendService =>				
					data_out <= service_inj;
					tx <= '1';
					S <= SendPayload;
				when SendSize =>
					data_out <= x"00000100";
					tx <= '1';
					S <= SendService;
				when SendPayload =>
					data_out <= x"01020304";
					tx <= '1';
					countPL := countPL+1;
					if countPL = 255 then
						countPL := 0;
						S <= SWait;
					end if;
				when SWait =>
					countPL := 0;
					tx <= '0';
					if inj_clk = '1' then
						S <= SendHeader;
					end if;
				when SCredit =>
					tx <= '0';
					if credit_i = '1' and inj_clk = '1' then
						S <= S_ant;
					end if;
				end case;
			end if;
		end if;
	end process Flit_Inj;

	service_inj <= x"FFFF" & source_address;
	header_inj <= x"0000" & target_address;
		
	Count:process(clock, reset)
	variable count: integer range 0 to 100000;
	begin
		if reset = '1' then
			count := 0;
		end if;
		if rising_edge(clock) then
			if count /= 90 then  
				count := count +1;
				inj_clk <= '0';
			else
				inj_clk <= '1';
				count := 0;
			end if;
		
		end if;
	end process Count;
	
end architecture PE_injector;
