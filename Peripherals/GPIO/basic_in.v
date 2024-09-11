`timescale 1ns / 1ps

//******************************************************************************
//* Egyszerû 8 bites bemeneti modul. Semmi extra szolgáltatás, csak            * 
//* mintavételezés történik.                                                   *
//*                                                                            *
//* A periféria címe paraméter átadással állítható be a felsõ szintû modulban. *
//* a GPIO modul megpéldányosításakor. A szintézis már ennek megfeleleõen az   *
//* aktuális BASEADDR báziscímmel történik.                                    *
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
module basic_in #(
   //A periféria báziscíme.
   parameter BASEADDR = 8'hff
) (
   //Órajel és reset.
   input  wire       clk,              //Órajel
   input  wire       rst,              //Reset jel
   
   //A slave busz interfész jelei.
   input  wire [7:0] s_mst2slv_addr,   //Címbusz
   input  wire       s_mst2slv_rd,     //Olvasás engedélyezõ jel
   output wire [7:0] s_slv2mst_data,   //Olvasási adatbusz
   
   //A GPIO interfész jelei.
   input  wire [7:0] gpio_in           //Az IO lábak aktuális értéke
);

//******************************************************************************
//* Címdekódolás.                                                              *
//******************************************************************************
//A periféria kiválasztó jele.
wire psel = (s_mst2slv_addr == BASEADDR);

//A bemeneti adatregiszter olvasásának jelzése.
wire in_reg_rd = psel & s_mst2slv_rd;


//******************************************************************************
//* A bemeneti adatregiszter.                                                  *
//*                                                                            *
//* Az alapfunkciót egyszerû minavételezéssel valósítjuk meg, melyet minden    * 
//* órajel ciklusban elvégzünk.                                                *
//******************************************************************************
reg [7:0] in_reg;

always @(posedge clk)
begin
   if (rst)
      in_reg <= 8'd0;                  //Reset esetén töröljük a regisztert
   else
      in_reg <= gpio_in;               //Egyébként folyamatosan mintavételezzük
end                                    //az IO lábak értékét


//******************************************************************************
//* A processzor olvasási adatbuszának meghajtása. Az olvasási adatbuszra csak *
//* az olvasás ideje alatt kapcsoljuk rá a kért értéket, egyébként egy inaktív *
//* nulla érték jelenik meg rajta (elosztott busz multiplexer funkció).        *
//******************************************************************************
assign s_slv2mst_data = (in_reg_rd) ? in_reg : 8'd0;

endmodule
