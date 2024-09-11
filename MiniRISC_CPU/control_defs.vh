//******************************************************************************
//* MiniRISC CPU v2.0                                                          *
//*                                                                            *
//* A vezérléssel kapcsolatos konstansok.                                      *
//******************************************************************************

//******************************************************************************
//* Reset és megszakítás vetorok. Az adott esemény esetén a megadott címre     *
//* kerül a vezérlés.                                                          *
//******************************************************************************
localparam RST_VECTOR = 8'h00;      //Reset vektor
localparam INT_VECTOR = 8'h01;      //Megszakítás vektor


//******************************************************************************
//* ALU mûveletek.                                                             *
//******************************************************************************
localparam ALU_MOVE  = 2'b00;       //Adatmozgatás
localparam ALU_ARITH = 2'b01;       //Aritmetikai mûveletek
localparam ALU_LOGIC = 2'b10;       //Bitenkénti logikai mûveletek
localparam ALU_SHIFT = 2'b11;       //Shiftelés/forgatás


//******************************************************************************
//* Flag-ek.                                                                   *
//******************************************************************************
localparam Z_FLAG  = 0;             //Zero flag
localparam C_FLAG  = 1;             //Carry flag
localparam N_FLAG  = 2;             //Negative flag
localparam V_FLAG  = 3;             //Overflow flag
localparam IE_FLAG = 4;             //Megszakítás engedélyezõ flag
localparam IF_FLAG = 5;             //Megszakítás flag
