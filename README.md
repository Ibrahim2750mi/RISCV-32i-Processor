## RISC-V 32-bit Processor — Logisim Evolution

A fully functional **RV32I base integer ISA** processor implemented in Logisim Evolution, supporting the complete single-cycle datapath with a two-phase fetch/execute FSM.

---

### Supported Instructions
- **R-type:** ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU
- **I-type:** ADDI, ANDI, ORI, XORI, SLLI, SRLI, SRAI, SLTI, SLTIU
- **Load:** LW, LH, LB, LHU, LBU
- **Store:** SW, SH, SB
- **Branch:** BEQ, BNE, BLT, BGE, BLTU, BGEU
- **Jump:** JAL, JALR
- **Upper Immediate:** LUI, AUIPC

---

### Architecture
- 32-bit datapath
- Two-phase FSM (FETCH / EXECUTE) on a shared memory bus
- ROM-based Control Unit (11-bit address, 16-bit output)
- 32 × 32-bit Register File (x0 hardwired to 0)
- Byte-addressable RAM (instructions + data unified)
- Separate submodules: ALU, IMM\_GEN, BRANCH\_UNIT, STORE\_UNIT, LOAD\_EXTRACTOR

---

### Tools
- Logisim Evolution 4.x
- Verilog reference implementation (for verification)
