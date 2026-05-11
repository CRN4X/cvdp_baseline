module traffic_light_controller_top #(
    parameter integer SHORT_COUNT = 10,
    parameter integer LONG_COUNT  = 20
) (
    input  i_clk,
    input  i_rst_b,
    input  i_vehicle_sensor_input,
    output [2:0] o_main,
    output [2:0] o_side
);

wire w_short_trigger;
wire w_long_trigger;
wire w_short_timer_expired;
wire w_long_timer_expired;

traffic_controller_fsm u_traffic_controller_fsm (
    .i_clk(i_clk),
    .i_rst_b(i_rst_b),
    .i_vehicle_sensor_input(i_vehicle_sensor_input),
    .i_short_timer(w_short_timer_expired),
    .i_long_timer(w_long_timer_expired),
    .o_short_trigger(w_short_trigger),
    .o_long_trigger(w_long_trigger),
    .o_main(o_main),
    .o_side(o_side)
);

timer_module #(
    .SHORT_COUNT_PARAM(SHORT_COUNT),
    .LONG_COUNT_PARAM(LONG_COUNT)
) u_timer_module (
    .i_clk(i_clk),
    .i_rst_b(i_rst_b),
    .i_short_trigger(w_short_trigger),
    .i_long_trigger(w_long_trigger),
    .o_short_timer_expired(w_short_timer_expired),
    .o_long_timer_expired(w_long_timer_expired)
);

endmodule
