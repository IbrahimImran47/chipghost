// trigger.v -- ChipGhost trigger engine (module 2)
//
// Decides when the sampler should start capturing. Watches the probe inputs
// and emits a single-cycle `trigger` pulse when the configured condition is
// met while armed. Feeds the sampler's `trigger` input.
//
// Modes (trig_mode):
//   0 PATTERN  -- (probe & pattern_mask) == (pattern_value & pattern_mask)
//   1 RISING   -- 0->1 transition on probe[edge_channel]
//   2 FALLING  -- 1->0 transition on probe[edge_channel]
//   3 ANY EDGE -- any transition on probe[edge_channel]
//
// Fires once per arm cycle: after the pulse it latches until `arm` is
// deasserted and reasserted (re-arm). This matches the sampler, which only
// needs one trigger to leave its ARMED state.

module trigger #(
    parameter NUM_CHANNELS = 8
) (
    input  wire                            clk,
    input  wire                            rst_n,
    input  wire [NUM_CHANNELS-1:0]         probe_in,
    input  wire                            arm,

    // Configuration
    input  wire [1:0]                      trig_mode,
    input  wire [NUM_CHANNELS-1:0]         pattern_mask,   // 1 = compare this channel
    input  wire [NUM_CHANNELS-1:0]         pattern_value,  // expected value on masked channels
    input  wire [$clog2(NUM_CHANNELS)-1:0] edge_channel,   // channel selected for edge modes

    output reg                             trigger         // one-cycle pulse
);

    localparam MODE_PATTERN = 2'd0;
    localparam MODE_RISING  = 2'd1;
    localparam MODE_FALLING = 2'd2;
    localparam MODE_ANYEDGE = 2'd3;

    // Double-flop synchronizer on external inputs (same convention as sampler.v).
    // Note: this 2-cycle delay matches the sampler's own input pipeline, so the
    // sample captured at the trigger instant lines up with what was matched.
    reg [NUM_CHANNELS-1:0] sync1, sync2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync1 <= 0;
            sync2 <= 0;
        end else begin
            sync1 <= probe_in;
            sync2 <= sync1;
        end
    end

    // Previous synchronized sample, for edge detection.
    reg [NUM_CHANNELS-1:0] prev;

    wire pattern_match = ((sync2 & pattern_mask) == (pattern_value & pattern_mask));
    wire ch_now        = sync2[edge_channel];
    wire ch_prev       = prev[edge_channel];
    wire rising        =  ch_now & ~ch_prev;
    wire falling       = ~ch_now &  ch_prev;
    wire any_edge      =  ch_now ^  ch_prev;

    reg cond;
    always @(*) begin
        case (trig_mode)
            MODE_PATTERN: cond = pattern_match;
            MODE_RISING:  cond = rising;
            MODE_FALLING: cond = falling;
            MODE_ANYEDGE: cond = any_edge;
            default:      cond = 1'b0;
        endcase
    end

    reg fired;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prev    <= 0;
            trigger <= 1'b0;
            fired   <= 1'b0;
        end else begin
            prev    <= sync2;
            trigger <= 1'b0;          // default: one-cycle pulse
            if (!arm) begin
                fired <= 1'b0;        // re-arm when arm deasserts
            end else if (!fired && cond) begin
                trigger <= 1'b1;
                fired   <= 1'b1;
            end
        end
    end

endmodule
