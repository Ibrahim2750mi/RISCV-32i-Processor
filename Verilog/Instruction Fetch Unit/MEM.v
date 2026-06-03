/*
Instruction & Data Memory Interface.
Unified memory: instruction fetches and data load/store share one address bus
matching the required processor interface:
  mem_addr   – address driven by the processor
  mem_wdata  – data to write
  mem_wmask  – byte-enable write mask [3:0]
  mem_rdata  – data returned to the processor (instructions & loads)
  mem_rstrb  – processor asserts 1 to initiate a read
  mem_rbusy  – memory asserts 1 when read is not yet ready
  mem_wbusy  – memory asserts 1 when write is not yet ready
*/

module MEM (
    input         clock,
    input         reset,
    input  [31:0] mem_addr,
    input  [31:0] mem_wdata,
    input  [3:0]  mem_wmask,
    output [31:0] mem_rdata,
    input         mem_rstrb,
    output        mem_rbusy,
    output        mem_wbusy
);

    reg [7:0] memory [0:4095];

    integer i;
    initial begin
        for (i = 0; i < 4096; i = i + 1) memory[i] = 8'h00;
        $readmemh("program.hex", memory);
    end

    // Single-cycle memory: never busy
    assign mem_rbusy = 1'b0;
    assign mem_wbusy = 1'b0;

    // Combinational read
    assign mem_rdata = {memory[mem_addr+3], memory[mem_addr+2],
                        memory[mem_addr+1], memory[mem_addr]};

    // Synchronous byte-masked write
    always @(posedge clock) begin
        if (!reset) begin
            if (mem_wmask[0]) memory[mem_addr]   <= mem_wdata[7:0];
            if (mem_wmask[1]) memory[mem_addr+1] <= mem_wdata[15:8];
            if (mem_wmask[2]) memory[mem_addr+2] <= mem_wdata[23:16];
            if (mem_wmask[3]) memory[mem_addr+3] <= mem_wdata[31:24];
        end
    end

endmodule
