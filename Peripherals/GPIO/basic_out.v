`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Egyszer� 8 bites kimeneti modul a PicoBlaze vez�rl�h�z
// Semmi extra szolg�ltat�s, csak k�zvetlen adat kiad�s
// A perif�ria c�m param�ter �tad�ssal �ll�that� be a fels� szint� modulban
// a szint�zis m�r ennek megfelele�en az aktu�lis p_addr c�mmel t�rt�nik

// PicoBlaze IO port WRITE ciklus id�diagram
// A port c�m �s a kimeneti adat 2 �rajel cikluson kereszt�l stabil
// A WRITE_STROBE a 2. �rajelben akt�v 
// Ennek megfelel�en a kimeneti adatot a 2. �rajel v�g�n �rjuk be a kimeneti regiszterbe

// CLK      ________--------________--------________--------________--------______   
// PORT_ID  XXXXXXXXXX<        WRITE_PORT_ID         >XXXXXXXXXXXXXXXXXXXXXXXXXXXXX
// DATA_INPUT XXXXXXXX<        VALIID OUTPUT         >XXXXXXXXXXXXXXXXXXXXXXXXXXXXX     
// WRITE_STROBE_______________________----------------______________________________
// Kimenet �t�r�sa                                   ^ <- itt

  
module Basic_OUT(
    input clk,
    input rst,
    input wr_strobe,
    input [7:0] addr,
    input [7:0] out_data,                    // A vez�rl� kimeneti adata ezen a modulon bemenet
    output [7:0] out_signals
    );

parameter p_addr = 8'hff;                    // A c�m alap�rt�ke legyen hexa FF

wire p_sel;                                  // Perif�ria c�m kiv�laszt�s jel
wire p_write;                                // Perif�ria �r�s jel
reg [7:0] out_reg;                           // Kimeneti regiszter 

// Az alapfunkci�t egyszer� adatkiad�ssal val�s�tjuk meg
// A kimeneti adat egy regiszterbe ker�l, ez fogja meghajtani a kimeneti vonalakat
// Teh�t a kimeneti buszon egy �r�si ciklus ideig (2 �rajel ciklus) megjelen� dinamikus 
// adatot a regiszter egy statikus, stabil adatt� alak�tja (am�g �jra nem �rjuk)

assign p_sel = (addr == p_addr);             // A perif�ria c�m dek�dol�sa

assign p_write = p_sel & wr_strobe;          // Az �r�s parancs felismer�se

always @ (posedge clk)                      
   if (rst)        out_reg <= 8'b0;          // RESET alatt a regiszter t�r�lve
   else 
      if (p_write) out_reg <= out_data;      // �r�sn�l friss�tve, egy�bk�nt tartja az �llapot�t


assign out_signals = out_reg;                // A regiszter tartalma k�zvetlen�l megjelenik a kimeneten


endmodule