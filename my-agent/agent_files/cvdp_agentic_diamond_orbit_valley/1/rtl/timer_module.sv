module timer_module #(
    parameter integer SHORT_COUNT_PARAM = 10,
    parameter integer LONG_COUNT_PARAM  = 20
) (
    input  i_clk,
    input  i_rst_b,
    input  i_short_trigger,
    input  i_long_trigger,
    output reg o_short_timer_expired,
    output reg o_long_timer_expired
);

reg [31:0] r_short_count;
reg [31:0] r_long_count;

always @(posedge i_clk or negedge i_rst_b) begin
    if (!i_rst_b) begin
        r_short_count          <= 32'd0;
        r_long_count           <= 32'd0;
        o_short_timer_expired  <= 1'b0;
        o_long_timer_expired   <= 1'b0;
    end else begin
        if (i_short_trigger) begin
            if (r_short_count >= (SHORT_COUNT_PARAM - 1)) begin
                o_short_timer_expired <= 1'b1;
                r_short_count         <= r_short_count;
            end else begin
                o_short_timer_expired <= 1'b0;
                r_short_count         <= r_short_count + 1'b1;
            end
        end else begin
            r_short_count         <= 32'd0;
            o_short_timer_expired <= 1'b0;
        end

        if (i_long_trigger) begin
            if (r_long_count >= (LONG_COUNT_PARAM - 1)) begin
                o_long_timer_expired <= 1'b1;
                r_long_count         <= r_long_count;
            end else begin
                o_long_timer_expired <= 1'b0;
                r_long_count         <= r_long_count + 1'b1;
            end
        end else begin
            r_long_count         <= 32'd0;
            o_long_timer_expired <= 1'b0;
        end
    end
end

endmodule
