`timescale 1ns / 1ps

//******************************************************************************
//* Visszaolvasható 8 bites kimeneti modul. A kimeneti adat visszaolvasható a  *
//* RMW (Read-Modify-Write) típusú mûveletekhez.                               *
//*                                                                            *
//* A periféria címe paraméter átadással állítható be a felsõ szintû modulban. *
//* a GPIO modul megpéldányosításakor. A szintézis már ennek megfeleleõen az   *
//* aktuális BASEADDR báziscímmel történik.                                    *
//*                                                                            *
//* A processzor írási (WRITE) ciklusának idõdiagramja:                        *
//* Az írási ciklust az 1 órajel ciklus ideig aktív S_MST2SLV_WR jel jelzi. Az *
//* írási ciklus ideje alatt a cím és a kimeneti adat stabil.                  *
//*                                                                            *
//*                     --------          --------          --------           *
//* CLK                |        |        |        |        |        |          *
//*                ----          --------          --------          ----      *
//*                                        ------------------                  *
//* S_MST2SLV_WR                          /                  \                 *
//*                -----------------------                    -----------      *
//*                ----------------------- ------------------ -----------      *
//* S_MST2SLV_ADDR                        X   ÉRVÉNYES CÍM   X                 *
//*                ----------------------- ------------------ -----------      *
//*                ----------------------- ------------------ -----------      *
//* S_MST2SLV_DATA                        X   ÉRVÉNYES ADAT  X                 *
//*                ----------------------- ------------------ -----------      *
//*                                                        ^                   *
//*                                Az írási parancs végrehajtása itt történik. *
//*                                                                            *
//* A processzor olvasási (READ) ciklusának idõdiagramja:                      *
//* Az olvasási ciklust az 1 órajel ciklus ideig aktív S_MST2SLV_RD jel jelzi. *
//* Az olvasási ciklus ideje alatt a cím stabil és a kiválasztott periféria az *
//* olvasási adatbuszra kapuzza az adatot. Az olvasási ciklus elõtt és után    *
//* az olvasási adatbusz értéke inaktív 0 kell, hogy legyen.                   *
//*                                                                            *
//*                     --------          --------          --------           *
//* CLK                |        |        |        |        |        |          *
//*                ----          --------          --------          ----      *
//*                                        ------------------                  *
//* S_MST2SLV_RD                          /                  \                 *
//*                -----------------------                    -----------      *
//*                ----------------------- ------------------ -----------      *
//* S_MST2SLV_ADDR                        X   ÉRVÉNYES CÍM   X                 *
//*                ----------------------- ------------------ -----------      *
//*                ----------------------- ------------------ -----------      *
//* S_SLV2MST_DATA           0            X   ÉRVÉNYES ADAT  X       0         *
//*                ----------------------- ------------------ -----------      *
//*                                                        ^                   *
//*                              A bemeneti adat mintavételezése itt történik. *  
//******************************************************************************
module basic_owr #(
   //A periféria báziscíme.
   parameter BASEADDR = 8'hff
) (
   //Órajel és reset.
   input  wire       clk,              //Órajel
   input  wire       rst,              //Reset jel
   
   //A slave busz interfész jelei.
   input  wire [7:0] s_mst2slv_addr,   //Címbusz
   input  wire       s_mst2slv_wr,     //Írás engedélyezõ jel
   input  wire       s_mst2slv_rd,     //Olvasás engedélyezõ jel
   input  wire [7:0] s_mst2slv_data,   //Írási adatbusz
   output wire [7:0] s_slv2mst_data,   //Olvasási adatbusz
   
   //A GPIO interfész jelei.
   output wire [7:0] gpio_out          //Az IO lábakra kiírandó adat
);
  
//******************************************************************************
//* Címdekódolás.                                                              *
//******************************************************************************
//A periféria kiválasztó jele.
wire psel = (s_mst2slv_addr == BASEADDR);

//A kimeneti adatregiszter írásának és olvasásának jelzése.
wire out_reg_wr = psel & s_mst2slv_wr;
wire out_reg_rd = psel & s_mst2slv_rd;


//******************************************************************************
//* A kimeneti adatregiszter.                                                  *
//*                                                                            *
//* Az alapfunkciót egyszerû adatkiadással valósítjuk meg. A kimeneti adat     *
//* egy regiszterbe kerül, ez fogja meghajtani a kimeneti vonalakat. Tehát a   *
//* kimeneti buszon egy írási ciklus ideig megjelenõ  dinamikus a regiszter    *
//* egy statikus, stabil adattá alakítja (amíg újra nem írjuk).                *
//******************************************************************************
reg [7:0] out_reg;

always @(posedge clk)
begin
   if (rst)
      out_reg <= 8'd0;                 //Reset esetén töröljük a regisztert
   else
      if (out_reg_wr)
         out_reg <= s_mst2slv_data;    //Kimeneti adatregiszter írása
end

//A kimeneti lábak meghajtása.
assign gpio_out = out_reg;


//******************************************************************************
//* A processzor olvasási adatbuszának meghajtása. Az olvasási adatbuszra csak *
//* az olvasás ideje alatt kapcsoljuk rá a kért értéket, egyébként egy inaktív *
//* nulla érték jelenik meg rajta (elosztott busz multiplexer funkció).        *
//******************************************************************************
assign s_slv2mst_data = (out_reg_rd) ? out_reg : 8'd0;

endmodule
