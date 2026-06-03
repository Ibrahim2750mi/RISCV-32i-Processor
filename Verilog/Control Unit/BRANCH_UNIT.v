/*
Branch Unit: given funct3 of a B-type instruction and the ALU zero flag
(plus the ALU SLT/SLTU result), decides whether the branch is taken.
*/

module BRANCH_UNIT (
    input  [2:0] funct3,
    input        zero_flag,
    input  [31:0] alu_result,
    output reg   branch_taken
);

    always @(*) begin
        case (funct3)
            3'h0: branch_taken =  zero_flag;            // BEQ
            3'h1: branch_taken = ~zero_flag;            // BNE
            3'h4: branch_taken =  alu_result[0];        // BLT  (SLT result)
            3'h5: branch_taken = ~alu_result[0];        // BGE
            3'h6: branch_taken =  alu_result[0];        // BLTU (SLTU result)
            3'h7: branch_taken = ~alu_result[0];        // BGEU
            default: branch_taken = 1'b0;
        endcase
    end

endmodule
