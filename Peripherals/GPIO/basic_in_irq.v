`timescale 1ns / 1ps

//******************************************************************************
//* Egyszerû 8 bites bemeneti modul megszakításkérési lehetõséggel a bemeneti  * 
//* jelek megváltozása esetén. A gpio_in bemenet 200 Hz-es mintavételezéssel   *
//* pergésmentesítve van.                                                      *
//*                                                                            *
//* A periféria címe paraméter átadással állítható be a felsõ szintû modulban. *
//* a GPIO modul megpéldányosításakor. A szintézis már ennek megfeleleõen az   *
//* aktuális BASEADDR báziscímmel történik.                                    *
//*                                                                            *
//* A programozói felület:                                                     *
//*                                                                            *
//* Cím         Típus   Bitek                                                  *
//* BASEADDR+0  RD      Adatregiszter                                          *
//*                     IN7   IN6   IN5   IN4   IN3   IN2   IN1   IN0          *
//* BASEADDR+1  RD/WR   Megszakítás engedélyezõ regiszter                      *
//*                     IE7   IE6   IE5   IE4   IE3   IE2   IE1   IE0          *
//* BASEADDR+2  RD/W1C  Megszakítás flag regiszter                             *
//*                     IF7   IF6   IF5   IF4   IF3   IF2   IF1   IF0          *
//*                                                                            *
//* A megszakítás flag regiszter bitjei 1 beírásával törölhetõek, ezzel        *
//* nyugtázva a megszakításkérést.                                             * 
//******************************************************************************
module basic_in_irq #(
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
   output reg  [7:0] s_slv2mst_data,   //Olvasási adatbusz
   
   //Megszakításkérõ kimenet.
   output wire       irq,
   
   //A GPIO interfész jelei.
   input  wire [7:0] gpio_in           //Az IO lábak aktuális értéke
);

//******************************************************************************
//* Címdekódolás.                                                              *
//******************************************************************************
//A periféria kiválasztó jele.
wire psel = ((s_mst2slv_addr >> 2) == (BASEADDR >> 2));

//Az adatregiszter olvasásának jelzése.
wire in_reg_rd = psel & s_mst2slv_rd & (s_mst2slv_addr[1:0] == 2'b00);

//A megszakítás engedélyezõ regiszter írásának és olvasásának jelzése.
wire ie_reg_wr = psel & s_mst2slv_wr & (s_mst2slv_addr[1:0] == 2'b01);
wire ie_reg_rd = psel & s_mst2slv_rd & (s_mst2slv_addr[1:0] == 2'b01);

//A megszakítás flag regiszter írásának és olvasásának jelzése.
wire if_reg_wr = psel & s_mst2slv_wr & (s_mst2slv_addr[1:0] == 2'b10);
wire if_reg_rd = psel & s_mst2slv_rd & (s_mst2slv_addr[1:0] == 2'b10);


//******************************************************************************
//* A 200 Hz-es engedélyezõ jel elõállítása a bemenet pergésmentesítéséhez.    *
//* A számláló modulusa: 16000000 Hz / 200 Hz = 80000 (79999-0).               * 
//******************************************************************************
reg  [16:0] clk_div_cnt;
wire        gpio_in_sample = (clk_div_cnt == 0);

always @(posedge clk)
begin
   if (rst || gpio_in_sample)
      clk_div_cnt <= 17'd79999;
   else
      clk_div_cnt <= clk_div_cnt - 17'd1;
end


//******************************************************************************
//* Az adatregiszter.                                                          *
//******************************************************************************
reg [7:0] in_reg;

always @(posedge clk)
begin
   if (rst)
      in_reg <= 8'd0;                  //Reset esetén töröljük a regisztert
   else
      if (gpio_in_sample)              //Egyébként 200 Hz-el folyamatosan
         in_reg <= gpio_in;            //mintavételezzük a bemenetet
end

//A bemeneti változás detektálása.
reg  [7:0] in_reg_prev;
wire [7:0] in_reg_changed = in_reg ^ in_reg_prev;

always @(posedge clk)
begin
   if (rst)
      in_reg_prev <= 8'd0;
   else
      in_reg_prev <= in_reg;
end


//******************************************************************************
//* A megszakítás engedélyezõ regiszter.                                       *
//******************************************************************************
reg [7:0] ie_reg;

always @(posedge clk)
begin
   if (rst)
      ie_reg <= 8'd0;                  //Reset: tiltjuk a megszakításokat
   else
      if (ie_reg_wr)
         ie_reg <= s_mst2slv_data;     //Regiszter írás
end


//******************************************************************************
//* A megszakítás flag regiszter.                                              *
//******************************************************************************
reg [7:0] if_reg;

integer i;

always @(posedge clk)
begin
   for (i = 0; i < 8; i = i + 1)
      if (rst)
         if_reg[i] <= 1'b0;            //Reset: a jelzések törlése
      else
         if (in_reg_changed[i])
            if_reg[i] <= 1'b1;         //A bemenet megváltozásának jelzése
         else
            if (if_reg_wr && s_mst2slv_data[i])
               if_reg[i] <= 1'b0;      //1 beírása esetén töröljük a jelzést
end

//A megszakításkérõ kimenet meghajtása.
assign irq = |(if_reg & ie_reg);


//******************************************************************************
//* Az olvasási adatbusz meghajtása.                                           *
//******************************************************************************
wire [2:0] dout_sel = {if_reg_rd, ie_reg_rd, in_reg_rd};

always @(*)
begin
   case (dout_sel)
      3'b001 : s_slv2mst_data <= in_reg;
      3'b010 : s_slv2mst_data <= ie_reg;
      3'b100 : s_slv2mst_data <= if_reg;
      default: s_slv2mst_data <= 8'd0;
   endcase
end

endmodule
