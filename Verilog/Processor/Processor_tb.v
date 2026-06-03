`timescale 1ns/1ps
`include "25125027_riscv.v"

// ============================================================
// Full RV32I testbench
// Every instruction from the spec table is tested.
// "NOTE" cases (msb-extends, zero-extends) are called out
// separately with a NOTE tag in the label.
// 2 clock cycles per instruction (FETCH + EXECUTE).
// ============================================================

module stimulus ();

    reg         clk, reset;
    wire [31:0] mem_addr, mem_wdata;
    wire [3:0]  mem_wmask;
    wire        mem_rstrb;
    reg  [31:0] mem_rdata;
    reg         mem_rbusy, mem_wbusy;

    reg [7:0] sim_mem [0:4095];
    integer   i;

    riscv_processor DUT (
        .clk(clk),         .reset(reset),
        .mem_addr(mem_addr), .mem_wdata(mem_wdata),
        .mem_wmask(mem_wmask), .mem_rdata(mem_rdata),
        .mem_rstrb(mem_rstrb), .mem_rbusy(mem_rbusy),
        .mem_wbusy(mem_wbusy)
    );

    always @(*) begin
        if (mem_addr < 4096)
            mem_rdata = {sim_mem[mem_addr+3], sim_mem[mem_addr+2],
                         sim_mem[mem_addr+1], sim_mem[mem_addr]};
        else mem_rdata = 32'hdeadbeef;
    end

    always @(posedge clk) begin
        if (mem_wmask[0]) sim_mem[mem_addr  ] <= mem_wdata[7:0];
        if (mem_wmask[1]) sim_mem[mem_addr+1] <= mem_wdata[15:8];
        if (mem_wmask[2]) sim_mem[mem_addr+2] <= mem_wdata[23:16];
        if (mem_wmask[3]) sim_mem[mem_addr+3] <= mem_wdata[31:24];
    end

    task load_word;
        input [31:0] addr, word;
        begin
            sim_mem[addr  ] = word[7:0];  sim_mem[addr+1] = word[15:8];
            sim_mem[addr+2] = word[23:16]; sim_mem[addr+3] = word[31:24];
        end
    endtask

    integer pass_count, fail_count;

    task check;
        input [4:0]   rn;
        input [31:0]  exp;
        input [255:0] label;
        reg   [31:0]  got;
        begin
            got = DUT.reg_file.reg_memory[rn];
            if (got === exp) begin
                $display("  PASS  %-30s  x%0d = 0x%08x", label, rn, got);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL  %-30s  x%0d  got=0x%08x  exp=0x%08x",
                         label, rn, got, exp);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task check_mem;
        input [31:0]  addr, exp;
        input [255:0] label;
        reg   [31:0]  got;
        begin
            got = {sim_mem[addr+3],sim_mem[addr+2],sim_mem[addr+1],sim_mem[addr]};
            if (got === exp) begin
                $display("  PASS  %-30s  mem[%0d]=0x%08x", label, addr, got);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL  %-30s  mem[%0d] got=0x%08x  exp=0x%08x",
                         label, addr, got, exp);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task run;
        input integer n;
        integer c;
        begin for (c=0; c<n; c=c+1) @(posedge clk); #1; end
    endtask

    task hard_reset;
        begin
            reset = 1;
            for (i=0; i<4096; i=i+1) sim_mem[i] = 8'h00;
            run(6); reset = 0; #1;
        end
    endtask

    initial begin clk=0; forever #10 clk=~clk; end
    initial begin
        $dumpfile("processor_output_wave.vcd");
        $dumpvars(0, stimulus);
    end

    initial begin
        mem_rbusy=0; mem_wbusy=0; pass_count=0; fail_count=0;
        reset=1; run(2);

        // ============================================================
        // 1. R-TYPE: ADD SUB XOR OR AND SLL SRL SLT SLTU
        // ============================================================
        $display("\n=== R-TYPE: ADD SUB XOR OR AND SLL SRL SLT SLTU ===");
        hard_reset;
        // x1=15(0xF)  x2=3 for ADD/SUB/XOR/OR/AND/SLT/SLTU
        load_word(0,  32'h00f00093); // addi x1,x0,15
        load_word(4,  32'h00300113); // addi x2,x0,3
        load_word(8,  32'h002081b3); // add  x3,x1,x2   x3=18
        load_word(12, 32'h40208233); // sub  x4,x1,x2   x4=12
        load_word(16, 32'h0020c2b3); // xor  x5,x1,x2   -> 0xF^0x3=12
        load_word(20, 32'h0020e333); // or   x6,x1,x2   -> 0xF|0x3=15
        load_word(24, 32'h0020f3b3); // and  x7,x1,x2   -> 0xF&0x3=3
        load_word(28, 32'h0020a433); // slt  x8,x1,x2   -> 0 (15 not < 3)
        load_word(32, 32'h001124b3); // slt  x9,x2,x1   -> 1 (3 < 15)
        load_word(36, 32'h0020b533); // sltu x10,x1,x2  -> 0
        load_word(40, 32'h001135b3); // sltu x11,x2,x1  -> 1
        // shift: x1=1, x2=3
        load_word(44, 32'h00100093); // addi x1,x0,1
        load_word(48, 32'h00300113); // addi x2,x0,3
        load_word(52, 32'h00209633); // sll  x12,x1,x2  -> 1<<3=8
        // shift: x1=16, x2=2
        load_word(56, 32'h01000093); // addi x1,x0,16
        load_word(60, 32'h00200113); // addi x2,x0,2
        load_word(64, 32'h0020d6b3); // srl  x13,x1,x2  -> 16>>2=4
        load_word(68, 32'h0000006f); // halt
        run(48);
        check(3,  32'd18, "add  15+3");
        check(4,  32'd12, "sub  15-3");
        check(5,  32'd12, "xor  0xF^0x3");
        check(6,  32'd15, "or   0xF|0x3");
        check(7,  32'd3,  "and  0xF&0x3");
        check(8,  32'd0,  "slt  15<3=0");
        check(9,  32'd1,  "slt  3<15=1");
        check(10, 32'd0,  "sltu 15<3=0");
        check(11, 32'd1,  "sltu 3<15=1");
        check(12, 32'd8,  "sll  1<<3");
        check(13, 32'd4,  "srl  16>>2");

        // ============================================================
        // 2. SRA - NOTE: msb-extends (arithmetic, fills with sign bit)
        //    Compare with SRL (zero-fills, no note)
        // ============================================================
        $display("\n=== SRA (NOTE: msb-extends) vs SRL (zero-extends) ===");
        hard_reset;
        // x1=-8 (0xFFFFFFF8), x2=2
        load_word(0,  32'hff800093); // addi x1,x0,-8
        load_word(4,  32'h00200113); // addi x2,x0,2
        load_word(8,  32'h0020d1b3); // srl  x3,x1,x2  -> 0x3FFFFFFE (zero-fill)
        load_word(12, 32'h4020d233); // sra  x4,x1,x2  -> 0xFFFFFFFE=-2 (msb-fill NOTE)
        load_word(16, 32'h0000006f); // halt
        run(14);
        check(3, 32'h3ffffffe, "srl -8>>2 zero-fill (no note)");
        check(4, 32'hfffffffe, "sra -8>>2 msb-fill  (NOTE)");

        // ============================================================
        // 3. SLTU - NOTE: zero-extends (treats operands as unsigned)
        //    x1=1, x2=-1(0xFFFFFFFF)
        //    slt:  signed   1 < -1 = 0 (no note)
        //    sltu: unsigned 1 < 0xFFFFFFFF = 1 (NOTE)
        // ============================================================
        $display("\n=== SLTU (NOTE: zero-extends unsigned compare) ===");
        hard_reset;
        load_word(0,  32'h00100093); // addi x1,x0,1
        load_word(4,  32'hfff00113); // addi x2,x0,-1   (0xFFFFFFFF)
        load_word(8,  32'h0020a1b3); // slt  x3,x1,x2   -> 0 (signed: 1 < -1 = false)
        load_word(12, 32'h0020b233); // sltu x4,x1,x2   -> 1 (unsigned: 1 < 0xFFFF...=true)
        load_word(16, 32'h0000006f); // halt
        run(14);
        check(3, 32'd0, "slt  1<-1 signed=0  (no note)");
        check(4, 32'd1, "sltu 1<0xFFFFFFFF=1 (NOTE)");

        // ============================================================
        // 4. I-TYPE ALU: ADDI XORI ORI ANDI SLLI SRLI SLTI SLTIU
        // ============================================================
        $display("\n=== I-TYPE ALU: ADDI XORI ORI ANDI SLLI SRLI SLTI SLTIU ===");
        hard_reset;
        load_word(0,  32'h06400093); // addi  x1,x0,100
        load_word(4,  32'h0ff0c113); // xori  x2,x1,255   -> 155
        load_word(8,  32'h00f0e193); // ori   x3,x1,15    -> 111
        load_word(12, 32'h00f0f213); // andi  x4,x1,15    -> 4
        load_word(16, 32'h00209293); // slli  x5,x1,2     -> 400
        load_word(20, 32'h0020d313); // srli  x6,x1,2     -> 25
        load_word(24, 32'h0c80a393); // slti  x7,x1,200   -> 1 (100<200)
        load_word(28, 32'h0320a413); // slti  x8,x1,50    -> 0 (100 not<50)
        load_word(32, 32'h0c80b493); // sltiu x9,x1,200   -> 1 (unsigned 100<200)
        load_word(36, 32'h0000006f); // halt
        run(26);
        check(2, 32'd155, "xori 100^255");
        check(3, 32'd111, "ori  100|15");
        check(4, 32'd4,   "andi 100&15");
        check(5, 32'd400, "slli 100<<2");
        check(6, 32'd25,  "srli 100>>2");
        check(7, 32'd1,   "slti  100<200=1");
        check(8, 32'd0,   "slti  100<50=0");
        check(9, 32'd1,   "sltiu 100<200=1");

        // ============================================================
        // 5. SRAI - NOTE: msb-extends (arithmetic shift right immediate)
        // ============================================================
        $display("\n=== SRAI (NOTE: msb-extends) vs SRLI (zero-extends) ===");
        hard_reset;
        load_word(0,  32'hf9c00093); // addi x1,x0,-100
        load_word(4,  32'h0020d113); // srli x2,x1,2   -> zero-fill (no note)
        load_word(8,  32'h4020d193); // srai x3,x1,2   -> msb-fill  (NOTE)
        load_word(12, 32'h0000006f); // halt
        run(12);
        check(2, 32'h3fffffe7, "srli -100>>2 zero-fill (no note)");
        check(3, 32'hffffffe7, "srai -100>>2 msb-fill  (NOTE)");

        // ============================================================
        // 6. SLTIU - NOTE: zero-extends (imm treated as unsigned after sign-ext)
        //    imm=-1 sign-extends to 0xFFFFFFFF (largest unsigned)
        //    slti  x,1,-1 -> signed:   1 < -1 = 0
        //    sltiu x,1,-1 -> unsigned: 1 < 0xFFFFFFFF = 1 (NOTE)
        // ============================================================
        $display("\n=== SLTIU (NOTE: zero-extends) ===");
        hard_reset;
        load_word(0,  32'h00100093); // addi x1,x0,1
        load_word(4,  32'hfff0a113); // slti  x2,x1,-1   -> 0 (signed 1 < -1 = false)
        load_word(8,  32'hfff0b193); // sltiu x3,x1,-1   -> 1 (unsigned: 1 < 0xFFFF...)
        load_word(12, 32'h0000006f); // halt
        run(12);
        check(2, 32'd0, "slti  1<-1 signed=0  (no note)");
        check(3, 32'd1, "sltiu 1<0xFFFFFFFF=1 (NOTE)");

        // ============================================================
        // 7. LOADS: LW LH LB LHU LBU
        //    mem[128] = 0xDEADBEEF
        //    LH/LB: sign-extend (no note base behavior is sign)
        //    LHU/LBU: zero-extend (NOTE)
        // ============================================================
        $display("\n=== LOADS: LW LH LB LHU(NOTE) LBU(NOTE) ===");
        hard_reset;
        sim_mem[128]=8'hEF; sim_mem[129]=8'hBE;
        sim_mem[130]=8'hAD; sim_mem[131]=8'hDE;
        load_word(0,  32'h08000093); // addi x1,x0,128
        load_word(4,  32'h0000a103); // lw   x2,0(x1)  -> 0xDEADBEEF
        load_word(8,  32'h00009183); // lh   x3,0(x1)  -> sign_ext(0xBEEF)=0xFFFFBEEF
        load_word(12, 32'h00008203); // lb   x4,0(x1)  -> sign_ext(0xEF)=0xFFFFFFEF
        load_word(16, 32'h0000d283); // lhu  x5,0(x1)  -> 0x0000BEEF (NOTE: zero-extends)
        load_word(20, 32'h0000c303); // lbu  x6,0(x1)  -> 0x000000EF (NOTE: zero-extends)
        load_word(24, 32'h0000006f); // halt
        run(20);
        check(2, 32'hdeadbeef, "lw  full word");
        check(3, 32'hffffbeef, "lh  sign-extend");
        check(4, 32'hffffffef, "lb  sign-extend");
        check(5, 32'h0000beef, "lhu zero-extend (NOTE)");
        check(6, 32'h000000ef, "lbu zero-extend (NOTE)");

        // ============================================================
        // 8. STORES: SW SH SB
        //    Store then read back with LW to verify byte masking
        // ============================================================
        $display("\n=== STORES: SW SH SB ===");

        // SW
        hard_reset;
        load_word(0,  32'h123450b7); // lui  x1,0x12345
        load_word(4,  32'h67808093); // addi x1,x1,0x678  -> 0x12345678
        load_word(8,  32'h04102023); // sw   x1,64(x0)
        load_word(12, 32'h04002103); // lw   x2,64(x0)    -> readback
        load_word(16, 32'h0000006f); // halt
        run(16);
        check(2, 32'h12345678, "sw full word readback");

        // SH
        hard_reset;
        load_word(0,  32'h123450b7); // lui  x1,0x12345
        load_word(4,  32'h67808093); // addi x1,x1,0x678  -> 0x12345678
        load_word(8,  32'h04101023); // sh   x1,64(x0)    -> only low 16 bits
        load_word(12, 32'h04002103); // lw   x2,64(x0)
        load_word(16, 32'h0000006f); // halt
        run(16);
        check(2, 32'h00005678, "sh half-word readback");

        // SB
        hard_reset;
        load_word(0,  32'h123450b7); // lui  x1,0x12345
        load_word(4,  32'h67808093); // addi x1,x1,0x678  -> 0x12345678
        load_word(8,  32'h04100023); // sb   x1,64(x0)    -> only low byte
        load_word(12, 32'h04002103); // lw   x2,64(x0)
        load_word(16, 32'h0000006f); // halt
        run(16);
        check(2, 32'h00000078, "sb byte readback");

        // ============================================================
        // 9. BRANCHES: BEQ BNE BLT BGE BLTU(NOTE) BGEU(NOTE)
        //    Each: taken case skips a poison addi, lands on marker addi
        //          not-taken case falls through to poison
        // ============================================================
        $display("\n=== BRANCHES ===");

        // BEQ taken
        $display("  -- BEQ --");
        hard_reset;
        load_word(0,  32'h00500093); // addi x1,x0,5
        load_word(4,  32'h00500113); // addi x2,x0,5
        load_word(8,  32'h00208463); // beq  x1,x2,+8   taken
        load_word(12, 32'h06300213); // POISON  x4=99
        load_word(16, 32'h00100293); // MARKER  x5=1
        load_word(20, 32'h0000006f); // halt
        run(16);
        check(4, 32'd0,  "beq  taken: poison skipped");
        check(5, 32'd1,  "beq  taken: marker written");

        // BEQ not-taken
        hard_reset;
        load_word(0,  32'h00500093);
        load_word(4,  32'h00600113); // x2=6 (!=x1)
        load_word(8,  32'h00208463); // beq  x1,x2,+8   NOT taken
        load_word(12, 32'h06300213); // executes x4=99
        load_word(16, 32'h0000006f);
        run(14);
        check(4, 32'd99, "beq  not-taken: fallthrough");

        // BNE
        $display("  -- BNE --");
        hard_reset;
        load_word(0,  32'h00500093);
        load_word(4,  32'h00600113); // x1=5 x2=6
        load_word(8,  32'h00209463); // bne  x1,x2,+8   taken (5!=6)
        load_word(12, 32'h06300213); // POISON
        load_word(16, 32'h00100293); // MARKER
        load_word(20, 32'h0000006f);
        run(16);
        check(4, 32'd0, "bne  taken: poison skipped");
        check(5, 32'd1, "bne  taken: marker written");

        // BLT signed
        $display("  -- BLT --");
        hard_reset;
        load_word(0,  32'h00500093);
        load_word(4,  32'h00a00113); // x1=5 x2=10
        load_word(8,  32'h0020c463); // blt  x1,x2,+8   taken (5<10 signed)
        load_word(12, 32'h06300213); // POISON
        load_word(16, 32'h00100293); // MARKER
        load_word(20, 32'h0000006f);
        run(16);
        check(4, 32'd0, "blt  taken: poison skipped");
        check(5, 32'd1, "blt  taken: marker written");

        // BGE signed
        $display("  -- BGE --");
        hard_reset;
        load_word(0,  32'h00a00093); // x1=10
        load_word(4,  32'h00500113); // x2=5
        load_word(8,  32'h0020d463); // bge  x1,x2,+8   taken (10>=5)
        load_word(12, 32'h06300213); // POISON
        load_word(16, 32'h00100293); // MARKER
        load_word(20, 32'h0000006f);
        run(16);
        check(4, 32'd0, "bge  taken: poison skipped");
        check(5, 32'd1, "bge  taken: marker written");

        // BLTU - NOTE: zero-extends (unsigned compare)
        $display("  -- BLTU (NOTE: zero-extends) --");
        // NOT taken: 0xFFFFFFFF is NOT < 1 in unsigned
        hard_reset;
        load_word(0,  32'hfff00093); // x1=0xFFFFFFFF
        load_word(4,  32'h00100113); // x2=1
        load_word(8,  32'h0020e463); // bltu x1,x2,+8   NOT taken
        load_word(12, 32'h06300213); // executes x4=99
        load_word(16, 32'h0000006f);
        run(14);
        check(4, 32'd99, "bltu not-taken: 0xFFFF!<1 unsigned (NOTE)");
        // taken: 1 < 0xFFFFFFFF unsigned
        hard_reset;
        load_word(0,  32'h00100093); // x1=1
        load_word(4,  32'hfff00113); // x2=0xFFFFFFFF
        load_word(8,  32'h0020e463); // bltu x1,x2,+8   taken
        load_word(12, 32'h06300213); // POISON
        load_word(16, 32'h00100293); // MARKER
        load_word(20, 32'h0000006f);
        run(16);
        check(4, 32'd0, "bltu taken: 1<0xFFFF unsigned (NOTE)");
        check(5, 32'd1, "bltu taken: marker (NOTE)");

        // BGEU - NOTE: zero-extends
        $display("  -- BGEU (NOTE: zero-extends) --");
        hard_reset;
        load_word(0,  32'hfff00093); // x1=0xFFFFFFFF
        load_word(4,  32'h00100113); // x2=1
        load_word(8,  32'h0020f463); // bgeu x1,x2,+8   taken (0xFFFF>=1 unsigned)
        load_word(12, 32'h06300213); // POISON
        load_word(16, 32'h00100293); // MARKER
        load_word(20, 32'h0000006f);
        run(16);
        check(4, 32'd0, "bgeu taken: 0xFFFF>=1 unsigned (NOTE)");
        check(5, 32'd1, "bgeu taken: marker (NOTE)");

        // ============================================================
        // 10. JAL: rd = PC+4, PC += imm
        // ============================================================
        $display("\n=== JAL ===");
        hard_reset;
        // addr 0: jal x1,+8  -> x1=4, jump to 8
        // addr 4: POISON x2=99
        // addr 8: MARKER x3=1
        // addr 12: halt
        load_word(0,  32'h008000ef); // jal x1,+8
        load_word(4,  32'h06300113); // POISON x2=99
        load_word(8,  32'h00100193); // MARKER x3=1
        load_word(12, 32'h0000006f); // halt
        run(12);
        check(1, 32'd4, "jal rd=PC+4");
        check(2, 32'd0, "jal skip poison");
        check(3, 32'd1, "jal target marker");

        // ============================================================
        // 11. JALR: rd = PC+4, PC = (rs1+imm)&~1
        // ============================================================
        $display("\n=== JALR ===");
        hard_reset;
        // addr  0: addi x2,x0,16
        // addr  4: jalr x1,x2,-4  -> x1=8, PC=(16-4)=12
        // addr  8: POISON x3=99
        // addr 12: MARKER x4=1
        // addr 16: halt
        load_word(0,  32'h01000113); // addi x2,x0,16
        load_word(4,  32'hffc100e7); // jalr x1,x2,-4
        load_word(8,  32'h06300193); // POISON x3=99
        load_word(12, 32'h00100213); // MARKER x4=1
        load_word(16, 32'h0000006f); // halt
        run(14);
        check(1, 32'd8,  "jalr rd=PC+4");
        check(3, 32'd0,  "jalr skip poison");
        check(4, 32'd1,  "jalr target marker");

        // ============================================================
        // 12. LUI: rd = imm << 12
        // ============================================================
        $display("\n=== LUI ===");
        hard_reset;
        load_word(0,  32'habcde0b7); // lui x1,0xABCDE  -> 0xABCDE000
        load_word(4,  32'h00000137); // lui x2,0        -> 0
        load_word(8,  32'hfffff1b7); // lui x3,0xFFFFF  -> 0xFFFFF000
        load_word(12, 32'h0000006f); // halt
        run(12);
        check(1, 32'habcde000, "lui 0xABCDE");
        check(2, 32'h00000000, "lui 0");
        check(3, 32'hfffff000, "lui 0xFFFFF");

        // ============================================================
        // 13. AUIPC: rd = PC + (imm<<12)
        // ============================================================
        $display("\n=== AUIPC ===");
        hard_reset;
        // addr 0: auipc x1,0         -> x1 = 0+0 = 0
        // addr 4: auipc x2,1         -> x2 = 4+0x1000 = 0x1004
        // addr 8: auipc x3,0xABCDE   -> x3 = 8+0xABCDE000 = 0xABCDE008
        // addr 12: halt
        load_word(0,  32'h00000097); // auipc x1,0
        load_word(4,  32'h00001117); // auipc x2,1
        load_word(8,  32'habcde197); // auipc x3,0xABCDE
        load_word(12, 32'h0000006f); // halt
        run(12);
        check(1, 32'h00000000, "auipc PC=0,imm=0");
        check(2, 32'h00001004, "auipc PC=4,imm=1");
        check(3, 32'habcde008, "auipc PC=8,imm=0xABCDE");

        // ============================================================
        // FINAL SCORE
        // ============================================================
        $display("\n============================================");
        $display("  TOTAL:  %0d PASSED   %0d FAILED", pass_count, fail_count);
        if (fail_count == 0)
            $display("  ALL RV32I TESTS PASSED");
        else
            $display("  SOME TESTS FAILED - check output above");
        $display("============================================\n");
        $finish;
    end

endmodule
