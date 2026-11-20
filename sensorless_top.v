// Top level for ORFS. In a real chip the ADC sits outside, so the
// samples arrive on input pins (no ROM / $readmemh inside the design).
module sensorless_top(
    input         clk,
    input         rst,
    input  [11:0] adc_sample,
    input         sample_valid,
    input  [15:0] target_rpm,
    output [15:0] estimated_rpm,
    output [2:0]  commutation_state,
    output [5:0]  phase_drive,
    output        pwm_out
);
    wire        zero_cross_flag;
    wire [23:0] period_cycles;
    wire [31:0] speed_rpm_full;
    wire        speed_valid;
    wire [7:0]  duty_cycle;

    assign estimated_rpm = (speed_rpm_full > 32'd65535) ? 16'hFFFF : speed_rpm_full[15:0];

    zero_cross_detector zc_inst (
        .clk(clk), .rst(rst),
        .adc_sample(adc_sample), .sample_valid(sample_valid),
        .zero_cross_flag(zero_cross_flag)
    );

    speed_calculator speed_inst (
        .clk(clk), .rst(rst),
        .zero_cross_flag(zero_cross_flag),
        .period_cycles(period_cycles),
        .speed_rpm(speed_rpm_full),
        .speed_valid(speed_valid)
    );

    commutation_fsm fsm_inst (
        .clk(clk), .rst(rst),
        .zero_cross_flag(zero_cross_flag),
        .state(commutation_state), .phase_drive(phase_drive)
    );

    pi_controller pi_inst (
        .clk(clk), .rst(rst), .update_en(speed_valid),
        .target_rpm(target_rpm), .actual_rpm(estimated_rpm),
        .duty_cycle(duty_cycle)
    );

    pwm_generator pwm_inst (
        .clk(clk), .rst(rst), .duty_cycle(duty_cycle), .pwm_out(pwm_out)
    );
endmodule
