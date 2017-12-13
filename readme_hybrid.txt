Comentários sobre principais alterações e funcionamento da HeMPS 7.2 Híbrida
Por Giovani Salvamoura Soares - Estágio 2º Semestre/2017

As seguintes alterações realizadas no framework da HeMPS 7.2 tem como objetivo a criação de uma NoC Híbrida parametrizada com seu topo de projeto escrito em linguagem SystemVerilog a partir de um script.

-> Alteração da estrutura do arquivo ".hmp".
	• Deve ser colocado a quantidade barramentos[bus_count], quantidade de processadores por barramento[proc_per_bus] e posição em ID dos barramentos na NoC[bus position]. O mesmo deve ser feito para a Crossbar.
	Exemplo para os dados do barramento:
	[bus_count]    • Dois barramentos conectados na NoC
	2
	[proc_per_bus] • O primeiro barramento possuí 5 e e o segundo possuí 10 processadores
	5
	10
	[bus position] • O primeiro barramento com 5 processadores se encontra na posição 1 e o segundo com 10 processadores na posição 4
	1
	4
	IDs são posições baseado nas dimensões da NoC, por exemplo uma NoC 2x2 e 3x3 tem os seguintes IDs(posições):
						 _____
	  ___ 				|6 7 8|
	 |2 3|  NoC 2x2	,	|3 4 5| NoC 3x3     , ...
	 |0 1|				|0 1 2|
	  ¯¯¯	 			 ¯¯¯¯¯
	Sendo a posição Left Bottom (0) a localização do processador Mestre.
	• Pode ser criada uma NoC Híbrida sem nenhum barramento OU crossbar. Deve ser colocado o valor 0 em todos os respectivos campos caso não seja desejado algum barramento ou crossbar.
	• DOIS processadores são o MÍNIMO para cada instância de barramento ou crossbar.
	• Não colocar as posições do barramento e da crossbar fora das dimensões possíveis da NoC Criada. Exemplo: Posição 10 em uma NoC 3x3.
	• Um barramento e uma crossbar NÃO podem ocupar a mesma posição na NoC.
	• Barramentos e crossbars não podem ser colocados na posição 0 (Roteador com processador Mestre).
	• Ao ser conectado barramento ou crossbar o roteador correspondente é SUBSTITUÍDO por um Wrapper + barramento ou Wrapper + Crossbar.
	
-> Alteração no arquivo principal do framework "script.pl" localizado em "7.2/scripts/".
	• Alterada função read_hmp_file() para leitura dos novos dados do novo arquivo ".hmp".
	-> Adicionada função generate_hybrid_top_setup() onde essa função cria um arquivo descrito em linguagem SystemVerilog chamado hybrid_top_setup.sv na pasta onde foi criado o projeto.
		• Esse arquivo contém o Topo do projeto contendo as ligações dos roteadores, processadores, barramentos, crossbars e Wrappers.
		• Essa função também cria o arquivo "if_plasma.sv" para a pasta do projeto contendo as interfaces utilizadas pelos processadores para troca de flits baseado nos endereços dos processadores que estão em barramento e crossbar.
		• Não há necessidade da criação do arquivo "if_plasma.sv" caso seja possível uma leitura do arquivo "HeMPS_pkg.vhd" escrito em VHDL para a tabela dentro do arquivo "if_plasma.sv" escrito em SystemVerilog.
	• Alteração na função generate_Hemps_PKG() adicionando as novas constantes de barramento e crossbar da HeMPS Híbrida para o arquivo "HeMPS_pkg.vhd".
	• Alteração na função generate_makefile_hardware() onde agora o makefile gerado contém os arquivos e pastas de projeto para a HeMPS_Híbrida. Alterações no makefile devem ser realizadas dentro dessa função.
	
-> Futuras alterações nos arquivo hybrid_top_setup.sv e if_plasma.sv devem ser realizadas na função generate_hybrid_top_setup() do arquivo "script.pl".

-> Lógica de reutilização de endereços para a NoC Híbrida
	• Processadores em barramentos e crossbar reutilizam endereços não utilizados que estão fora das dimensões da NoC criada.
	• Essa reutilizão é dada em formato de um "L" invertido começando pela linha acima da dimensão Y da NoC e X igual a 0. Criando endereços primeiro para processadores em barramento e após para as crossbars.
	• Wrappers e o primeiro processador no barramento ou crossbar possuem o mesmo endereço dos roteadores na qual foram substituídos.
	
-> Observações!
	• A numeração dos processadores dentro do arquivo hybrid_top_setup.sv é baseada no total de processadores no sistema. Logo quando um roteador é substituído, é "pulado" um número apesar dos sinais terem sido criados mas os mesmos não são conectados.
	
-> Alterações em Barramento e Crossbar
	• Parametrização de barramento e crossbar e alteração na lógica de comparação de endereços.
	• Barramentos e Crossbars recebem um ID e a quantidade de barramentos conectados pelo Topo.
	• O ID faz com que o barramento/crossbar guarde os endereços dos processadores que estão conectados para comparação correta dos endereços. Endereços são lidos das constantes do arquivo "HeMPS_pkg.vhd".
	
-> NoC com Injetores
	• A alteração no framework permite colocar injetores de mensagens artificiais na NoC
	• Alterando [injectores] para 1 todos os Processadores que estão nas extremidades da NoC serão substituído por injetores de pacote, em 0 é gerado a NoC híbrida.
	• Criando uma NoC 4x4 com injetores, apenas os 4(2x2) processadores no centro estarão disponíveis para executar aplicações ou serem substituidos por Wrappers. Uma NoC 5x5, apenas os 9(3x3) processadores centrais e assim por diante.
	• A NoC deve ser sempre quadrada e o tamanho mínimo deve ser 4x4: 4x4, 5x5, 6x6 e etc.
	• Não é possível substituir os injetores por Wrappers, cuidar IDs dos barramentos e crossbars quando usado o modo injetor.