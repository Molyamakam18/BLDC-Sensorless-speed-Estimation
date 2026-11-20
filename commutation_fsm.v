// 6-step commutation sequencer (advances on each zero crossing)
module commutation_fsm(
    input            clk,
    input            rst,
    input            zero_cross_flag,
    output reg [2:0] state,
    output reg [5:0] phase_drive   // {AH,BH,CH,AL,BL,CL} pattern (example)
);
    always @(posedge clk) begin
        if (rst)
            state <= 3'd0;
        else if (zero_cross_flag)
            state <= (state == 3'd5) ? 3'd0 : state + 3'd1;
    end

    always @(*) begin
        case (state)
            3'd0:    phase_drive = 6'b100001;
            3'd1:    phase_drive = 6'b100010;
            3'd2:    phase_drive = 6'b010010;
            3'd3:    phase_drive = 6'b010100;
            3'd4:    phase_drive = 6'b001100;
            3'd5:    phase_drive = 6'b001001;
            default: phase_drive = 6'b000000;
        endcase
    end
endmodule
