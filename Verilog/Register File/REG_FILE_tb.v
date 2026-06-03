`include "REG_FILE.v"

module stimulus ();
    reg  [4:0]  read_reg_num1, read_reg_num2, write_reg;
    reg  [31:0] write_data;
    wire [31:0] read_data1, read_data2;
    reg         regwrite, clock, reset;

    REG_FILE REG_FILE_module (
        read_reg_num1, read_reg_num2,
        write_reg, write_data,
        read_data1, read_data2,
        regwrite, clock, reset
    );

    initial begin
        $dumpfile("regfile_output_wave.vcd");
        $dumpvars(0, stimulus);
    end

    initial $monitor($time, " rd1[%0d]=%0d  rd2[%0d]=%0d",
                     read_reg_num1, read_data1, read_reg_num2, read_data2);

    initial begin reset = 1; #10 reset = 0; end

    initial begin
        clock = 0;
        forever #10 clock = ~clock;
    end

    initial begin
        regwrite = 0;
        #15 regwrite = 1; write_reg = 5'd1;  write_data = 32'd100;
        #20 regwrite = 1; write_reg = 5'd2;  write_data = 32'd200;
        #20 regwrite = 1; write_reg = 5'd0;  write_data = 32'd999; // x0 stays 0
        #20 regwrite = 0;
    end

    initial begin
        read_reg_num1 = 5'd0; read_reg_num2 = 5'd0;
        #35 read_reg_num1 = 5'd1; read_reg_num2 = 5'd2;
        #40 read_reg_num1 = 5'd0; read_reg_num2 = 5'd1;
    end

    initial #200 $finish;
endmodule
