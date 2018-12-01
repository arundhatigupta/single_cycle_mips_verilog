//--------------------------------------------------------------

// single-cycle MIPS processor
module mips(input         clk, reset,
            output [31:0] pc,
            input  [31:0] instr,
            output        memwrite,
            output [31:0] aluout, writedata,
            input  [31:0] readdata);

  wire        branch, memtoreg,
              pcsrc, zero, spra,
              alusrc, regwrite, spregwrite, jump, jal, jumpreg, readhilo;
  wire [1:0]  regdst;
  wire [3:0]  alucontrol;

  controller c(instr[31:26], instr[5:0], instr[10:6], zero,
               memwrite, pcsrc,
               alusrc, regwrite, spregwrite, regdst, memtoreg, jump, jal, jumpreg,
               alucontrol, spra, readhilo);
  datapath dp(clk, reset, memtoreg, pcsrc,
              alusrc, regdst, regwrite, spregwrite, jump, jal, jumpreg, instr[10:6],
              alucontrol,
              zero, pc, instr,
              aluout, writedata, readdata, spra, readhilo);
endmodule

module controller(input  [5:0] op, funct,
				  input  [4:0] shamt,
                  input        zero,
                  output       memwrite,
                  output       pcsrc, alusrc,
                  output       regwrite, spregwrite,
                  output [1:0] regdst, 
                  output       memtoreg,
                  output       jump, jal, jumpreg,
                  output [3:0] alucontrol,
                  output       spra, readhilo);

  wire [3:0] aluop;
  wire       branch;

  maindec md(op, funct, memwrite, branch,
             alusrc, regwrite, spregwrite, regdst, memtoreg, jump, jal,
             aluop, spra, readhilo);
  aludec  ad(funct, shamt, aluop, alucontrol, jumpreg);

  assign pcsrc = branch & zero;
endmodule

module maindec(input  [5:0] op, funct,
               output       memwrite,
               output       branch, alusrc,
               output       regwrite, spregwrite,
               output [1:0] regdst, 
               output       memtoreg,
               output       jump, jal,
               output [3:0] aluop,
               output reg   spra,
               output       readhilo);

  reg [14:0] controls;

  assign {regwrite, regdst, alusrc,
          branch, memwrite,
          memtoreg, jump, jal, aluop, spregwrite, readhilo} = controls;

  always @(*)
    case(op)
      6'b000000: 
      	begin
      		case(funct)
      			6'b011000: controls <= 15'b101000000001010; //mult
      			6'b011010: controls <= 15'b101000000001010; //div
      			default:   
      			  begin
      			    case(funct)
      			      6'b010000: 
      			        begin
      			          spra <= 1'b1;
      			          controls <= 15'b101000000001001;
      			        end
      			      6'b010010: 
      			        begin
      			          spra <= 1'b0;
      			          controls <= 15'b101000000001001;
      			        end
      			      default: controls <= 15'b101000000001000; //other R-type
      			    endcase
      			  end
      		endcase
      	end
      6'b100011: controls <= 15'b100100100000000; //LW
      6'b101011: controls <= 15'b000101000000000; //SW
      6'b000100: controls <= 15'b000010000000100; //BEQ
      6'b001000: controls <= 15'b100100000000000; //ADDI
      6'b000010: controls <= 15'b000000010000000; //J
      6'b000011: controls <= 15'b111000011000000; //JAL
      6'b001100: controls <= 15'b100100000010000; //ANDI
      6'b001101: controls <= 15'b100100000010100; //ORI
      6'b001010: controls <= 15'b100100000011100; //SLTI
      6'b001111: controls <= 15'b100100000100000; //LUI
      default:   controls <= 15'bxxxxxxxxxxxxxx; //???
    endcase
endmodule

module aludec(input      [5:0] funct,
              input      [4:0] shamt,
              input      [3:0] aluop,
              output reg [3:0] alucontrol,
              output     jumpreg);

  always @(*)
    case(aluop)
      4'b0000: alucontrol <= 4'b0010;  // add
      4'b0001: alucontrol <= 4'b0110;  // sub
      4'b0100: alucontrol <= 4'b0000;	 // and
      4'b0101: alucontrol <= 4'b0001;  // or
      4'b0111: alucontrol <= 4'b0111;  // slt
      4'b1000: alucontrol <= 4'b1000;  // lui
      default: case(funct)          // RTYPE
          6'b100000: alucontrol <= 4'b0010; // ADD
          6'b100010: alucontrol <= 4'b0110; // SUB
          6'b100100: alucontrol <= 4'b0000; // AND
          6'b100101: alucontrol <= 4'b0001; // OR
          6'b101010: alucontrol <= 4'b0111; // SLT
          6'b000000: alucontrol <= 4'b0011; // SLL
          6'b000010: alucontrol <= 4'b0100; // SRL
          6'b000011: alucontrol <= 4'b0101; // SRA
          6'b000100: alucontrol <= 4'b1011; // SLLV
          6'b000110: alucontrol <= 4'b1100; // SRLV
          6'b011000: alucontrol <= 4'b1010; // MULT
          6'b011010: alucontrol <= 4'b1110; // DIV
          default:   alucontrol <= 4'bxxxx; // ???
        endcase
    endcase
    assign jumpreg = (funct == 6'b001000) ? 1 : 0;
endmodule

module datapath(input         clk, reset,
                input         memtoreg, 
                input         pcsrc,
                input         alusrc, 
                input  [1:0]  regdst,
                input         regwrite, spregwrite, jump, jal, jumpreg,
                input  [4:0]  shamt,
                input  [3:0]  alucontrol,
                output        zero,
                output [31:0] pc,
                input  [31:0] instr,
                output [31:0] aluout, writedata,
                input  [31:0] readdata,
                input         spra, readhilo);

  wire [4:0]  writereg;
  wire [31:0] pcnextjr, pcnext, pcnextbr, pcplus4, pcbranch;
  wire [31:0] signimm, signimmsh;
  wire [31:0] srca, srcb, wd0, wd1, sprd;
  wire [31:0] result, resultjal, resulthilo;

  // next PC logic
  flopr #(32) pcreg(clk, reset, pcnext, pc);
  adder       pcadd1(pc, 32'b100, pcplus4);
  sl2         immsh(signimm, signimmsh);
  adder       pcadd2(pcplus4, signimmsh, pcbranch);
  mux2 #(32)  pcbrmux(pcplus4, pcbranch, pcsrc,
                      pcnextbr);
  mux2 #(32)  pcmux(pcnextbr, {pcplus4[31:28], 
                    instr[25:0], 2'b00}, 
                    jump, pcnext);
  mux2 #(32)  pcmuxjr(pcnext, srca, 
                    jumpreg, pcnextjr);


  // register file logic
  regfile     rf(clk, regwrite, instr[25:21],
                 instr[20:16], writereg,
                 resulthilo, srca, writedata);
  mux3 #(5)   wrmux(instr[20:16], instr[15:11], 5'b11111,
                    regdst, writereg);
  mux2 #(32)  resmux(aluout, readdata,
                     memtoreg, result);
  mux2 #(32)  wrmuxjal(result, pcplus4, jal,
                      resultjal);
  mux2 #(32)  wrmuxhilo(resultjal, sprd, readhilo, resulthilo);
  signext     se(instr[15:0], signimm);

  // ALU logic
  mux2 #(32)  srcbmux(writedata, signimm, alusrc,
                      srcb);
  alu         alu(srca, srcb, shamt, alucontrol,
                  aluout, wd0, wd1, zero);
  // special register file logic
  spregfile   sprf(clk, spregwrite, spra, wd0, wd1, sprd);
endmodule