`include "ALU.v"

module stimulus ();
    reg  [31:0] A, B;
    reg  [3:0]  ALUControl;
    wire [31:0] ALUResult;
    wire        ZERO;

    ALU ALU_module (
        .in1(A), .in2(B),
        .alu_control(ALUControl),
        .alu_result(ALUResult),
        .zero_flag(ZERO)
    );

    initial begin
        $dumpfile("alu_output_wave.vcd");
        $dumpvars(0, stimulus);
    end

    initial
        $monitor($time, "\nA=%0d B=%0d ctrl=%b → result=%0d zero=%b\n",
                 A, B, ALUControl, ALUResult, ZERO);

    initial begin
                A = 15;  B = 9;   ALUControl = 4'b0010; // ADD  → 24
        #20     A = 15;  B = 9;   ALUControl = 4'b0100; // SUB  → 6
        #20     A = 15;  B = 9;   ALUControl = 4'b0000; // AND  → 9
        #20     A = 15;  B = 9;   ALUControl = 4'b0001; // OR   → 15
        #20     A = 15;  B = 9;   ALUControl = 4'b0111; // XOR  → 6
        #20     A = 1;   B = 3;   ALUControl = 4'b0011; // SLL  → 8
        #20     A = 16;  B = 2;   ALUControl = 4'b0101; // SRL  → 4
        #20     A = -8;  B = 2;   ALUControl = 4'b0110; // SRA  → -2
        #20     A = 5;   B = 10;  ALUControl = 4'b1000; // SLT  → 1
        #20     A = 10;  B = 5;   ALUControl = 4'b1000; // SLT  → 0
        #20     A = 5;   B = 5;   ALUControl = 4'b0100; // SUB  → 0 (zero flag)
    end

    initial #250 $finish;
endmodule
