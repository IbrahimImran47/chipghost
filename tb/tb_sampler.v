`timescale 1ns / 1ps

module tb_sampler;

    parameter NUM_CHANNELS = 8;
    parameter SAMPLE_DEPTH = 64;

    reg                    clk;
    reg                    rst_n;
    reg [NUM_CHANNELS-1:0] probe_in;
    reg                    armed;
    reg                    trigger;
    wire                   capture_done;
    wire [NUM_CHANNELS-1:0] read_data;
    reg [$clog2(SAMPLE_DEPTH)-1:0] read_addr;
    reg                    read_en;

    sampler #(
        .NUM_CHANNELS(NUM_CHANNELS),
        .SAMPLE_DEPTH(SAMPLE_DEPTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .probe_in(probe_in),
        .armed(armed),
        .trigger(trigger),
        .capture_done(capture_done),
        .read_data(read_data),
        .read_addr(read_addr),
        .read_en(read_en)
    );

    always #5 clk = ~clk; // 100 MHz

    integer i;
    integer errors;

    initial begin
        $dumpfile("tb_sampler.vcd");
        $dumpvars(0, tb_sampler);

        clk      = 0;
        rst_n    = 0;
        probe_in = 0;
        armed    = 0;
        trigger  = 0;
        read_addr = 0;
        read_en  = 0;
        errors   = 0;

        // Reset
        #20 rst_n = 1;
        #10;

        // Arm the sampler
        armed = 1;
        #10;

        // Feed known pattern on probes
        probe_in = 8'hA5;
        #10;

        // Fire trigger
        trigger = 1;
        #10;
        trigger = 0;

        // Generate a counting pattern while capturing
        for (i = 0; i < SAMPLE_DEPTH + 10; i = i + 1) begin
            probe_in = i[7:0];
            #10;
        end

        // Wait for capture to complete
        #50;

        if (!capture_done) begin
            $display("FAIL: capture_done not asserted");
            errors = errors + 1;
        end

        // Read back samples and verify
        armed   = 0;
        read_en = 1;
        #10;

        for (i = 0; i < SAMPLE_DEPTH; i = i + 1) begin
            read_addr = i;
            #10;
            if (i < 5) begin
                $display("Sample[%0d] = 0x%02h", i, read_data);
            end
        end

        read_en = 0;

        if (errors == 0)
            $display("PASS: All sampler tests passed");
        else
            $display("FAIL: %0d errors", errors);

        #20 $finish;
    end

endmodule
