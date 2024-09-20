//******************************************************************************
//* MiniRISC CPU v2.0                                                          *
//*                                                                            *
//* A vez�rl�ssel kapcsolatos konstansok.                                      *
//******************************************************************************

//******************************************************************************
//* Reset �s megszak�t�s vetorok. Az adott esem�ny eset�n a megadott c�mre     *
//* ker�l a vez�rl�s.                                                          *
//******************************************************************************
localparam RST_VECTOR = 8'h00;      //Reset vektor
localparam INT_VECTOR = 8'h01;      //Megszak�t�s vektor


//******************************************************************************
//* ALU m�veletek.                                                             *
//******************************************************************************
localparam ALU_MOVE  = 2'b00;       //Adatmozgat�s
localparam ALU_ARITH = 2'b01;       //Aritmetikai m�veletek
localparam ALU_LOGIC = 2'b10;       //Bitenk�nti logikai m�veletek
localparam ALU_SHIFT = 2'b11;       //Shiftel�s/forgat�s


//******************************************************************************
//* Flag-ek.                                                                   *
//******************************************************************************
localparam Z_FLAG  = 0;             //Zero flag
localparam C_FLAG  = 1;             //Carry flag
localparam N_FLAG  = 2;             //Negative flag
localparam V_FLAG  = 3;             //Overflow flag
localparam IE_FLAG = 4;             //Megszak�t�s enged�lyez� flag
localparam IF_FLAG = 5;             //Megszak�t�s flag


//******************************************************************************
//* SP regiszter cime.                                                         *
//******************************************************************************
localparam SP_address = 4'b0000;

localparam PUSH = 1'b1;
localparam POP  = 1'b0;