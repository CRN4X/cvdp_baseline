module thermostat (
    input  wire [5:0] i_temp_feedback,
    input  wire       i_fan_on,
    input  wire       i_enable,
    input  wire       i_fault,
    input  wire       i_clr,
    input  wire       i_clk,
    input  wire       i_rst,
    output reg        o_heater_full,
    output reg        o_heater_medium,
    output reg        o_heater_low,
    output reg        o_aircon_full,
    output reg        o_aircon_medium,
    output reg        o_aircon_low,
    output reg        o_fan,
    output reg [2:0]  o_state
);

localparam [2:0] HEAT_LOW  = 3'b000,
                 HEAT_MED  = 3'b001,
                 HEAT_FULL = 3'b010,
                 AMBIENT   = 3'b011,
                 COOL_LOW  = 3'b100,
                 COOL_MED  = 3'b101,
                 COOL_FULL = 3'b110;

reg [2:0] next_state;
reg heater_full_n, heater_medium_n, heater_low_n;
reg aircon_full_n, aircon_medium_n, aircon_low_n;
reg fan_n;

always @(posedge i_clk or negedge i_rst) begin
    if (!i_rst) begin
        o_state         <= AMBIENT;
        o_heater_full   <= 1'b0;
        o_heater_medium <= 1'b0;
        o_heater_low    <= 1'b0;
        o_aircon_full   <= 1'b0;
        o_aircon_medium <= 1'b0;
        o_aircon_low    <= 1'b0;
        o_fan           <= 1'b0;
    end else begin
        o_state         <= next_state;
        o_heater_full   <= heater_full_n;
        o_heater_medium <= heater_medium_n;
        o_heater_low    <= heater_low_n;
        o_aircon_full   <= aircon_full_n;
        o_aircon_medium <= aircon_medium_n;
        o_aircon_low    <= aircon_low_n;
        o_fan           <= fan_n || i_fan_on;
    end
end

always @(*) begin
    next_state    = AMBIENT;
    heater_full_n = 1'b0;
    heater_medium_n = 1'b0;
    heater_low_n  = 1'b0;
    aircon_full_n = 1'b0;
    aircon_medium_n = 1'b0;
    aircon_low_n  = 1'b0;
    fan_n         = 1'b0;

    if (i_enable && !i_fault) begin
        if (i_temp_feedback[5]) begin
            next_state = HEAT_FULL;
        end else if (i_temp_feedback[0]) begin
            next_state = COOL_FULL;
        end else if (i_temp_feedback[4]) begin
            next_state = HEAT_MED;
        end else if (i_temp_feedback[1]) begin
            next_state = COOL_MED;
        end else if (i_temp_feedback[3]) begin
            next_state = HEAT_LOW;
        end else if (i_temp_feedback[2]) begin
            next_state = COOL_LOW;
        end else begin
            next_state = AMBIENT;
        end

        case (next_state)
            HEAT_FULL: begin
                heater_full_n = 1'b1;
                fan_n = 1'b1;
            end
            HEAT_MED: begin
                heater_medium_n = 1'b1;
                fan_n = 1'b1;
            end
            HEAT_LOW: begin
                heater_low_n = 1'b1;
                fan_n = 1'b1;
            end
            COOL_FULL: begin
                aircon_full_n = 1'b1;
                fan_n = 1'b1;
            end
            COOL_MED: begin
                aircon_medium_n = 1'b1;
                fan_n = 1'b1;
            end
            COOL_LOW: begin
                aircon_low_n = 1'b1;
                fan_n = 1'b1;
            end
            default: begin
                if (i_clr) begin
                    next_state = AMBIENT;
                end
            end
        endcase
    end
end

endmodule
