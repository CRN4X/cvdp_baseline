module des3_enc #(
    parameter NBW_DATA = 'd64,
    parameter NBW_KEY  = 'd192
) (
    input  logic              clk,
    input  logic              rst_async_n,
    input  logic              i_valid,
    input  logic [1:NBW_DATA] i_data,
    input  logic [1:NBW_KEY]  i_key,
    output logic              o_valid,
    output logic [1:NBW_DATA] o_data
);

localparam integer DES_LATENCY = 16;

logic              valid_s1;
logic              valid_s2;
logic              valid_s3;
logic [1:NBW_DATA] data_s1;
logic [1:NBW_DATA] data_s2;
logic [1:NBW_DATA] data_s3;

// Per spec and model, key is ordered as {K1, K2, K3} from MSB to LSB.
logic [1:64] k1;
logic [1:64] k2;
logic [1:64] k3;

logic [1:64] k2_pipe [0:DES_LATENCY-1];
logic [1:64] k3_pipe [0:(2*DES_LATENCY)-1];
integer i;

assign k1 = i_key[  1: 64];
assign k2 = i_key[ 65:128];
assign k3 = i_key[129:192];

always_ff @(posedge clk or negedge rst_async_n) begin
    if (!rst_async_n) begin
        for (i = 0; i < DES_LATENCY; i = i + 1) begin
            k2_pipe[i] <= '0;
        end
        for (i = 0; i < 2*DES_LATENCY; i = i + 1) begin
            k3_pipe[i] <= '0;
        end
    end else begin
        k2_pipe[0] <= k2;
        for (i = 1; i < DES_LATENCY; i = i + 1) begin
            k2_pipe[i] <= k2_pipe[i-1];
        end

        k3_pipe[0] <= k3;
        for (i = 1; i < 2*DES_LATENCY; i = i + 1) begin
            k3_pipe[i] <= k3_pipe[i-1];
        end
    end
end

des_enc #(
    .NBW_DATA(NBW_DATA),
    .NBW_KEY  (64)
) u_des_enc_1 (
    .clk        (clk),
    .rst_async_n(rst_async_n),
    .i_valid    (i_valid),
    .i_data     (i_data),
    .i_key      (k1),
    .o_valid    (valid_s1),
    .o_data     (data_s1)
);

des_dec #(
    .NBW_DATA(NBW_DATA),
    .NBW_KEY  (64)
) u_des_dec_2 (
    .clk        (clk),
    .rst_async_n(rst_async_n),
    .i_valid    (valid_s1),
    .i_data     (data_s1),
    .i_key      (k2_pipe[DES_LATENCY-1]),
    .o_valid    (valid_s2),
    .o_data     (data_s2)
);

des_enc #(
    .NBW_DATA(NBW_DATA),
    .NBW_KEY  (64)
) u_des_enc_3 (
    .clk        (clk),
    .rst_async_n(rst_async_n),
    .i_valid    (valid_s2),
    .i_data     (data_s2),
    .i_key      (k3_pipe[(2*DES_LATENCY)-1]),
    .o_valid    (valid_s3),
    .o_data     (data_s3)
);

assign o_valid = valid_s3;
assign o_data  = data_s3;

endmodule : des3_enc
