library IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.HeMPS_PKG.all;
use work.HeMPS_defaults.all;

entity HeMPS_busDC is
        generic (
            mlite_description   : string := "RTL";
            router_description  : string := "RTL";
            ram_description     : string := "RTL"
        );
        port (
                clock                            : in    std_logic;
                reset                            : in    std_logic;
                -- Tasks repository interface
                mem_addr                         : out   std_logic_vector(29 downto 0);
                data_read                        : in    std_logic_vector(31 downto 0);
                -- Debug interface
                write_enable_debug              : out   std_logic;
                data_out_debug                  : out   std_logic_vector(31 downto 0);
                busy_debug                      : in    std_logic;
                
                ack_app                        : out  std_logic;
                req_app                        : in  std_logic_vector(31 downto 0)
        );

end entity HeMPS_busDC;

architecture HeMPS_busDC of HeMPS_busDC is  

        signal tx           : std_logic_vector(NUMBER_PROCESSORS_BUS-1 downto 0);
        signal data_out     : arrayNregflit;
        signal credit_o     : std_logic_vector(NUMBER_PROCESSORS_BUS-1 downto 0);
	-- Bus Data/Control
        signal bus_rx       : std_logic_vector(NUMBER_PROCESSORS_BUS-1 downto 0);
        signal bus_data     : regflit;
        signal bus_credit   : std_logic;
	-- Bus Arbiter Interface
	signal grant_out    : std_logic_vector(NUMBER_PROCESSORS_BUS-1 downto 0);
	signal request      : std_logic_vector(NUMBER_PROCESSORS_BUS-1 downto 0);
	signal using_bus    : std_logic_vector(NUMBER_PROCESSORS_BUS-1 downto 0);
	signal grant        : std_logic;
	signal tx_addr      : arrayNregflit;
	signal bus_busy     : std_logic := '0';
	signal multi_req    : std_logic_vector(NUMBER_PROCESSORS_BUS-1 downto 0) := (others=>'0');

begin

	-- More than one request simultaneously counter
	bus_busy <= '0' when using_bus = (NUMBER_PROCESSORS_BUS-1 downto 0 => '0') else '1';

	process(bus_busy, request)
	variable counter_req: integer;
	begin
		counter_req := 0;
		for i in 0 to NUMBER_PROCESSORS_BUS-1 loop
			if request(i) = '1' then
				counter_req := counter_req + 1;
			end if;
		end loop;
		if falling_edge(bus_busy) and counter_req > 1 then
			multi_req <= multi_req + 1; 
		end if;
	end process;
	
        proc: for i in 0 to NUMBER_PROCESSORS_BUS-1 generate
                mas:if (kernel_type(i) = "mas") generate     
                        master: entity work.plasma_busDC
                        generic map (
                                memory_type             => "TRI",
                                router_address          => RouterAddress(i),
                                mlite_description       => mlite_description,
                                ram_description         => ram_description,
				                        log_file_tx             => log_filename_tx(i),
                                is_master               => '1'
                                )
                        port map(
                                address_sc      => RouterAddress(i),
                                clock           => clock,
                                reset           => reset,

                                tx              => tx(i),
                                data_out        => data_out(i),
                                credit_i        => bus_credit,
				tx_addr         => tx_addr(i),
                                rx              => bus_rx(i),
                                data_in         => bus_data,
                                credit_o        => credit_o(i),

                                address         => mem_addr,
                                data_read       => data_read,

                                write_enable_debug  => write_enable_debug,
                                data_out_debug      => data_out_debug,
                                busy_debug          => busy_debug,
                                
                                ack_app        => ack_app,
                                req_app        => req_app,

				grant_in       => grant,
				grant_out      => grant_out(i),
				request        => request(i),
				using_bus      => using_bus(i)
                        );         
                end generate mas;   

                loc:if (kernel_type(i) = "loc" ) generate
                        slave: entity work.plasma_busDC
                        generic map (
                                memory_type             => "TRI",
                                router_address          => RouterAddress(i),
                                mlite_description       => mlite_description,
                                ram_description         => ram_description,
                                log_file                => log_filename(i),
				log_file_tx             => log_filename_tx(i),
                                is_master               => '1'
                                )
                        port map(
                                address_sc      => RouterAddress(i),
                                clock           => clock,
                                reset           => reset,
				--
                                tx              => tx(i),
                                data_out        => data_out(i),
                                credit_i        => bus_credit,
				tx_addr         => tx_addr(i),
                                rx              => bus_rx(i),
                                data_in         => bus_data,
                                credit_o        => credit_o(i),

                                address         => open,
                                data_read       => (others => '0'),

                                write_enable_debug      => open,
                                data_out_debug          => open,
                                busy_debug              => '0',
                                
                                ack_app        => open,
                                req_app        => (others=>'0'),

				grant_in       => grant_out(i-1),
				grant_out      => grant_out(i),
				request        => request(i),
				using_bus      => using_bus(i)
                        );
		end generate loc;

                slav:if (kernel_type(i) = "sla" ) generate
                        slave: entity work.plasma_busDC
                        generic map (
                                memory_type             => "TRI",
                                router_address          => RouterAddress(i),
                                mlite_description       => mlite_description,
                                ram_description         => ram_description,
                                log_file                => log_filename(i),
				log_file_tx             => log_filename_tx(i),
                                is_master               => '0'
                                )
                        port map(
                                address_sc      => RouterAddress(i),
                                clock           => clock,
                                reset           => reset,
				--
                                tx              => tx(i),
                                data_out        => data_out(i),
                                credit_i        => bus_credit,
				tx_addr         => tx_addr(i),
                                rx              => bus_rx(i),
                                data_in         => bus_data,
                                credit_o        => credit_o(i),

                                address         => open,
                                data_read       => (others => '0'),

                                write_enable_debug      => open,
                                data_out_debug          => open,
                                busy_debug              => '0',
                                
                                ack_app        => open,
                                req_app        => (others=>'0'),

				grant_in       => grant_out(i-1),
				grant_out      => grant_out(i),
				request        => request(i),
				using_bus      => using_bus(i)
                        );
                end generate slav;
	end generate proc;

	-- Bus Interface -----------------------
	BUS_CTRL: entity work.bus_ctrl
		port map(
			-- Input to bus
			tx         => tx,
			data_out   => data_out,
			credit_o   => credit_o,
			-- Output to processors
			bus_data   => bus_data,
			bus_rx	   => bus_rx,
			bus_credit => bus_credit,
			-- Control which processor is using the bus
			using_bus  => using_bus,
			tx_addr    => tx_addr
		);

	-- Bus Arbiter ---------
	DAISY_CHAIN: entity work.daisy_chain
		port map(
			request   => request,
			grant	  => grant,
			using_bus => using_bus
		);      
           
end architecture HeMPS_busDC;
