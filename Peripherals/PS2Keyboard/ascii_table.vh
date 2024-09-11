//******************************************************************************
//* A numerikus billentyûk scan kódjához tartozó ASCII kódok, ha a SHIFT       *
//* billentyû nincs lenyomva.                                                  *
//******************************************************************************
function [7:0] numpad_normal;
   input [7:0] scan_code;
   
   begin
      case (scan_code)
         8'h77  : numpad_normal = 8'h00;     //Num Lock
         8'hca  : numpad_normal = "/";
         8'h7c  : numpad_normal = "*";
         8'h7b  : numpad_normal = "-";
         8'h6c  : numpad_normal = "7";       //Numpad 7, (Home)
         8'h75  : numpad_normal = "8";       //Numpad 8, (Up)
         8'h7d  : numpad_normal = "9";       //Numpad 9, (Page up)
         8'h79  : numpad_normal = "+";
         8'h6b  : numpad_normal = "4";       //Numpad 4, (Left)
         8'h73  : numpad_normal = "5";       //Numpad 5
         8'h74  : numpad_normal = "6";       //Numpad 6, (Right)
         8'h69  : numpad_normal = "1";       //Numpad 1, (End)
         8'h72  : numpad_normal = "2";       //Numpad 2, (Down)
         8'h7a  : numpad_normal = "3";       //Numpad 3, (Page down)
         8'hda  : numpad_normal = 8'h0a;     //Numpad Enter
         8'h70  : numpad_normal = "0";       //Numpad 0, (Insert)
         8'h71  : numpad_normal = ".";       //Numpad ., (Delete)
         default: numpad_normal = 8'h00;
      endcase
   end
endfunction

//******************************************************************************
//* A numerikus billentyûk scan kódjához tartozó ASCII kódok, ha a SHIFT       *
//* billentyû le van nyomva.                                                   *
//******************************************************************************
function [7:0] numpad_shift;
   input [7:0] scan_code;
   
   begin
      case (scan_code)
         8'h77  : numpad_shift = 8'h00;      //Num Lock
         8'hca  : numpad_shift = "/";
         8'h7c  : numpad_shift = "*";
         8'h7b  : numpad_shift = "-";
         
         8'h6c  : numpad_shift = "7";       //Numpad 7, (Home)
         8'h75  : numpad_shift = "8";       //Numpad 8, (Up)
         8'h7d  : numpad_shift = "9";       //Numpad 9, (Page up)
         8'h79  : numpad_shift = "+";
         8'h6b  : numpad_shift = "4";       //Numpad 4, (Left)
         8'h73  : numpad_shift = "5";       //Numpad 5
         8'h74  : numpad_shift = "6";       //Numpad 6, (Right)
         8'h69  : numpad_shift = "1";       //Numpad 1, (End)
         8'h72  : numpad_shift = "2";       //Numpad 2, (Down)
         8'h7a  : numpad_shift = "3";       //Numpad 3, (Page down)
         8'hda  : numpad_shift = 8'h0a;     //Numpad Enter
         8'h70  : numpad_shift = "0";       //Numpad 0, (Insert)
         8'h71  : numpad_shift = ".";       //Numpad ., (Delete)
         default: numpad_shift = 8'h00;
      endcase
   end
endfunction


