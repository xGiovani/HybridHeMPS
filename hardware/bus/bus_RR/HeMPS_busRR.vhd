library IEEE;
use ieee.std_logic_1164.all;
use IEEE.math_real.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.HeMPS_PKG.all;
use work.HeMPS_defaults.all;

entity HeMPS_busRR is
        generic (
            mlite_description   : string := "RTL";
            router_description  : string := "RTL";
            ram_description     : string := "RTL"
        );
        port (
                clock                          : in    std_logic;
                reset                          : in    std_logic;
                -- Tasks repository interface
                mem_addr                       : out   std_logic_vector(29 downto 0);
                data_read                      : in    std_logic_vector(31 downto 0);
                -- Debug interface
                write_enable_debug             : out   std_logic;
                data_out_debug                 : out   std_logic_vector(31 downto 0);
                busy_debug                     : in    std_logic;
                --Dynamic Insertion of Applications
                ack_app                        : out  std_logic;
                req_app                        : in  std_logic_vector(31 downto 0)
        );

end entity HeMPS_busRR;

architecture HeMPS_busRR of HeMPS_busRR is  
	-- Control Bus
	signal tx           : std_logic_vector(NUMBER_PE_BUS-1 downto 0);
        signal data_out     : arrayNregflitPE;
        signal credit_o     : std_logic_vector(NUMBER_PE_BUS-1 downto 0);
	-- Data Bus
	signal bus_rx       : std_logic_vector(NUMBER_PE_BUS-1 downto 0);
	signal bus_data     : regflit;
	signal bus_credit   : std_logic;
	-- Bus Arb Interface
        signal tx_addr      : arrayNregflitPE;
	signal using_bus    : std_logic_vector(NUMBER_PE_BUS-1 downto 0) := (others=>'0');
	signal request      : std_logic_vector(NUMBER_PE_BUS-1 downto 0) := (others=>'0');
	signal grant        : std_logic_vector(NUMBER_PE_BUS-1 downto 0) := (others=>'0');
	signal grant_out,grant_out2    : std_logic_vector(NUMBER_PE_BUS-1 downto 0) := (others=>'0');
	signal tmp          : std_logic_vector(NUMBER_PE_BUS-1 downto 0) := (others=>'0');
	signal ack_o        : std_logic_vector(NUMBER_PE_BUS-1 downto 0) := (others=>'0');
	signal ack          : std_logic := '0';

begin
        proc: for i in 0 to NUMBER_PE_BUS-1 generate

                mas:if (kernel_type(i) = "mas") generate     
                        master: entity work.plasma_busRR
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
				-- Bus Arb
				using_bus       => using_bus(i),
				request         => request(i),
				ack             => ack_o(i),
				grant           => grant(i)
                        );         
                end generate mas;   

                loc:if (kernel_type(i) = "loc" ) generate
                        slave: entity work.plasma_busRR
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

                                write_enable_debug  => open,
                                data_out_debug      => open,
                                busy_debug          => '0',
                                
                                ack_app        => open,
                                req_app        => (others=>'0'),
				-- Bus Arb
				ack             => ack_o(i),
				using_bus       => using_bus(i),
				request         => request(i),
				grant           => grant(i)
                        );
		end generate loc;

                slav:if (kernel_type(i) = "sla" ) generate
                        slave: entity work.plasma_busRR
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

                                write_enable_debug  => open,
                                data_out_debug      => open,
                                busy_debug          => '0',
                                
                                ack_app        => open,
                                req_app        => (others=>'0'),
				-- Bus Arb
				ack             => ack_o(i),
				using_bus       => using_bus(i),
				request         => request(i),
				grant           => grant(i)
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
		
	grant <= grant_out when using_bus = tmp else tmp;
	ack <= '0' when ack_o = tmp else '1';
	
	-- Round Robin Arbiter
	RR_ARBITER: entity work.rr_arbiter
		port map(
			clock    => clock,
			reset    => reset,
			ack      => ack,
			request  => request,
			grant    => grant_out
        );
		
end architecture HeMPS_busRR;
