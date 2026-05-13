module sampler #(
    parameter NUM_CHANNELS = 8,
    parameter SAMPLE_DEPTH = 16384
) (
    input  wire                    clk,
    input  wire                    rst_n,
    input  wire [NUM_CHANNELS-1:0] probe_in,
    input  wire                    armed,
    input  wire                    trigger,

    output reg                     capture_done,
    output wire [NUM_CHANNELS-1:0] read_data,
    input  wire [$clog2(SAMPLE_DEPTH)-1:0] read_addr,
    input  wire                    read_en
);

    localparam ADDR_W = $clog2(SAMPLE_DEPTH);

    reg [NUM_CHANNELS-1:0] sample_mem [0:SAMPLE_DEPTH-1];

    reg [ADDR_W-1:0] write_ptr;
    reg              capturing;
    reg [ADDR_W-1:0] sample_count;

    reg [NUM_CHANNELS-1:0] probe_sync1, probe_sync2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            probe_sync1 <= 0;
            probe_sync2 <= 0;
        end else begin
            probe_sync1 <= probe_in;
            probe_sync2 <= probe_sync1;
        end
    end

    localparam S_IDLE     = 2'd0;
    localparam S_ARMED    = 2'd1;
    localparam S_CAPTURE  = 2'd2;
    localparam S_DONE     = 2'd3;

    reg [1:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= S_IDLE;
            write_ptr    <= 0;
            sample_count <= 0;
            capturing    <= 0;
            capture_done <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    capture_done <= 0;
                    write_ptr    <= 0;
                    sample_count <= 0;
                    if (armed)
                        state <= S_ARMED;
                end

                S_ARMED: begin
                    if (trigger) begin
                        state     <= S_CAPTURE;
                        capturing <= 1;
                    end
                end

                S_CAPTURE: begin
                    sample_mem[write_ptr] <= probe_sync2;
                    write_ptr             <= write_ptr + 1;
                    sample_count          <= sample_count + 1;
                    if (sample_count == SAMPLE_DEPTH - 1) begin
                        state        <= S_DONE;
                        capturing    <= 0;
                        capture_done <= 1;
                    end
                end

                S_DONE: begin
                    if (!armed)
                        state <= S_IDLE;
                end
            endcase
        end
    end

    assign read_data = read_en ? sample_mem[read_addr] : {NUM_CHANNELS{1'b0}};

endmodule
