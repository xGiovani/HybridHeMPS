------------------------------------------------------------------------------------------------
--
--  DISTRIBUTED HEMPS  - version 5.0
--
--  Research group: GAPH-PUCRS    -    contact   fernando.moraes@pucrs.br
--
--  Distribution:  September 2013
--
--  Source name:  plasma.vhd
--
--  AUTHOR: Steve Rhoads (rhoadss@yahoo.com)
--
--  DATE CREATED: 6/4/02
--
--  COPYRIGHT: Software placed into the public domain by the author.
--    Software 'as is' without warranty.  Author liable for nothing.
--
--  Brief description:  This entity combines the CPU core with memory and a debug.
--
------------------------------------------------------------------------------------------------
-- Memory Map:
--   0x00000000 - 0x0000ffff   Internal RAM (64KB)
--   0x10000000 - 0x100fffff   External RAM (1MB)
--   Access all Misc registers with 32-bit accesses
--   0x20000000  debug Write (will pause CPU if busy)
--   0x20000000  debug Read
--   0x20000010  IRQ Mask
--   0x20000020  IRQ Status
--   0x20000030 
--   0x20000050 
--   0x20000060  Time_Slice_Addr 

--   0x20000100 - NI Status Reading
--   0x20000110 - NI Status Sending
--   0x20000120 - NI Read Data
--   0x20000130 - NI Write Data
--   0x20000140 - NI Configuration
--   0x20000150 - NI Packet ACK
--   0x20000160 - NI Packet NACK
--   0x20000170 - NI Packet END

-- Mappings only for the slave CPU
--   0x20000200 - Set DMNI Size
--   0x20000210 - Set DMNI Address
--   0x20000220 - Set DMNI Operation
--   0x20000230 - Start DMNI
--   0x20000240 - DMNI ACK
--   0x20000250 - DMNI_AVAILABLE


--   0x20000300 - Tick Counter

--   IRQ bits:
--      7   
--      6   
--      5   NoC
--      4   DMNI (slave only)
--      3   Counter(18)
--      2  ^Counter(18)
--      1  ^debugBufferFull
--      0   debugDataAvailable
--
--  Re-structurated for adding DMA and NI modules.
---------------------------------------------------------------------

library ieee;
use work.mlite_pack.all;                
use work.HeMPS_defaults.all;
use work.HemPS_PKG.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_textio.all;
use ieee.std_logic_unsigned.all;
use ieee.math_real.all;

use std.textio.all;
library unisim;
use unisim.vcomponents.all;

entity plasma is
    generic 
    (
        memory_type         : string := "XIL"; -- "TRI_PORT_X"
        mlite_description   : string := "RTL";
        ram_description     : string := "RTL";
        log_file            : string := "output.txt";
        router_address      : regmetadeflit:= (others=>'0');
        is_master           : std_logic
    );
    port 
    (  
        clock               : in  std_logic;
        reset               : in  std_logic;
        -- NoC Interface      
        clock_tx            : out std_logic;
        tx                  : out std_logic;
        data_out            : out regflit;
        credit_i            : in  std_logic;

        clock_rx            : in  std_logic;        
        rx                  : in  std_logic;
        data_in             : in  regflit;
        credit_o            : out std_logic;

        -- Debug MC
        write_enable_debug  : out std_logic;
        data_out_debug      : out std_logic_vector(31 downto 0);
        busy_debug          : in  std_logic;
        
        --Dynamic Insertion of Applications
        ack_app             : out std_logic;
        req_app             : in  std_logic_vector(31 downto 0);

        -- External Memory
        address             : out std_logic_vector(29 downto 0);
        data_read           : in  std_logic_vector(31 downto 0)        
    );
end entity plasma;

