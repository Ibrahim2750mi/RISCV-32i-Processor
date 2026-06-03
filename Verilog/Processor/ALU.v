/*
ALU module: two 32-bit operands + 4-bit control → 32-bit result + zero flag.

ALU Control | Operation
--------------------------
  0000       AND
  0001       OR
  0010       ADD
  0011       SLL  (shift left logical)
  0100       SUB
  0101       SRL  (shift right logical)
  0110       SRA  (shift right arithmetic)
  0111       XOR
  1000       SLT  (signed less-than)
  1001       SLTU (unsigned less-than)
*/

module ALU (
    input  [31:0] in1,
    input  [31:0] in2,
    input  [3:0]  alu_control,
    output reg [31:0] alu_result,
    output reg        zero_flag
);

    always @(*) begin
        case (alu_control)
            4'b0000: alu_result = in1 & in2;
            4'b0001: alu_result = in1 | in2;
            4'b0010: alu_result = in1 + in2;
            4'b0011: alu_result = in1 << in2[4:0];
            4'b0100: alu_result = in1 - in2;
            4'b0101: alu_result = in1 >> in2[4:0];
            4'b0110: alu_result = $signed(in1) >>> in2[4:0];
            4'b0111: alu_result = in1 ^ in2;
            4'b1000: alu_result = ($signed(in1) < $signed(in2)) ? 32'd1 : 32'd0;
            4'b1001: alu_result = (in1 < in2)                   ? 32'd1 : 32'd0;
            default: alu_result = 32'hx;
        endcase

        zero_flag = (alu_result == 32'd0) ? 1'b1 : 1'b0;
    end

endmodule
