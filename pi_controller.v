// Proportional-Integral speed controller (fixed point, anti-windup)
// duty = clamp( (KP*error + KI*integral) >>> SHIFT , 0, 255 )
module pi_controller #(
    parameter signed [7:0] KP    = 8'sd1,
    parameter signed [7:0] KI    = 8'sd1,
    parameter        [3:0] SHIFT = 4'd6
)(
    input             clk,
    input             rst,
    input             update_en,        // pulse when a new speed value is ready
    input      [15:0] target_rpm,
    input      [15:0] actual_rpm,
    output reg [7:0]  duty_cycle
);
    localparam signed [31:0] I_MAX = 32'sd1048576;

    reg signed [31:0] integral;

    wire signed [31:0] error  = $signed({16'd0, target_rpm}) - $signed({16'd0, actual_rpm});
    wire signed [31:0] i_raw  = integral + error;
    wire signed [31:0] i_next = (i_raw >  I_MAX) ?  I_MAX :
                                (i_raw < -I_MAX) ? -I_MAX : i_raw;
    wire signed [31:0] ctrl   = ((KP * error) + (KI * i_next)) >>> SHIFT;

    always @(posedge clk) begin
        if (rst) begin
            integral   <= 32'sd0;
            duty_cycle <= 8'd0;
        end else if (update_en) begin
            integral <= i_next;
            if (ctrl > 32'sd255)      duty_cycle <= 8'd255;
            else if (ctrl < 32'sd0)   duty_cycle <= 8'd0;
            else                      duty_cycle <= ctrl[7:0];
        end
    end
endmodule
