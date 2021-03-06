module add (in_1,in_2,out_1,overflow);
  input [3:0] in_1,in_2;
  output [3:0] out_1;
  output overflow;
  
  wire [3:0] in_1,in_2;
  wire [3:0] out_1;
  wire  [4:0] out_data;
  wire overflow;
  
  assign out_data = in_1 - in_2;
  assign overflow=out_data[4];
  assign out_1=out_data[3:0];
  
endmodule

  

