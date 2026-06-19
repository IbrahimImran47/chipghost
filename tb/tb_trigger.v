`timescale 1ns / 1ps

module tb_trigger;

    parameter NUM_CHANNELS = 8;

    reg                         clk;
    reg                         rst_n;
    reg [NUM_CHANNELS-1:0]      probe_in;
    reg                         arm;
    reg [1:0]                   trig_mode;
    reg [NUM_CHANNELS-1:0]      pattern_mask;
    reg [NUM_CHANNELS-1:0]      pattern_value;
    reg [$clog2(NUM_CHANNELS)-1:0] edge_channel;
    wire                        trigger;

    localparam MODE_PATTERN = 2'd0;
    localparam MODE_RISING  = 2'd1;
    localparam MODE_FALLING = 2'd2;
    localparam MODE_ANYEDGE = 2'd3;

    trigger #(
        .NUM_CHANNELS(NUM_CHANNELS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .probe_in(probe_in),
        .arm(arm),
        .trig_mode(trig_mode),
        .pattern_mask(pattern_mask),
        .pattern_value(pattern_value),
        .edge_channel(edge_channel),
        .trigger(trigger)
    );

    always #5 clk = ~clk; // 100 MHz

    integer errors;
    integer trig_count;
    integer base;

    // Count trigger pulses as they happen.
    always @(posedge clk)
        if (trigger)
            trig_count = trig_count + 1;

    task check;
        input        cond;
        input [255:0] msg;
        begin
            if (!cond) begin
                $display("FAIL: %0s", msg);
                errors = errors + 1;
            end else begin
                $display("PASS: %0s", msg);
            end
        end
    endtask

    // Deassert arm long enough to clear the one-shot latch, then re-arm.
    task rearm;
        begin
            arm = 0; #30;
            arm = 1; #10;
        end
    endtask

    initial begin
        $dumpfile("tb_trigger.vcd");
        $dumpvars(0, tb_trigger);

        clk           = 0;
        rst_n         = 0;
        probe_in      = 0;
        arm           = 0;
        trig_mode     = MODE_PATTERN;
        pattern_mask  = 0;
        pattern_value = 0;
        edge_channel  = 0;
        errors        = 0;
        trig_count    = 0;

        #20 rst_n = 1;
        #10;

        // --- Test 1: full pattern match (0xA5) fires exactly once ---
        trig_mode     = MODE_PATTERN;
        pattern_mask  = 8'hFF;
        pattern_value = 8'hA5;
        probe_in      = 8'h00;
        arm           = 1;
        #30;
        base = trig_count;
        probe_in = 8'hA5;
        #40;
        check(trig_count - base == 1, "pattern 0xA5 fires once");

        // --- Test 2: no re-fire on same arm cycle ---
        base = trig_count;
        probe_in = 8'h00; #20;
        probe_in = 8'hA5; #40;
        check(trig_count - base == 0, "no refire until rearm");

        // --- Test 3: re-arm fires again (probe still matches) ---
        base = trig_count;
        rearm();         // arm low->high; probe is still 0xA5
        #30;
        check(trig_count - base == 1, "fires again after rearm");

        // --- Test 4: masked pattern ignores upper nibble ---
        probe_in      = 8'h00;
        rearm();
        trig_mode     = MODE_PATTERN;
        pattern_mask  = 8'h0F;   // only low nibble matters
        pattern_value = 8'h05;
        base = trig_count;
        probe_in = 8'hF6;        // low nibble 6 -> no match
        #40;
        check(trig_count - base == 0, "masked pattern: 0xF6 no match");
        base = trig_count;
        probe_in = 8'hF5;        // low nibble 5 -> match despite upper nibble
        #40;
        check(trig_count - base == 1, "masked pattern: 0xF5 matches");

        // --- Test 5: rising edge on channel 0 ---
        probe_in = 8'h00;
        rearm();
        trig_mode    = MODE_RISING;
        edge_channel = 0;
        base = trig_count;
        probe_in = 8'h00; #20;
        probe_in = 8'h01;        // 0 -> 1 on ch0
        #40;
        check(trig_count - base == 1, "rising edge ch0 fires");

        // --- Test 6: falling edge on channel 0 ---
        probe_in = 8'h01;
        rearm();
        trig_mode    = MODE_FALLING;
        edge_channel = 0;
        base = trig_count;
        probe_in = 8'h01; #20;
        probe_in = 8'h00;        // 1 -> 0 on ch0
        #40;
        check(trig_count - base == 1, "falling edge ch0 fires");

        // --- Test 7: falling-edge mode ignores a rising edge ---
        probe_in = 8'h00;
        rearm();
        trig_mode    = MODE_FALLING;
        edge_channel = 0;
        base = trig_count;
        probe_in = 8'h00; #20;
        probe_in = 8'h01;        // rising while in FALLING mode
        #40;
        check(trig_count - base == 0, "falling mode ignores rising edge");

        // --- Test 8: any-edge fires on either transition ---
        probe_in = 8'h00;
        rearm();
        trig_mode    = MODE_ANYEDGE;
        edge_channel = 2;
        base = trig_count;
        probe_in = 8'h00; #20;
        probe_in = 8'h04;        // 0 -> 1 on ch2
        #40;
        check(trig_count - base == 1, "any-edge fires on rising");

        // --- Test 9: trigger never fires while disarmed ---
        arm = 0;
        trig_mode    = MODE_RISING;
        edge_channel = 0;
        base = trig_count;
        probe_in = 8'h00; #20;
        probe_in = 8'h01; #40;
        check(trig_count - base == 0, "no trigger while disarmed");

        if (errors == 0)
            $display("PASS: All trigger tests passed");
        else
            $display("FAIL: %0d errors", errors);

        #20 $finish;
    end

endmodule