architecture structural of plasma is
    -- Memory map constants.
    constant DEBUG              : std_logic_vector(31 downto 0):=x"20000000";
    constant IRQ_MASK           : std_logic_vector(31 downto 0):=x"20000010";
    constant IRQ_STATUS_ADDR    : std_logic_vector(31 downto 0):=x"20000020";
    constant TIME_SLICE_ADDR    : std_logic_vector(31 downto 0):=x"20000060";
    constant FIFO_AVAIL         : std_logic_vector(31 downto 0):=x"20000040";
    constant END_SIM            : std_logic_vector(31 downto 0):=x"20000080";   
    constant CLOCK_HOLD         : std_logic_vector(31 downto 0):=x"20000090";
    constant NET_ADDRESS        : std_logic_vector(31 downto 0):=x"20000140";

    -- Network interface mapping.
    constant NI_STATUS_READ     : std_logic_vector(31 downto 0):=x"20000100";
    constant NI_STATUS_SEND     : std_logic_vector(31 downto 0):=x"20000110";
    constant NI_READ            : std_logic_vector(31 downto 0):=x"20000120";
    constant NI_WRITE           : std_logic_vector(31 downto 0):=x"20000130";
    constant NI_CONFIGURATION   : std_logic_vector(31 downto 0):=x"20000140";
    constant NI_ACK             : std_logic_vector(31 downto 0):=x"20000150";
    constant NI_NACK            : std_logic_vector(31 downto 0):=x"20000160";
    constant NI_END             : std_logic_vector(31 downto 0):=x"20000170";
    
    -- DMNI mapping.
    constant DMNI_SIZE           : std_logic_vector(31 downto 0):=x"20000200";
    constant DMNI_ADDR           : std_logic_vector(31 downto 0):=x"20000210";
    constant DMNI_SIZE_2         : std_logic_vector(31 downto 0):=x"20000204";
    constant DMNI_ADDR_2         : std_logic_vector(31 downto 0):=x"20000214";
    constant DMNI_OP             : std_logic_vector(31 downto 0):=x"20000220";
    constant START_DMNI          : std_logic_vector(31 downto 0):=x"20000230";
    constant DMNI_ACK            : std_logic_vector(31 downto 0):=x"20000240";

    constant DMNI_SEND_ACTIVE    : std_logic_vector(31 downto 0):=x"20000250";
    constant DMNI_RECEIVE_ACTIVE : std_logic_vector(31 downto 0):=x"20000260";

    constant SCHEDULING_REPORT   : std_logic_vector(31 downto 0):=x"20000270";

    
    constant TICK_COUNTER_ADDR  : std_logic_vector(31 downto 0):=x"20000300";    
    constant REQ_APP_REG        : std_logic_vector(31 downto 0):=x"20000350";
    constant ACK_APP_REG        : std_logic_vector(31 downto 0):=x"20000360";

    constant PENDING_SERVICE_INTR : std_logic_vector(31 downto 0):=x"20000400";

    
    signal cpu_mem_address_reg           : std_logic_vector(31 downto 0);
    signal cpu_mem_data_write_reg        : std_logic_vector(31 downto 0);
    signal cpu_mem_write_byte_enable_reg : std_logic_vector(3 downto 0); 
    signal irq_mask_reg                  : std_logic_vector(7 downto 0);
    signal irq_status                    : std_logic_vector(7 downto 0); 
    signal irq                           : std_logic;
    signal time_slice                    : std_logic_vector(31 downto 0);
    signal write_enable                  : std_logic; 
    signal tick_counter_local            : std_logic_vector(31 downto 0);  
    signal tick_counter                  : std_logic_vector(31 downto 0);            
    signal current_page                  : std_logic_vector(7 downto 0); 
    
    --cpu
    signal cpu_mem_address               : std_logic_vector(31 downto 0);
    signal cpu_mem_data_write            : std_logic_vector(31 downto 0);
    signal cpu_mem_data_read             : std_logic_vector(31 downto 0);
    signal cpu_mem_write_byte_enable     : std_logic_vector(3 downto 0);
    signal cpu_mem_pause                 : std_logic;    
    signal cpu_enable_ram            : std_logic;
    signal cpu_set_size              : std_logic;
    signal cpu_set_address           : std_logic;
    signal cpu_set_size_2            : std_logic;
    signal cpu_set_address_2         : std_logic;
    signal cpu_set_op                : std_logic;
    signal cpu_start                 : std_logic;
    signal cpu_ack                   : std_logic;
    signal clock_aux                 : std_logic;       
    signal clock_hold_s              : std_logic; 

    signal pending_service           : std_logic;   


    --ram
    signal data_read_ram  : std_logic_vector(31 downto 0);
    signal mem_data_read  : std_logic_vector(31 downto 0);
    
    --mc debug 
    signal debug_busy        : std_logic;
    signal debug_write_data  : std_logic; 
    signal debug_write_busy  : std_logic;
    signal debug_data_avail  : std_logic; 
    
    --network interface
    signal ni_intr       : std_logic;
    
    --dmni    
    signal dmni_mem_address           : std_logic_vector( 31 downto 0);
    signal dmni_mem_addr_ddr          : std_logic_vector(31 downto 0);
    signal dmni_mem_ddr_read_req      : std_logic;
    signal mem_ddr_access             : std_logic;
    signal dmni_mem_write_byte_enable : std_logic_vector(3 downto 0);
    signal dmni_mem_data_write        : std_logic_vector(31 downto 0);
    signal dmni_mem_data_read         : std_logic_vector(31 downto 0);
    signal dmni_data_read             : std_logic_vector(31 downto 0);
    signal dmni_enable_internal_ram   : std_logic;
    signal dmni_send_active_sig       : std_logic;
    signal dmni_receive_active_sig    : std_logic;
    signal address_mux                : std_logic_vector(31 downto 2);
    signal cpu_mem_address_reg2       : std_logic_vector(31 downto 0);
    signal addr_a                     : std_logic_vector(31 downto 2);
    signal addr_b                     : std_logic_vector(31 downto 2);
    signal cpu_repo_access            : std_logic := '0';
    --logfile signals
    signal data_av                    : std_logic;
    signal end_sim_reg : std_logic_vector(31 downto 0);
    type repo_state is (WAIT_state, COPY_FROM_REP);
    signal repo_FSM: repo_state;
    signal data_read_reg              : std_logic_vector(31 downto 0);
    
    signal l_irq_status : std_logic_vector(7 downto 0);
    signal new_mem_address : std_logic_vector(31 downto 0);
    --emulated uart log_file
    signal uart_write_data : std_logic;
        
