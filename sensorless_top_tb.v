`timescale 1ns/1ps
module sensorless_top_tb;
    reg clk = 0, rst = 1, sample_valid = 0;
    reg [11:0] adc_sample = 0;
    reg [15:0] target_rpm = 16'd30000;
    wire [15:0] estimated_rpm; wire [2:0] commutation_state; wire [5:0] phase_drive; wire pwm_out;

    sensorless_top dut(.clk(clk), .rst(rst), .adc_sample(adc_sample), .sample_valid(sample_valid),
        .target_rpm(target_rpm), .estimated_rpm(estimated_rpm),
        .commutation_state(commutation_state), .phase_drive(phase_drive), .pwm_out(pwm_out));

    always #5 clk = ~clk;   // 100 MHz

    // Triangle wave "back-EMF": step every 100 clocks
    reg up = 1; integer cnt = 0;
    always @(posedge clk) begin
        sample_valid <= 1;
        cnt <= cnt + 1;
        if (cnt == 99) begin
            cnt <= 0;
            if (up) begin
                if (adc_sample == 12'd4032) begin up <= 0; adc_sample <= 12'd3968; end
                else adc_sample <= adc_sample + 12'd64;
            end else begin
                if (adc_sample == 12'd0) begin up <= 1; adc_sample <= 12'd64; end
                else adc_sample <= adc_sample - 12'd64;
            end
        end
    end

    initial begin
        $dumpfile("sensorless_top_tb.vcd");
        $dumpvars(0, sensorless_top_tb);
        #100 rst = 0;
        #3_000_000 target_rpm = 16'd10000;
        #3_000_000 $finish;
    end

    always @(posedge dut.speed_valid)
        $display("t=%0t state=%0d est_rpm=%0d target=%0d duty=%0d",
                 $time, commutation_state, estimated_rpm, target_rpm, dut.duty_cycle);
endmodule
