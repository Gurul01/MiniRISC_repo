`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Egyszerû 8 bites kimeneti modul a PicoBlaze vezérlõhöz
// Semmi extra szolgáltatás, csak közvetlen adat kiadás
// A periféria cím paraméter átadással állítható be a felsõ szintû modulban
// a szintézis már ennek megfeleleõen az aktuális p_addr címmel történik

// PicoBlaze IO port WRITE ciklus idõdiagram
// A port cím és a kimeneti adat 2 órajel cikluson keresztül stabil
// A WRITE_STROBE a 2. órajelben aktív 
// Ennek megfelelõen a kimeneti adatot a 2. órajel végén írjuk be a kimeneti regiszterbe

// CLK      ________--------________--------________--------________--------______   
// PORT_ID  XXXXXXXXXX<        WRITE_PORT_ID         >XXXXXXXXXXXXXXXXXXXXXXXXXXXXX
// DATA_INPUT XXXXXXXX<        VALIID OUTPUT         >XXXXXXXXXXXXXXXXXXXXXXXXXXXXX     
// WRITE_STROBE_______________________----------------______________________________
// Kimenet átírása                                   ^ <- itt

  
module Basic_OUT(
    input clk,
    input rst,
    input wr_strobe,
    input [7:0] addr,
    input [7:0] out_data,                    // A vezérlõ kimeneti adata ezen a modulon bemenet
    output [7:0] out_signals
    );

parameter p_addr = 8'hff;                    // A cím alapértéke legyen hexa FF

wire p_sel;                                  // Periféria cím kiválasztás jel
wire p_write;                                // Periféria írás jel
reg [7:0] out_reg;                           // Kimeneti regiszter 

// Az alapfunkciót egyszerû adatkiadással valósítjuk meg
// A kimeneti adat egy regiszterbe kerül, ez fogja meghajtani a kimeneti vonalakat
// Tehát a kimeneti buszon egy írási ciklus ideig (2 órajel ciklus) megjelenõ dinamikus 
// adatot a regiszter egy statikus, stabil adattá alakítja (amíg újra nem írjuk)

assign p_sel = (addr == p_addr);             // A periféria cím dekódolása

assign p_write = p_sel & wr_strobe;          // Az írás parancs felismerése

always @ (posedge clk)                      
   if (rst)        out_reg <= 8'b0;          // RESET alatt a regiszter törölve
   else 
      if (p_write) out_reg <= out_data;      // Írásnál frissítve, egyébként tartja az állapotát


assign out_signals = out_reg;                // A regiszter tartalma közvetlenül megjelenik a kimeneten


endmodule