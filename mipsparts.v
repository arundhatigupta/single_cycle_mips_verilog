//------------------------------------------------
// mipsparts.v
// Components used in MIPS processor
//------------------------------------------------

module alu(input      [31:0] a, b, 
           input      [4:0]  shamt,
           input      [3:0]  alucont, 
           output reg [31:0] result, wd0, wd1,
           output            zero);

  wire [31:0] b2, sum, slt, sra_sign, sra_aux;
  wire [63:0] product, quotient, remainder;
 
  assign b2 = alucont[2] ? ~b:b; 
  assign sum = a + b2 + alucont[2];
  assign slt = sum[31];
  assign sra_sign = 32'b1111_1111_1111_1111 << (32 - shamt);
  assign sra_aux = b >> shamt;
  assign product = a * b;
  assign quotient = a / b;
  assign remainder = a % b;

  always@(*)
    case(alucont[3:0])
      4'b0000: result <= a & b;
      4'b0001: result <= a | b;
      4'b0010: result <= sum;
      4'b0011: result <= b << shamt;
      4'b1011: result <= b << a;
      4'b0100: result <= b >> shamt;
      4'b1100: result <= b >> a;
      4'b0101: result <= sra_sign | sra_aux;
      4'b0110: result <= sum;
      4'b0111: result <= slt;
      4'b1010: 
        begin
          result <= product[31:0]; 
          wd0    <= product[31:0];
          wd1    <= product[63:32];
        end
      4'b1110: 
        begin
          result <= quotient; 
          wd0    <= quotient;
          wd1    <= remainder;
        end
      4'b1000: result <= b << 5'd16;
    endcase

  assign zero = (result == 32'd0);
endmodule

module regfile(input         clk, 
               input         we3, 
               input  [4:0]  ra1, ra2, wa3, 
               input  [31:0] wd3, 
               output [31:0] rd1, rd2);

  reg [31:0] rf[31:0];

  // three ported register file
  // read two ports combinationally
  // write third port on rising edge of clock
  // register 0 hardwired to 0

  always @(posedge clk)
    if (we3) rf[wa3] <= wd3;	

  assign rd1 = (ra1 != 0) ? rf[ra1] : 0;
  assign rd2 = (ra2 != 0) ? rf[ra2] : 0;
endmodule

module spregfile(input       clk, 
               input         we, 
               input         ra, 
               input  [31:0] wd0, wd1, 
               output [31:0] rd);

  reg [31:0] rf[1:0];

  // three ported register file
  // read two ports combinationally
  // write third port on rising edge of clock
  // register 0 hardwired to 0

  always @(posedge clk)
    if (we == 1'b1)
      begin
        rf[1'b0] <= wd0;
        rf[1'b1] <= wd1;
      end
   assign rd = (ra != 1'b0) ? rf[1'b1] : rf[1'b0];
endmodule

module adder(input [31:0] a, b,
             output [31:0] y);

  assign y = a + b;
endmodule

module sl2(input  [31:0] a,
           output [31:0] y);

  // shift left by 2
  assign y = {a[29:0], 2'b00};
endmodule

module signext(input  [15:0] a,
               output [31:0] y);
              
  assign y = {{16{a[15]}}, a};
endmodule

module flopr #(parameter WIDTH = 8)
              (input                  clk, reset,
               input      [WIDTH-1:0] d, 
               output reg [WIDTH-1:0] q);

  always @(posedge clk, posedge reset)
    if (reset) q <= 0;
    else       q <= d;
endmodule

module flopenr #(parameter WIDTH = 8)
                (input                  clk, reset,
                 input                  en,
                 input      [WIDTH-1:0] d, 
                 output reg [WIDTH-1:0] q);
 
  always @(posedge clk, posedge reset)
    if      (reset) q <= 0;
    else if (en)    q <= d;
endmodule

module mux2 #(parameter WIDTH = 8)
             (input  [WIDTH-1:0] d0, d1, 
              input              s, 
              output [WIDTH-1:0] y);

  assign y = s ? d1 : d0; 
endmodule

module mux3 #(parameter WIDTH = 8)
             (input  [WIDTH-1:0] d0, d1, d2,
              input  [1:0]            s, 
              output [WIDTH-1:0] y);

  assign y = (s == 2'b00) ? d0 : ((s == 2'b01) ? d1 : d2); 
endmodule
