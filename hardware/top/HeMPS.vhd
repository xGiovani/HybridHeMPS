------------------------------------------------------------------------------------------------
--
--  DISTRIBUTED HEMPS  - version 5.0
--
--  Research group: GAPH-PUCRS    -    contact   fernando.moraes@pucrs.br
--
--  Distribution:  September 2013
--
--  Source name:  HeMPS.vhd
--
--  Brief description:  NoC generation
--
------------------------------------------------------------------------------------------------

library IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.HeMPS_PKG.all;
use work.HeMPS_defaults.all;

entity HeMPS is
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
end;

architecture HeMPS of HeMPS is  

        -- Interconnection signals 
        type txNport is array(NUMBER_PROCESSORS-1 downto 0) of std_logic_vector(3 downto 0);
        signal tx       : txNPORT;
        type rxNport is array(NUMBER_PROCESSORS-1 downto 0) of std_logic_vector(3 downto 0);
        signal rx       : rxNPORT;
        type clock_rxNport is array(NUMBER_PROCESSORS-1 downto 0) of std_logic_vector(3 downto 0);
        signal clock_rx : clock_rxNPORT;
        type clock_txNport is array(NUMBER_PROCESSORS-1 downto 0) of std_logic_vector(3 downto 0);
        signal clock_tx : clock_txNPORT;
        type credit_iNport is array(NUMBER_PROCESSORS-1 downto 0) of std_logic_vector(3 downto 0);
        signal credit_i : credit_iNPORT;
        type credit_oNport is array(NUMBER_PROCESSORS-1 downto 0) of std_logic_vector(3 downto 0);
        signal credit_o : credit_oNPORT;
        type data_inNport is array(NUMBER_PROCESSORS-1 downto 0) of arrayNPORT_1_regflit;
        signal data_in  : data_inNPORT;
        type data_outNport is array(NUMBER_PROCESSORS-1 downto 0) of arrayNPORT_1_regflit;
        signal data_out : data_outNPORT;
                
        signal   address_router : std_logic_vector(7 downto 0);
        
        type router_position is array(NUMBER_PROCESSORS-1 downto 0) of integer range 0 to TR;
        signal position : router_position;

	type array_addr is array (0 to NUMBER_PROCESSORS-1) of regmetadeflit;
	signal addr : array_addr;

        begin
        
        core_type_gen:   for i in 0 to NUMBER_PROCESSORS-1 generate
                position(i) <= RouterPosition(i);
        end generate core_type_gen;

	ProcAddr: for i in 0 to NUMBER_PROCESSORS-1 generate
		addr(i) <= RouterAddress(i);
	end generate ProcAddr;
        
        
        proc: for i in 0 to NUMBER_PROCESSORS-1 generate
                
                mas:if (kernel_type(i) = "mas") generate     
                        master: entity work.processing_element
                        generic map (
                                memory_type             => "TRI",
                                router_address          => RouterAddress(i),
                                core_type               => core_type(i),
                                mlite_description       => mlite_description,
                                router_description      => router_description,
                                ram_description         => ram_description,
                                is_master               => '1'
                                )
                        port map(
                                address_sc      => RouterAddress(i),
                                clock           => clock,
                                reset           => reset,
                                clock_tx        => clock_tx(i),
                                tx                      => tx(i),
                                data_out        => data_out(i),
                                credit_i        => credit_i(i),
                                clock_rx        => clock_rx(i),
                                rx                      => rx(i),
                                data_in         => data_in(i),
                                credit_o        => credit_o(i),

                                address                         => mem_addr,
                                data_read                       => data_read,

                                write_enable_debug      => write_enable_debug,
                                data_out_debug      => data_out_debug,
                                busy_debug                      => busy_debug,
                                
                                ack_app        => ack_app,
                                req_app        => req_app
                        );         
                end generate mas;   

                loc:if (kernel_type(i) = "loc" ) generate
                        slave: entity work.processing_element
                        generic map (
                                memory_type             => "TRI",
                                router_address          => RouterAddress(i),
                                core_type               => core_type(i),
                                mlite_description       => mlite_description,
                                router_description      => router_description,
                                ram_description         => ram_description,
                                log_file                => log_filename(i),
                                is_master               => '1'
                                )
                        port map(
                                address_sc      => RouterAddress(i),
                                clock           => clock,
                                reset           => reset,
                                clock_tx        => clock_tx(i),
                                tx                      => tx(i),
                                data_out        => data_out(i),
                                credit_i        => credit_i(i),
                                clock_rx        => clock_rx(i),
                                rx                      => rx(i),
                                data_in         => data_in(i),
                                credit_o        => credit_o(i),

                                address                         => open,
                                data_read                       => (others => '0'),

                                write_enable_debug      => open,
                                data_out_debug          => open,
                                busy_debug                      => '0',
                                
                                ack_app        => open,
                                req_app        => (others=>'0')
                        );
                end generate loc; 

                slav:if (kernel_type(i) = "sla" ) generate
                        slave: entity work.processing_element
                        generic map (
                                memory_type             => "TRI",
                                router_address          => RouterAddress(i),
                                core_type               => core_type(i),
                                mlite_description       => mlite_description,
                                router_description      => router_description,
                                ram_description         => ram_description,
                                log_file                => log_filename(i),
                                is_master               => '0'
                                )
                        port map(
                                address_sc      => RouterAddress(i),
                                clock           => clock,
                                reset           => reset,
                                clock_tx        => clock_tx(i),
                                tx                      => tx(i),
                                data_out        => data_out(i),
                                credit_i        => credit_i(i),
                                clock_rx        => clock_rx(i),
                                rx                      => rx(i),
                                data_in         => data_in(i),
                                credit_o        => credit_o(i),

                                address                         => open,
                                data_read                       => (others => '0'),

                                write_enable_debug      => open,
                                data_out_debug          => open,
                                busy_debug                      => '0',
                                
                                ack_app        => open,
                                req_app        => (others=>'0')
                        );
                end generate slav;          

                ------------------------------------------------------------------------------
                --- EAST PORT CONNECTIONS ----------------------------------------------------
                ------------------------------------------------------------------------------
                east_grounding: if RouterPosition(i) = BR or RouterPosition(i) = CRX or RouterPosition(i) = TR generate
                        rx(i)(EAST)             <= '0';
                        clock_rx(i)(EAST)       <= '0';
                        credit_i(i)(EAST)       <= '0';
                        data_in(i)(EAST)        <= (others => '0');
                end generate;

                east_connection: if RouterPosition(i) = BL or RouterPosition(i) = CL or RouterPosition(i) = TL  or RouterPosition(i) = BC or RouterPosition(i) = TC or RouterPosition(i) = CC generate
                        rx(i)(EAST)             <= tx(i+1)(WEST);
                        clock_rx(i)(EAST)       <= clock_tx(i+1)(WEST);
                        credit_i(i)(EAST)       <= credit_o(i+1)(WEST);
                        data_in(i)(EAST)        <= data_out(i+1)(WEST);
                end generate;

                ------------------------------------------------------------------------------
                --- WEST PORT CONNECTIONS ----------------------------------------------------
                ------------------------------------------------------------------------------
                west_grounding: if RouterPosition(i) = BL or RouterPosition(i) = CL or RouterPosition(i) = TL generate
                        rx(i)(WEST)             <= '0';
                        clock_rx(i)(WEST)       <= '0';
                        credit_i(i)(WEST)       <= '0';
                        data_in(i)(WEST)        <= (others => '0');
                end generate;

                west_connection: if (RouterPosition(i) = BR or RouterPosition(i) = CRX or RouterPosition(i) = TR or  RouterPosition(i) = BC or RouterPosition(i) = TC or RouterPosition(i) = CC) generate
                        rx(i)(WEST)             <= tx(i-1)(EAST);
                        clock_rx(i)(WEST)       <= clock_tx(i-1)(EAST);
                        credit_i(i)(WEST)       <= credit_o(i-1)(EAST);
                        data_in(i)(WEST)        <= data_out(i-1)(EAST);
                end generate;

                -------------------------------------------------------------------------------
                --- NORTH PORT CONNECTIONS ----------------------------------------------------
                -------------------------------------------------------------------------------
                north_grounding: if RouterPosition(i) = TL or RouterPosition(i) = TC or RouterPosition(i) = TR generate
                        rx(i)(NORTH)            <= '0';
                        clock_rx(i)(NORTH)      <= '0';
                        credit_i(i)(NORTH)      <= '0';
                        data_in(i)(NORTH)       <= (others => '0');
                end generate;

                north_connection: if RouterPosition(i) = BL or RouterPosition(i) = BC or RouterPosition(i) = BR or RouterPosition(i) = CL or RouterPosition(i) = CRX or RouterPosition(i) = CC generate
                        rx(i)(NORTH)            <= tx(i+NUMBER_PROCESSORS_X)(SOUTH);
                        clock_rx(i)(NORTH)      <= clock_tx(i+NUMBER_PROCESSORS_X)(SOUTH);
                        credit_i(i)(NORTH)      <= credit_o(i+NUMBER_PROCESSORS_X)(SOUTH);
                        data_in(i)(NORTH)       <= data_out(i+NUMBER_PROCESSORS_X)(SOUTH);
                end generate;

                --------------------------------------------------------------------------------
                --- SOUTH PORT CONNECTIONS -----------------------------------------------------
                ---------------------------------------------------------------------------
                south_grounding: if RouterPosition(i) = BL or RouterPosition(i) = BC or RouterPosition(i) = BR generate
                        rx(i)(SOUTH)            <= '0';
                        clock_rx(i)(SOUTH)      <= '0';
                        credit_i(i)(SOUTH)      <= '0';
                        data_in(i)(SOUTH)       <= (others => '0');
                end generate;

                south_connection: if RouterPosition(i) = TL or RouterPosition(i) = TC or RouterPosition(i) = TR or RouterPosition(i) = CL or RouterPosition(i) = CRX or RouterPosition(i) = CC generate
                        rx(i)(SOUTH)            <= tx(i-NUMBER_PROCESSORS_X)(NORTH);
                        clock_rx(i)(SOUTH)      <= clock_tx(i-NUMBER_PROCESSORS_X)(NORTH);
                        credit_i(i)(SOUTH)      <= credit_o(i-NUMBER_PROCESSORS_X)(NORTH);
                        data_in(i)(SOUTH)       <= data_out(i-NUMBER_PROCESSORS_X)(NORTH);
                end generate;
        end generate proc;
           
end architecture;
