// Detects when the (ADC) floating-phase voltage crosses the midpoint
module zero_cross_detector #(
    parameter [11:0] MIDPOINT = 12'h800
)(
    input             clk,
    input             rst,
    input      [11:0] adc_sample,
    input             sample_valid,
    output reg        zero_cross_flag
);
    reg prev_sign;
    reg first_sample;
    wire curr_sign = (adc_sample >= MIDPOINT);

    always @(posedge clk) begin
        if (rst) begin
            prev_sign       <= 1'b0;
            first_sample    <= 1'b1;
            zero_cross_flag <= 1'b0;
        end else if (sample_valid) begin
            first_sample    <= 1'b0;
            prev_sign       <= curr_sign;
            zero_cross_flag <= (~first_sample) & (curr_sign ^ prev_sign);
        end else begin
            zero_cross_flag <= 1'b0;
        end
    end
endmodule
