// Measures clock cycles between zero crossings, then computes
// speed_rpm = SPEED_CONST / period using a small sequential divider
// (no '/' operator, so it synthesizes to a compact circuit).
// SPEED_CONST = CLK_FREQ * 60 / (STEPS_PER_REV * POLE_PAIRS)
//   100e6 * 60 / (6 * 7) = 142857142
module speed_calculator #(
    parameter [31:0] SPEED_CONST = 32'd142857142
)(
    input             clk,
    input             rst,
    input             zero_cross_flag,
    output reg [23:0] period_cycles,
    output reg [31:0] speed_rpm,
    output reg        speed_valid
);
    reg [23:0] counter;
    reg [23:0] den;
    reg [31:0] num, rem, quo;
    reg [5:0]  bitcnt;
    reg        busy;

    wire [31:0] trial = {rem[30:0], num[31]};
    wire        ge    = (trial >= {8'd0, den});
    wire [31:0] quo_n = {quo[30:0], ge};

    always @(posedge clk) begin
        if (rst) begin
            counter       <= 24'd0;
            period_cycles <= 24'd0;
            speed_rpm     <= 32'd0;
            speed_valid   <= 1'b0;
            den <= 24'd1; num <= 32'd0; rem <= 32'd0; quo <= 32'd0;
            bitcnt <= 6'd0;
            busy   <= 1'b0;
        end else begin
            speed_valid <= 1'b0;
            if (counter != 24'hFFFFFF)
                counter <= counter + 24'd1;

            if (zero_cross_flag) begin
                counter       <= 24'd1;
                period_cycles <= counter;
                if (!busy && counter != 24'd0) begin
                    den    <= counter;
                    num    <= SPEED_CONST;
                    rem    <= 32'd0;
                    quo    <= 32'd0;
                    bitcnt <= 6'd32;
                    busy   <= 1'b1;
                end
            end

            if (busy) begin
                num <= {num[30:0], 1'b0};
                rem <= ge ? (trial - {8'd0, den}) : trial;
                quo <= quo_n;
                bitcnt <= bitcnt - 6'd1;
                if (bitcnt == 6'd1) begin
                    busy        <= 1'b0;
                    speed_rpm   <= quo_n;
                    speed_valid <= 1'b1;
                end
            end
        end
    end
endmodule
