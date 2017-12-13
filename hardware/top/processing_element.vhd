------------------------------------------------------------------------------------------------
--
--  DISTRIBUTED HEMPS  - version 5.0
--
--  Research group: GAPH-PUCRS    -    contact   fernando.moraes@pucrs.br
--
--  Distribution:  September 2013
--
--  Source name:  processing_element.vhd
--
--  Brief description:  Generate processing element.
--
------------------------------------------------------------------------------------------------

library ieee;
use work.HeMPS_defaults.all;
use ieee.std_logic_1164.all;

entity processing_element is
        generic(
                memory_type             : string := "XIL"; -- "TRI_PORT_X"
                core_type               : string := "plasma";
                mlite_description       : string := "RTL";
                ram_description         : string := "RTL";
                router_description      : string := "RTL";
                log_file                : string := "UNUSED";
                router_address          : regmetadeflit;
                is_master               :  std_logic := '0'
        );
        port(
                address_sc              : in regmetadeflit;

                -- Noc Ports
                clock                   : in  std_logic;
                reset                   : in  std_logic;

                clock_rx                : in  std_logic_vector(3 downto 0);
                rx                      : in  std_logic_vector(3 downto 0);
                data_in                 : in  arrayNPORT_1_regflit;
                credit_o                : out std_logic_vector(3 downto 0);
                clock_tx                : out std_logic_vector(3 downto 0);
                tx                      : out std_logic_vector(3 downto 0);
                data_out                : out arrayNPORT_1_regflit;
                credit_i                : in  std_logic_vector(3 downto 0);

                -- External Memory
                address                 : out std_logic_vector(31 downto 2);
                data_read               : in  std_logic_vector(31 downto 0);
                
                -- Debug MC
                write_enable_debug      : out  std_logic;
                data_out_debug          : out  std_logic_vector(31 downto 0);
                busy_debug              : in std_logic;
                
                ack_app                 : out  std_logic;
                req_app                 : in  std_logic_vector(31 downto 0)
        );
end processing_element;

architecture processing_element of processing_element is

        -- NoC Interface
        signal clock_tx_pe      : std_logic;
        signal tx_pe            : std_logic;
        signal data_out_pe      : regflit;
        signal credit_i_pe      : std_logic;
        signal clock_rx_pe      : std_logic;
        signal rx_pe            : std_logic;
        signal data_in_pe       : regflit;
        signal credit_o_pe      : std_logic;

        signal clock_rx_CC      : regNport;
        signal rx_CC            : regNport;
        signal data_in_CC       : arrayNport_regflit;
        signal credit_o_CC      : regNport;
        signal clock_tx_CC      : regNport;
        signal tx_CC            : regNport;
        signal data_out_CC      : arrayNport_regflit;
        signal credit_i_CC      : regNport;
        
        signal sys_int_i        : std_logic;
        
begin

-------------------
-------------------
--begin Router CC--
-------------------
-------------------
        
        ROUTER_RTL:if router_description = "RTL" generate               
                routerCC : Entity work.RouterCC
                generic map( address => router_address )
                        port map(
                                clock           => clock,
                                reset           => reset,
                                clock_rx        => clock_rx_CC,
                                rx                      => rx_CC,
                                data_in         => data_in_CC,
                                credit_o        => credit_o_CC,
                                clock_tx        => clock_tx_CC,
                                tx                      => tx_CC,
                                data_out        => data_out_CC,
                                credit_i        => credit_i_CC
                        );
        end generate;

-------------------
-------------------
--end  Router  CC--
-------------------
-------------------

        -- connecting east, weast, north and south ports to the inputs and outputs
        clock_rx_CC(3 downto 0)         <= clock_rx;
        rx_CC(3 downto 0)               <= rx;
        data_in_CC                      <= ( 4 => data_out_pe,  3 => data_in(3),  2 => data_in(2),  1 => data_in(1),  0 => data_in(0));

        --(others=>(others=>'0'));

        credit_o                        <= credit_o_CC(3 downto 0);
        clock_tx                        <= clock_tx_CC(3 downto 0);
        tx                              <= tx_CC(3 downto 0);
        data_out                        <= ( 3 => data_out_CC(3), 2 => data_out_CC(2), 1 => data_out_CC(1), 0 => data_out_CC(0));
        credit_i_CC(3 downto 0) <= credit_i;

        -- connecting local port to plasma
        clock_rx_CC(LOCAL)              <= clock_tx_pe;
        rx_CC(LOCAL)                    <= tx_pe;
       -- data_in_CC(LOCAL)               <= data_out_pe;
        credit_i_pe                     <= credit_o_CC(LOCAL);
        clock_rx_pe                     <= clock_tx_CC(LOCAL);
        rx_pe                           <= tx_CC(LOCAL);
        data_in_pe                      <= data_out_CC(LOCAL);
        credit_i_CC(LOCAL)              <= credit_o_pe;

-------------------
-------------------
--begin  Plasma  --
-------------------
-------------------
        PE_PLASMA: if core_type = "plasma" generate
                plasma: entity work.plasma
                        generic map (
                                memory_type                     => "TRI",
                                mlite_description       => mlite_description,
                                ram_description         => ram_description,
                                log_file                        => log_file,
                                router_address          => router_address,
                                is_master               => is_master
                        )
                        port map(
                                clock                           => clock,
                                reset                           => reset,
                                clock_tx                        => clock_tx_pe,
                                tx                                      => tx_pe,
                                data_out                        => data_out_pe,
                                credit_i                        => credit_i_pe,
                                clock_rx                        => clock_rx_pe,
                                rx                                      => rx_pe,
                                data_in                         => data_in_pe,
                                credit_o                        => credit_o_pe,
        
                                address                         => address,
                                data_read                       => data_read,

                                write_enable_debug      => write_enable_debug,
                                data_out_debug          => data_out_debug,
                                busy_debug                      => busy_debug,
                                
                                ack_app                        => ack_app,
                                req_app                        => req_app
                        );
        end generate;
        
-------------------
-------------------
--  end  Plasma  --
-------------------
-------------------
end architecture processing_element;