begin
        u1_cpu: entity work.mlite_cpu 
        port map (
            clk          => clock_hold_s,                      
            reset_in     => reset,                      
            intr_in      => irq,                        
                                                        
            mem_address  => cpu_mem_address,               
            mem_data_w   => cpu_mem_data_write,             
            mem_data_r   => cpu_mem_data_read,          
            mem_byte_we  => cpu_mem_write_byte_enable,  
            mem_pause    => cpu_mem_pause,
            current_page => current_page
        );

    MASTER_RAM : if is_master = '1' generate
        u2_ram: entity work.ram_master
        port map (
            clk     => clock,                       

            enable_a        => cpu_enable_ram,         
            wbe_a           => cpu_mem_write_byte_enable,           
            address_a       => addr_a,
            data_write_a    => cpu_mem_data_write,          
            data_read_a     => data_read_ram,

            enable_b        => dmni_enable_internal_ram,         
            wbe_b           => dmni_mem_write_byte_enable,          
            address_b       => addr_b,
            data_write_b    => dmni_mem_data_write,          
            data_read_b     => mem_data_read
        );
    end generate MASTER_RAM;
    
    SLAVE_RAM : if is_master = '0' generate
        u2_ram: entity work.ram_plasma
        port map (
            clk             => clock,                       

            enable_a        => cpu_enable_ram,         
            wbe_a           => cpu_mem_write_byte_enable,        
            address_a       => addr_a,
            data_write_a    => cpu_mem_data_write,          
            data_read_a     => data_read_ram,

            enable_b        => dmni_enable_internal_ram,         
            wbe_b           => dmni_mem_write_byte_enable,         
            address_b       => addr_b,
            data_write_b    => dmni_mem_data_write,          
            data_read_b     => mem_data_read
        );
    end generate SLAVE_RAM;
        
    u3_dmni : entity work.dmni
     generic map ( 
        address_router => router_address
    )
    port map (
        clock           => clock,           
        reset           => reset,     
        --Configuration interface
        set_address     => cpu_set_address,
        set_address_2   => cpu_set_address_2,
        set_size        => cpu_set_size,
        set_size_2      => cpu_set_size_2,
        set_op          => cpu_set_op,
        start           => cpu_start,        
        config_data     => dmni_data_read,

        -- Status outputs
        intr            => ni_intr,
        send_active     => dmni_send_active_sig,
        receive_active  => dmni_receive_active_sig,    
        
        -- Memory interface
        mem_address     => dmni_mem_address, 
        mem_data_write  => dmni_mem_data_write,
        mem_data_read   => dmni_mem_data_read,
        mem_byte_we     => dmni_mem_write_byte_enable,      

        --NoC Interface (Local port)
        tx              => tx,
        data_out        => data_out,
        credit_i        => credit_i,
        clock_tx        => clock_tx,
        rx              => rx,
        data_in         => data_in,
        credit_o        => credit_o,
        clock_rx        => clock_rx                 
    );

    repo_to_mem_access: process(clock,reset)
    begin
        if reset = '1' then
            repo_FSM <= WAIT_state;
            cpu_repo_access <= '0';
        elsif rising_edge(clock) then
            case( repo_FSM ) is            
                when WAIT_state =>
                    if(cpu_mem_address(30 downto 28) = "001") then
                        cpu_repo_access <= '1';
                        repo_FSM <= COPY_FROM_REP;
                    end if;
                when COPY_FROM_REP =>
                    repo_FSM <= WAIT_state;
                    cpu_repo_access <= '0';
            end case ;
        end if;
    end process repo_to_mem_access;

    SLAVE_DEBUG : if (is_master = '0') generate
       u4_UartFile: entity work.UartFile
       generic map (
           log_file => log_file
       )
       port map (
           reset           => reset,                         
           data_av         => uart_write_data,          
           data_in         => cpu_mem_data_write_reg
       );

       uart_write_data     <= '1' when cpu_mem_address_reg = DEBUG and write_enable = '1' else '0';

       debug_busy          <= '0';
       debug_write_busy    <= '0';
       debug_data_avail    <= '0';
    end generate SLAVE_DEBUG; 

    MUX_CPU : cpu_mem_data_read <= data_read when cpu_mem_address_reg(30 downto 28) = "001" else   -- External RAM
                                    ZERO(31 downto 8) & irq_mask_reg when cpu_mem_address_reg = IRQ_MASK else
                                    ZERO(31 downto 8) & irq_status when cpu_mem_address_reg = IRQ_STATUS_ADDR else
                                    time_slice when cpu_mem_address_reg = TIME_SLICE_ADDR else
                                    ZERO(31 downto 16) & router_address when cpu_mem_address_reg = NET_ADDRESS else
                                    tick_counter when cpu_mem_address_reg = TICK_COUNTER_ADDR else  
                                    req_app when cpu_mem_address_reg = REQ_APP_REG else                                 
                                    ZERO(31 downto 1) & dmni_send_active_sig when cpu_mem_address_reg = DMNI_SEND_ACTIVE else                                    
                                    ZERO(31 downto 1) & dmni_receive_active_sig when cpu_mem_address_reg = DMNI_RECEIVE_ACTIVE else
                                    data_read_ram;
    
    --Comb assignments
    addr_a(31 downto 28) <= cpu_mem_address(31 downto 28);   
    addr_a(27 downto PAGE_SIZE_H_INDEX+1)   <= ZERO(27 downto PAGE_SIZE_H_INDEX+9) & current_page when current_page /= "00000000" and cpu_mem_address(31 downto PAGE_SIZE_H_INDEX+1) /= ZERO(31 downto PAGE_SIZE_H_INDEX+1)
                                           else cpu_mem_address(27 downto PAGE_SIZE_H_INDEX+1);               
    addr_a(PAGE_SIZE_H_INDEX downto 2) <= cpu_mem_address(PAGE_SIZE_H_INDEX downto 2);   

    addr_b              <= dmni_mem_address(31 downto 2);
    write_enable_debug  <= '1' when cpu_mem_address_reg = DEBUG and write_enable = '1' else '0';
    data_av             <= '1' when cpu_mem_address_reg = DEBUG and write_enable = '1' else '0';
    data_out_debug      <= cpu_mem_data_write_reg;
    debug_write_busy    <= busy_debug;
    debug_busy          <= '1' when cpu_mem_address_reg = DEBUG and write_enable = '1' and busy_debug = '1' else '0';
    cpu_mem_pause       <= cpu_repo_access or debug_busy;
    irq                 <= '1' when (irq_status /= x"00" and irq_mask_reg /= x"00") else '0';
    dmni_data_read      <= cpu_mem_data_write_reg; 
    dmni_mem_data_read  <= mem_data_read  when dmni_enable_internal_ram = '1' else data_read;  
    cpu_enable_ram              <= '1' when cpu_mem_address(30 downto 28) = "000" else '0';      
    dmni_enable_internal_ram    <= '1' when dmni_mem_address(30 downto 28) = "000" else '0';     
    end_sim_reg         <= x"00000000" when cpu_mem_address_reg = END_SIM and write_enable = '1' else x"00000001";
    irq_status(7 downto 4) <=  "00" & ni_intr & '0';
    irq_status(3) <= '1' when time_slice = x"00000001" else '0';
    irq_status(2 downto 1) <= "00";
    irq_status(0) <= (not dmni_send_active_sig and pending_service);
    
    cpu_set_size        <= '1' when cpu_mem_address_reg = DMNI_SIZE and write_enable = '1' else '0';
    cpu_set_address     <= '1' when cpu_mem_address_reg = DMNI_ADDR and write_enable = '1' else '0';
    cpu_set_size_2      <= '1' when cpu_mem_address_reg = DMNI_SIZE_2 and write_enable = '1' else '0';
    cpu_set_address_2   <= '1' when cpu_mem_address_reg = DMNI_ADDR_2 and write_enable = '1' else '0';
    cpu_set_op          <= '1' when (cpu_mem_address_reg = DMNI_OP and write_enable = '1') else '0';
    cpu_start           <= '1' when (cpu_mem_address_reg = START_DMNI and write_enable = '1') else '0';
    
    write_enable <= '1' when cpu_mem_write_byte_enable_reg /= "0000" else '0';

    process(cpu_repo_access, dmni_mem_address)
    begin
        if(cpu_repo_access = '1') then 
            address(29 downto 0) <= cpu_mem_address(29 downto 0) ;
        elsif dmni_mem_address(30 downto 28) = "001" then
            address(29 downto 0) <= dmni_mem_address(29 downto 0);
        end if;
    end process;

    sequential_attr: process(clock, reset)
    begin            
        if reset = '1' then
            cpu_mem_address_reg <= ZERO;
            cpu_mem_data_write_reg <= ZERO;
            cpu_mem_write_byte_enable_reg <= ZERO(3 downto 0);
            irq_mask_reg <= ZERO(7 downto 0);
            time_slice <= ZERO;
            tick_counter <= ZERO;
            pending_service <= '0';
            ack_app <= '0';
        elsif (clock'event and clock = '1') then
            if cpu_mem_pause = '0' then
                cpu_mem_address_reg <= cpu_mem_address;
                cpu_mem_data_write_reg <= cpu_mem_data_write;
                cpu_mem_write_byte_enable_reg <= cpu_mem_write_byte_enable;
        
                if cpu_mem_address_reg = IRQ_MASK and write_enable = '1' then
                    irq_mask_reg <= cpu_mem_data_write_reg(7 downto 0);
                end if;     
               -- Decrements the time slice when executing a task (current_page /= x"00") or handling a syscall (syscall = '1')
                if time_slice > 1 then
                    time_slice <= time_slice - 1;
                end if;  

                if(cpu_mem_address_reg = PENDING_SERVICE_INTR and write_enable = '1') then
                    if cpu_mem_data_write_reg = ZERO then
                        pending_service <= '0';
                    else
                        pending_service <= '1';
                    end if;
                end if; 
            end if;
                                    
            if cpu_mem_address_reg = TIME_SLICE_ADDR and write_enable = '1' then
                time_slice <= cpu_mem_data_write_reg;
            end if;
                
            if cpu_mem_address_reg = ACK_APP_REG then
                ack_app <= '1';
            elsif req_app(31) = '0' then 
                ack_app <= '0';
            end if;

            tick_counter <= tick_counter + 1;   
        end if;
    end process sequential_attr;

    clock_stop: process(reset,clock)
    begin
        if(reset = '1') then
            tick_counter_local <= (others=> '0');
            clock_aux <= '1';
        else
            if cpu_mem_address_reg = CLOCK_HOLD and write_enable = '1' then
                clock_aux <= '0';
            elsif rx = '1' or ni_intr = '1' then 
                clock_aux <= '1';
            end if;

            if(clock_aux ='1' and clock ='1') then
                clock_hold_s <= '1';
                tick_counter_local <= tick_counter_local + 1;
            else
                clock_hold_s <= '0';
            end if;
        end if;
    end process clock_stop;

end architecture structural;

  