/*
Control Unit: decodes opcode / funct3 / funct7 and drives every datapath mux
and enable signal for the full RV32I base integer ISA.

Control signals
---------------
  alu_control [3:0]  – selects ALU operation (see ALU.v)
  alu_src            – 0 = rs2, 1 = immediate (second ALU operand)
  regwrite           – enable register file write-back
  mem_read           – enable data memory read  (load instructions)
  mem_write          – enable data memory write (store instructions)
  mem_to_reg [1:0]   – write-back source: 00=ALU, 01=MEM, 10=PC+4
  branch             – instruction is a conditional branch
  jump               – instruction is an unconditional jump (jal / jalr)
  jalr               – disambiguates jalr from jal (target = rs1+imm)
  auipc              – add upper immediate to PC
  lui                – load upper immediate (pass imm straight to rd)
*/

module CONTROL (
    input  [6:0] opcode,
    input  [2:0] funct3,
    input  [6:0] funct7,
    output reg [3:0] alu_control,
    output reg       alu_src,
    output reg       regwrite,
    output reg       mem_read,
    output reg       mem_write,
    output reg [1:0] mem_to_reg,
    output reg       branch,
    output reg       jump,
    output reg       jalr,
    output reg       auipc,
    output reg       lui,
    output reg [2:0] funct3_out   // forwarded for load/store/branch sizing
);

    always @(*) begin
        // defaults – safe no-op
        alu_control = 4'b0010;
        alu_src     = 1'b0;
        regwrite    = 1'b0;
        mem_read    = 1'b0;
        mem_write   = 1'b0;
        mem_to_reg  = 2'b00;
        branch      = 1'b0;
        jump        = 1'b0;
        jalr        = 1'b0;
        auipc       = 1'b0;
        lui         = 1'b0;
        funct3_out  = funct3;

        case (opcode)

            // ----------------------------------------------------------------
            // R-type arithmetic / logic
            // ----------------------------------------------------------------
            7'b0110011: begin
                regwrite = 1'b1;
                case (funct3)
                    3'h0: alu_control = (funct7[5]) ? 4'b0100 : 4'b0010; // SUB : ADD
                    3'h4: alu_control = 4'b0111; // XOR
                    3'h6: alu_control = 4'b0001; // OR
                    3'h7: alu_control = 4'b0000; // AND
                    3'h1: alu_control = 4'b0011; // SLL
                    3'h5: alu_control = (funct7[5]) ? 4'b0110 : 4'b0101; // SRA : SRL
                    3'h2: alu_control = 4'b1000; // SLT
                    3'h3: alu_control = 4'b1001; // SLTU
                endcase
            end

            // ----------------------------------------------------------------
            // I-type ALU immediate
            // ----------------------------------------------------------------
            7'b0010011: begin
                regwrite   = 1'b1;
                alu_src    = 1'b1;
                case (funct3)
                    3'h0: alu_control = 4'b0010; // ADDI
                    3'h4: alu_control = 4'b0111; // XORI
                    3'h6: alu_control = 4'b0001; // ORI
                    3'h7: alu_control = 4'b0000; // ANDI
                    3'h1: alu_control = 4'b0011; // SLLI
                    3'h5: alu_control = (funct7[5]) ? 4'b0110 : 4'b0101; // SRAI : SRLI
                    3'h2: alu_control = 4'b1000; // SLTI
                    3'h3: alu_control = 4'b1001; // SLTIU
                endcase
            end

            // ----------------------------------------------------------------
            // Load instructions
            // ----------------------------------------------------------------
            7'b0000011: begin
                regwrite   = 1'b1;
                alu_src    = 1'b1;
                alu_control = 4'b0010; // address = rs1 + imm
                mem_read   = 1'b1;
                mem_to_reg = 2'b01;
            end

            // ----------------------------------------------------------------
            // Store instructions
            // ----------------------------------------------------------------
            7'b0100011: begin
                alu_src    = 1'b1;
                alu_control = 4'b0010; // address = rs1 + imm
                mem_write  = 1'b1;
            end

            // ----------------------------------------------------------------
            // Branch instructions
            // ----------------------------------------------------------------
            7'b1100011: begin
                branch     = 1'b1;
                alu_src    = 1'b0;
                case (funct3)
                    3'h0: alu_control = 4'b0100; // BEQ  → SUB, check zero
                    3'h1: alu_control = 4'b0100; // BNE  → SUB, check !zero
                    3'h4: alu_control = 4'b1000; // BLT  → SLT
                    3'h5: alu_control = 4'b1000; // BGE  → SLT, check 0
                    3'h6: alu_control = 4'b1001; // BLTU → SLTU
                    3'h7: alu_control = 4'b1001; // BGEU → SLTU, check 0
                    default: alu_control = 4'b0100;
                endcase
            end

            // ----------------------------------------------------------------
            // JAL
            // ----------------------------------------------------------------
            7'b1101111: begin
                regwrite   = 1'b1;
                jump       = 1'b1;
                mem_to_reg = 2'b10; // write-back PC+4
            end

            // ----------------------------------------------------------------
            // JALR
            // ----------------------------------------------------------------
            7'b1100111: begin
                regwrite   = 1'b1;
                jump       = 1'b1;
                jalr       = 1'b1;
                alu_src    = 1'b1;
                alu_control = 4'b0010; // target = rs1 + imm
                mem_to_reg = 2'b10;
            end

            // ----------------------------------------------------------------
            // LUI
            // ----------------------------------------------------------------
            7'b0110111: begin
                regwrite = 1'b1;
                lui      = 1'b1;
            end

            // ----------------------------------------------------------------
            // AUIPC
            // ----------------------------------------------------------------
            7'b0010111: begin
                regwrite    = 1'b1;
                auipc       = 1'b1;
                alu_src     = 1'b1;
                alu_control = 4'b0010;
            end

            default: ;

        endcase
    end

endmodule
