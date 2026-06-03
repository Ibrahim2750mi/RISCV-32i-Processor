/*
RV32I processor with a two-phase fetch/execute FSM.

Because the project interface uses ONE shared memory bus for both
instruction fetch and data load/store, we cannot do both in the same
clock edge. I have thus choosen a minimal 2-state FSM:

  FETCH   : drive mem_addr = PC, mem_wmask = 0, mem_rstrb = 1
            latch mem_rdata into instr_reg on the next posedge.
  EXECUTE : decode instr_reg, drive ALU, drive mem for load/store,
            compute next_PC, advance PC.
*/

`include "ALU.v"
`include "REG_FILE.v"
`include "CONTROL.v"
`include "BRANCH_UNIT.v"
`include "IMM_GEN.v"
`include "LOAD_EXTRACTOR.v"
`include "STORE_UNIT.v"

module riscv_processor (
    input         clk,
    output reg [31:0] mem_addr,
    output [31:0] mem_wdata,
    output [3:0]  mem_wmask,
    input  [31:0] mem_rdata,
    output        mem_rstrb,
    input         mem_rbusy,
    input         mem_wbusy,
    input         reset
);

    // ----------------------------------------------------------------
    // FSM: 0 = FETCH, 1 = EXECUTE
    // ----------------------------------------------------------------
    reg  state;
    localparam FETCH   = 1'b0;
    localparam EXECUTE = 1'b1;

    wire stall_fetch  = (state == FETCH)                     && mem_rbusy;
    wire stall_load   = (state == EXECUTE && mem_read)       && mem_rbusy;
    wire stall_store  = (state == EXECUTE && mem_write_ctrl) && mem_wbusy;
    wire stall        = stall_fetch | stall_load | stall_store;

    // ----------------------------------------------------------------
    // Program Counter & instruction register
    // ----------------------------------------------------------------
    reg [31:0] PC;
    reg [31:0] instr_reg;

    wire [31:0] PC_plus4 = PC + 32'd4;

    // ----------------------------------------------------------------
    // Instruction field extraction (from latched register)
    // ----------------------------------------------------------------
    wire [6:0] opcode = instr_reg[6:0];
    wire [4:0] rd     = instr_reg[11:7];
    wire [2:0] funct3 = instr_reg[14:12];
    wire [4:0] rs1    = instr_reg[19:15];
    wire [4:0] rs2    = instr_reg[24:20];
    wire [6:0] funct7 = instr_reg[31:25];

    // ----------------------------------------------------------------
    // Immediate Generator
    // ----------------------------------------------------------------
    wire [31:0] imm_out;
    IMM_GEN imm_gen (
        .instruction (instr_reg),
        .imm_out     (imm_out)
    );

    // ----------------------------------------------------------------
    // Control Unit
    // ----------------------------------------------------------------
    wire [3:0] alu_control;
    wire       alu_src;
    wire       regwrite;
    wire       mem_read;
    wire       mem_write_ctrl;
    wire [1:0] mem_to_reg;
    wire       branch;
    wire       jump;
    wire       jalr_flag;
    wire       auipc_flag;
    wire       lui_flag;
    wire [2:0] funct3_ctrl;

    CONTROL control_unit (
        .opcode     (opcode),
        .funct3     (funct3),
        .funct7     (funct7),
        .alu_control(alu_control),
        .alu_src    (alu_src),
        .regwrite   (regwrite),
        .mem_read   (mem_read),
        .mem_write  (mem_write_ctrl),
        .mem_to_reg (mem_to_reg),
        .branch     (branch),
        .jump       (jump),
        .jalr       (jalr_flag),
        .auipc      (auipc_flag),
        .lui        (lui_flag),
        .funct3_out (funct3_ctrl)
    );

    // ----------------------------------------------------------------
    // Register File
    // Only write during EXECUTE and only when not stalled
    // ----------------------------------------------------------------
    wire [31:0] read_data1;
    wire [31:0] read_data2;
    wire [31:0] write_back_data;

    wire regwrite_en = regwrite && (state == EXECUTE) && !stall;

    REG_FILE reg_file (
        .read_reg_num1 (rs1),
        .read_reg_num2 (rs2),
        .write_reg     (rd),
        .write_data    (write_back_data),
        .read_data1    (read_data1),
        .read_data2    (read_data2),
        .regwrite      (regwrite_en),
        .clock         (clk),
        .reset         (reset)
    );

    // ----------------------------------------------------------------
    // ALU
    // in1: rs1 value, or PC for AUIPC
    // in2: rs2 value, or sign-extended immediate when alu_src = 1
    // ----------------------------------------------------------------
    wire [31:0] alu_in1 = auipc_flag ? PC      : read_data1;
    wire [31:0] alu_in2 = alu_src    ? imm_out : read_data2;
    wire [31:0] alu_result;
    wire        zero_flag;

    ALU alu (
        .in1         (alu_in1),
        .in2         (alu_in2),
        .alu_control (alu_control),
        .alu_result  (alu_result),
        .zero_flag   (zero_flag)
    );

    // ----------------------------------------------------------------
    // Branch Unit
    // ----------------------------------------------------------------
    wire branch_taken_raw;
    wire branch_taken = branch_taken_raw & branch;

    BRANCH_UNIT branch_unit (
        .funct3       (funct3),
        .zero_flag    (zero_flag),
        .alu_result   (alu_result),
        .branch_taken (branch_taken_raw)
    );

    // ----------------------------------------------------------------
    // PC next-value mux
    // ----------------------------------------------------------------
    wire [31:0] branch_target = PC + imm_out;
    wire [31:0] jalr_target   = alu_result & ~32'd1;

    wire [31:0] next_PC = (jump && jalr_flag) ? jalr_target  :
                          jump                ? branch_target :
                          branch_taken        ? branch_target :
                                               PC_plus4;

    // ----------------------------------------------------------------
    // Store Unit
    // ----------------------------------------------------------------
    wire [31:0] store_data;
    wire [3:0]  store_mask;

    STORE_UNIT store_unit (
        .rs2_data    (read_data2),
        .byte_offset (alu_result[1:0]),
        .funct3      (funct3),
        .store_data  (store_data),
        .store_mask  (store_mask)
    );

    // ----------------------------------------------------------------
    // Load Extractor
    // ----------------------------------------------------------------
    wire [31:0] load_data;

    LOAD_EXTRACTOR load_ext (
        .raw_data    (mem_rdata),
        .byte_offset (alu_result[1:0]),
        .funct3      (funct3),
        .load_data   (load_data)
    );

    // ----------------------------------------------------------------
    // Write-back MUX
    // ----------------------------------------------------------------
    assign write_back_data =
        lui_flag              ? imm_out    :
        (mem_to_reg == 2'b01) ? load_data  :
        (mem_to_reg == 2'b10) ? PC_plus4   :
                                alu_result;

    // ----------------------------------------------------------------
    // Memory interface outputs: combinational, phase-gated
    //
    // FETCH: addr=PC,             wmask=0000, rstrb=1
    // EXECUTE: addr=alu_result    wmask=store_mask (store only)
    //                             rstrb=1 for loads, 0 otherwise
    // ----------------------------------------------------------------
    always @(*) begin
        case (state)
            FETCH:   mem_addr = PC;
            EXECUTE: mem_addr = (mem_read || mem_write_ctrl) ? alu_result : PC;
            default: mem_addr = PC;
        endcase
    end

    assign mem_wmask = (state == EXECUTE && mem_write_ctrl) ? store_mask : 4'b0000;
    assign mem_wdata = store_data;
    assign mem_rstrb = (state == FETCH) || (state == EXECUTE && mem_read);

    // ----------------------------------------------------------------
    // FSM: all state transitions gated by stall.
    // ----------------------------------------------------------------
    always @(posedge clk) begin
        if (reset) begin
            state     <= FETCH;
            PC        <= 32'h0;
            instr_reg <= 32'h00000013; // NOP: addi x0,x0,0
        end else if (!stall) begin
            case (state)
                FETCH: begin
                    instr_reg <= mem_rdata;
                    state     <= EXECUTE;
                end
                EXECUTE: begin
                    PC    <= next_PC;
                    state <= FETCH;
                end
            endcase
        end
    end

endmodule
