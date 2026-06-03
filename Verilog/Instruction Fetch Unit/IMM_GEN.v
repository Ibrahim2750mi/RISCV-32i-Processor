/*
Immediate Generator: sign-extends the immediate field of an instruction
based on its format type (determined by opcode).

  I-type : addi, lw, jalr, load instructions
  S-type : store instructions
  B-type : branch instructions
  U-type : lui, auipc
  J-type : jal
*/

module IMM_GEN (
    input  [31:0] instruction,
    output reg [31:0] imm_out
);

    wire [6:0] opcode = instruction[6:0];

    always @(*) begin
        case (opcode)
            7'b0010011, // I-type ALU immediate
            7'b0000011, // I-type Load
            7'b1100111: // jalr
                imm_out = {{20{instruction[31]}}, instruction[31:20]};

            7'b0100011: // S-type Store
                imm_out = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};

            7'b1100011: // B-type Branch
                imm_out = {{19{instruction[31]}}, instruction[31], instruction[7],
                           instruction[30:25], instruction[11:8], 1'b0};

            7'b0110111, // lui
            7'b0010111: // auipc
                imm_out = {instruction[31:12], 12'b0};

            7'b1101111: // J-type jal
                imm_out = {{11{instruction[31]}}, instruction[31], instruction[19:12],
                           instruction[20], instruction[30:21], 1'b0};

            default: imm_out = 32'h0;
        endcase
    end

endmodule
