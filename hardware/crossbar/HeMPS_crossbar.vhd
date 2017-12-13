library IEEE;
use ieee.std_logic_1164.all;
use IEEE.math_real.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.HeMPS_PKG.all;
use work.HeMPS_defaults.all;

entity HeMPS_crossbar is
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

end entity HeMPS_crossbar;

architecture HeMPS_crossbar of HeMPS_crossbar is  
	-- Control Bus
	signal tx             : std_logic_vector(NUMBER_PROCESSORS-1 downto 0) := (others=>'0');
	signal credit_i       : std_logic_vector(NUMBER_PROCESSORS-1 downto 0) := (others=>'0');
	signal credit_o       : std_logic_vector(NUMBER_PROCESSORS-1 downto 0) := (others=>'0');
	signal bus_rx	      : std_logic_vector(NUMBER_PROCESSORS-1 downto 0) := (others=>'0');
        signal data_out       : arrayNregflit := (others=>(others=>'0'));
        signal data_in        : arrayNregflit := (others=>(others=>'0'));
	-- Crossbar Arb Interface
        signal tx_addr        : arrayNregflit := (others=>(others=>'0'));
	signal tx_change_flit : std_logic_vector(NUMBER_PROCESSORS-1 downto 0) := (others=>'0');
	signal grant          : std_logic_vector(NUMBER_PROCESSORS-1 downto 0) := (others=>'0');
	signal request        : std_logic_vector(NUMBER_PROCESSORS-1 downto 0) := (others=>'0');

begin
        proc: for i in 0 to (NUMBER_PROCESSORS-1) generate

                mas:if (kernel_type(i) = "mas") generate     
                        master: entity work.plasma_cross
                        generic map (
                                memory_type             => "TRI",
                                router_address          => RouterAddress(i),
                                mlite_description       => mlite_description,
                                ram_description         => ram_description,
                                is_master               => '1'
                                )
                        port map(
				address_sc      => RouterAddress(i),
                                clock           => clock,
                                reset           => reset,

                                tx              => tx(i),
                                data_out        => data_out(i),
                                credit_i        => credit_i(i),
				tx_addr         => tx_addr(i),
                                rx              => bus_rx(i),
                                data_in         => data_in(i),
                                credit_o        => credit_o(i),
				tx_change_flit  => tx_change_flit(i),
				request         => request(i),
				grant           => grant(i),

                                address         => mem_addr,
                                data_read       => data_read,

                                write_enable_debug  => write_enable_debug,
                                data_out_debug      => data_out_debug,
                                busy_debug          => busy_debug,
                                
                                ack_app        => ack_app,
                                req_app        => req_app

                        );         
                end generate mas;   

                loc:if (kernel_type(i) = "loc" ) generate
                        slave: entity work.plasma_cross
                        generic map (
                                memory_type             => "TRI",
                                router_address          => RouterAddress(i),
                                mlite_description       => mlite_description,
                                ram_description         => ram_description,
                                log_file                => log_filename(i),
                                is_master               => '1'
                                )
                        port map(
                                address_sc      => RouterAddress(i),
                                clock           => clock,
                                reset           => reset,
				--
                                tx              => tx(i),
                                data_out        => data_out(i),
                                credit_i        => credit_i(i),
				tx_addr         => tx_addr(i),
                                rx              => bus_rx(i),
                                data_in         => data_in(i),
                                credit_o        => credit_o(i),
				tx_change_flit  => tx_change_flit(i),
				request         => request(i),
				grant           => grant(i),

                                address         => open,
                                data_read       => (others => '0'),

                                write_enable_debug  => open,
                                data_out_debug      => open,
                                busy_debug          => '0',
                                
                                ack_app        => open,
                                req_app        => (others=>'0')
                        );
		end generate loc;

                slav:if (kernel_type(i) = "sla" ) generate
                        slave: entity work.plasma_cross
                        generic map (
                                memory_type             => "TRI",
                                router_address          => RouterAddress(i),
                                mlite_description       => mlite_description,
                                ram_description         => ram_description,
                                log_file                => log_filename(i),
                                is_master               => '0'
                                )
                        port map(
                                address_sc      => RouterAddress(i),
                                clock           => clock,
                                reset           => reset,
				--
                                tx              => tx(i),
                                data_out        => data_out(i),
                                credit_i        => credit_i(i),
				tx_addr         => tx_addr(i),
                                rx              => bus_rx(i),
                                data_in         => data_in(i),
                                credit_o        => credit_o(i),
				tx_change_flit  => tx_change_flit(i),
				request         => request(i),
				grant           => grant(i),

                                address         => open,
                                data_read       => (others => '0'),

                                write_enable_debug  => open,
                                data_out_debug      => open,
                                busy_debug          => '0',
                                
                                ack_app        => open,
                                req_app        => (others=>'0')
                        );
                end generate slav;
	end generate proc;

	-- Cross Interface -----------------------
	CROSSGEN: entity work.crossgen
		port map(
			clock    => clock,
			reset    => reset,
            		data_in  => data_in,
			data_out => data_out,
            		tx       => tx,
			rx 	 => bus_rx,
			credit_o => credit_o,
			credit_i => credit_i,
           		tx_addr  => tx_addr,
			grant  	 => grant,
			request	 => request
		);
		
end architecture HeMPS_crossbar;
