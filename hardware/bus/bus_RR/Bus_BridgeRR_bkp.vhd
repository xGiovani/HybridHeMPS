library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use work.HeMPS_defaults.all;
use work.HemPS_PKG.all;

entity Bus_BridgeRR is
	generic(
	    router_address : std_logic_vector(15 downto 0):= (others=>'0');
	);
	port(
            clock        : in std_logic;
            reset        : in std_logic;
	-- DMNI INTERFACE
            rx           : in std_logic;
	    data_in      : in regflit;
	    credit_o     : out std_logic;
	-- BUS INTERFACE
            data_out     : out regflit;
            credit_i     : in std_logic;
	    tx           : out std_logic;
	    tx_addr      : out regflit;
	    source_addr    : out regmetadeflit;
	-- BUS CTRL Signals
	    ack          : out std_logic;
	    request      : out std_logic;
	    grant        : in std_logic;
	    using_bus     : out std_logic
	);
end Bus_BridgeRR;

architecture Bus_BridgeRR of Bus_BridgeRR is

signal data_av, data_ack: std_logic := '0';
type fila_out is (S_INIT, S_REQUEST, S_PAYLOAD, S_SENDHEADER, S_END, S_END2);
signal EA : fila_out;

signal buf: buff := (others=>(others=>'0'));
signal first,last: pointer := (others=>'0');
signal tem_espaco: std_logic := '0';
signal counter_flit: regflit := (others=>'0');
signal header_reg: regflit := (others=>'0');

begin

	-- There is available data on Buffer
	tx <= data_av;

	-- Processor that will receive message confirm having space on buffer
	data_ack <= credit_i when data_av= '1' else '0';
				
	-- Stores the header fli indicating which processor on bus will communicate
	header_reg <= buf(CONV_INTEGER(first)) when EA = S_SENDHEADER;
	
	-- Target Address
	tx_addr <= header_reg;

        -------------------------------------------------------------------------------------------
        -- ENTRADA DE DADOS NA FILA
        -------------------------------------------------------------------------------------------
		
        -- Verifica se existe espa\ufffdo na fila para armazenamento de flits.
        -- Se existe espa\ufffdo na fila o sinal tem_espaco_na_fila \ufffd igual 1.
        process(reset, clock)
        begin
                if reset='1' then
                        tem_espaco <= '1';
                elsif clock'event and clock='1' then
                        if not((first=x"0" and last=TAM_BUFFER - 1) or (first=last+1)) then
                                tem_espaco <= '1';
                        else
                                tem_espaco <= '0';
                        end if;
                end if;
        end process;
		
	-- Buffer has space to receive data from DMNI
	credit_o <= tem_espaco;
		
	-- O ponteiro last \ufffd inicializado com o valor zero quando o reset \ufffd ativado.
        -- Quando o sinal rx \ufffd ativado indicando que existe um flit na porta de entrada \ufffd
        -- verificado se existe espa\ufffdo na fila para armazen\ufffd-lo. Se existir espa\ufffdo na fila o
        -- flit recebido \ufffd armazenado na posi\ufffd\ufffdo apontada pelo ponteiro last e o mesmo \ufffd
        -- incrementado. Quando last atingir o tamanho da fila, ele recebe zero.
        process(reset, clock)
        begin
                if reset='1' then
                        last <= (others=>'0');
                elsif clock'event and clock='0' then
                        if tem_espaco='1' and rx='1' then
                                buf(CONV_INTEGER(last)) <= data_in;
                                --incrementa o last
                                if(last = TAM_BUFFER - 1) then 
					last <= (others=>'0');
                                else 
					last <= last + 1;
                                end if;
                        end if;
                end if;
        end process;

        -------------------------------------------------------------------------------------------
        -- SA\ufffdDA DE DADOS NA FILA
        -------------------------------------------------------------------------------------------
		
	-- Data to Bus
	data_out <= buf(CONV_INTEGER(first));
		
        process(reset, clock)
        begin
                if reset='1' then
                        counter_flit <= (others=>'0');
                        data_av <= '0';
                        first <= (others=>'0');
                        EA <= S_INIT;
			request <= '0';
			using_bus <= '0';
			ack <= '0';
                elsif clock'event and clock='1' then
                        case EA is
                                when S_INIT =>
                                        counter_flit <= (others=>'0');
                                        data_av <= '0';
                                        if first /= last then -- detectou dado na fila
						EA <= S_REQUEST;
						request <= '1';
                                        else
                                                EA <= S_INIT;
                                        end if;
				-- Waiting for BUS
				when S_REQUEST =>
				        if grant = '1' then    -- Will start using the bus and sending the message
						EA <= S_SENDHEADER;
						ack <= '1';
						request <= '0';
						using_bus <= '1';
						data_av <= '1';
					else	
						request <= '1';
						EA <= S_REQUEST;
					end if;
                                when S_SENDHEADER  =>
					ack <= '0';
                                        if data_ack = '1' then  -- confirmacao do envio do header
                                                -- retira o header do buffer e se tem dado no buffer pede envio do mesmo
                                                if (first = TAM_BUFFER -1) then
                                                        first <= (others=>'0');
                                                        if last /= 0 then 
								data_av <= '1';
                                                        else 
								data_av <= '0';
                                                        end if;
                                                else
                                                        first <= first+1;
                                                        if first+1 /= last then 
								data_av <= '1';
                                                        else 
								data_av <= '0';
                                                        end if;
                                                end if;
                                                EA <= S_PAYLOAD;
                                        else
                                                EA <= S_SENDHEADER;
                                        end if;
                                when S_PAYLOAD =>
                                        if data_ack = '1' and counter_flit /= x"1" then -- confirmacao do envio de um dado que nao eh o tail
                                                -- se counter_flit eh zero indica recepcao do size do payload
                                                if counter_flit = x"0" then    
							counter_flit <=  buf(CONV_INTEGER(first));
                                                else 
							counter_flit <= counter_flit - 1;
                                                end if;

                                                -- retira um dado do buffer e se tem dado no buffer pede envio do mesmo
                                                if (first = TAM_BUFFER -1) then
                                                        first <= (others=>'0');
                                                        if last /= 0 then 
								data_av <= '1';
                                                        else 
								data_av <= '0';
                                                        end if;
                                                else
                                                        first <= first+1;
                                                        if first+1 /= last then 
								data_av <= '1';
                                                        else 
								data_av <= '0';
                                                        end if;
                                                end if;
                                                EA <= S_PAYLOAD;
                                        elsif data_ack = '1' and counter_flit = x"1" then -- confirmacao do envio do tail
                                                -- retira um dado do buffer
                                                if (first = TAM_BUFFER -1) then    
							first <= (others=>'0');
                                                else 
							first <= first+1;
                                                end if;
                                                data_av <= '0';
                                                EA <= S_END;
                                        elsif first /= last then -- se tem dado a ser enviado faz a requisicao
                                                data_av <= '1';
                                                EA <= S_PAYLOAD;
                                        else
                                                EA <= S_PAYLOAD;
                                        end if;
                                when others => -- S_END
					using_bus <= '0';
                                        data_av <= '0';
                                        EA <= S_INIT;
                        end case;
                end if;
        end process;  

end architecture Bus_BridgeRR;
