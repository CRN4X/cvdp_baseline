module security_module #(
    parameter p_address_width = 8,
    parameter p_data_width    = 8,
    parameter p_unlock_code_0 = 8'hAB,
    parameter p_unlock_code_1 = 8'hCD
) (
    input  wire                        i_clk,
    input  wire                        i_rst,
    input  wire [p_address_width-1:0]  i_addr,
    input  wire [p_data_width-1:0]     i_data_in,
    input  wire                        i_read_write_enable,
    output reg                         o_secure_enable
);

localparam [1:0] ST_LOCKED_0 = 2'd0,
                 ST_LOCKED_1 = 2'd1,
                 ST_UNLOCKED = 2'd2;

reg [1:0] state_q, state_d;

always @(posedge i_clk or negedge i_rst) begin
    if (!i_rst) begin
        state_q <= ST_LOCKED_0;
    end else begin
        state_q <= state_d;
    end
end

always @(*) begin
    state_d = state_q;
    case (state_q)
        ST_LOCKED_0: begin
            if (!i_read_write_enable) begin
                if ((i_addr == {p_address_width{1'b0}}) && (i_data_in == p_unlock_code_0)) begin
                    state_d = ST_LOCKED_1;
                end else begin
                    state_d = ST_LOCKED_0;
                end
            end
        end
        ST_LOCKED_1: begin
            if (!i_read_write_enable) begin
                if ((i_addr == {{(p_address_width-1){1'b0}},1'b1}) && (i_data_in == p_unlock_code_1)) begin
                    state_d = ST_UNLOCKED;
                end else begin
                    state_d = ST_LOCKED_0;
                end
            end
        end
        ST_UNLOCKED: begin
            state_d = ST_UNLOCKED;
        end
        default: begin
            state_d = ST_LOCKED_0;
        end
    endcase
end

always @(*) begin
    o_secure_enable = (state_q == ST_UNLOCKED);
end

endmodule
