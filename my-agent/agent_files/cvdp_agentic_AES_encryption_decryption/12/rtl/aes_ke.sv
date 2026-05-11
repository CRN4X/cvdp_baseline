module aes_ke #(
    parameter NBW_KEY = 'd256,
    parameter NBW_OUT = 'd1920
) (
    input  logic               clk,
    input  logic               rst_async_n,
    input  logic               i_start,
    input  logic [NBW_KEY-1:0] i_key,
    output logic               o_idle,
    output logic               o_done,
    output logic [NBW_OUT-1:0] o_expanded_key
);

localparam NBW_BYTE  = 'd8;
localparam NBW_WORD  = 'd32;
localparam NKEY_WORD = 'd8;
localparam NEXP_WORD = 'd60;

logic [NBW_WORD-1:0] key_words_ff [0:NEXP_WORD-1];
logic [5:0]          idx_ff;
logic                busy_ff;
logic                done_ff;

logic [NBW_WORD-1:0] temp_word;
logic [NBW_WORD-1:0] rot_word;
logic [NBW_WORD-1:0] subword_in;
logic [NBW_WORD-1:0] subword_out;
logic [NBW_WORD-1:0] key_word_new;
logic [7:0]          rcon_value;

assign o_idle = ~busy_ff;
assign o_done = done_ff;

for(genvar word_idx = 0; word_idx < NEXP_WORD; word_idx++) begin : out_pack
    assign o_expanded_key[NBW_OUT-1-word_idx*NBW_WORD-:NBW_WORD] = key_words_ff[word_idx];
end

sbox uu_sbox0 (
    .i_data(subword_in[NBW_WORD-1-:NBW_BYTE]),
    .o_data(subword_out[NBW_WORD-1-:NBW_BYTE])
);

sbox uu_sbox1 (
    .i_data(subword_in[NBW_WORD-NBW_BYTE-1-:NBW_BYTE]),
    .o_data(subword_out[NBW_WORD-NBW_BYTE-1-:NBW_BYTE])
);

sbox uu_sbox2 (
    .i_data(subword_in[NBW_WORD-2*NBW_BYTE-1-:NBW_BYTE]),
    .o_data(subword_out[NBW_WORD-2*NBW_BYTE-1-:NBW_BYTE])
);

sbox uu_sbox3 (
    .i_data(subword_in[NBW_WORD-3*NBW_BYTE-1-:NBW_BYTE]),
    .o_data(subword_out[NBW_WORD-3*NBW_BYTE-1-:NBW_BYTE])
);

always_comb begin : word_compute
    temp_word  = 32'd0;
    rot_word   = 32'd0;
    subword_in = 32'd0;
    rcon_value = 8'd0;
    key_word_new = 32'd0;

    if ((idx_ff >= 6'd8) && (idx_ff < 6'd60)) begin
        temp_word = key_words_ff[idx_ff-1];

        if (idx_ff[2:0] == 3'd0) begin
            rot_word = {temp_word[23:0], temp_word[31:24]};
            subword_in = rot_word;

            case (idx_ff)
                6'd8  : rcon_value = 8'h01;
                6'd16 : rcon_value = 8'h02;
                6'd24 : rcon_value = 8'h04;
                6'd32 : rcon_value = 8'h08;
                6'd40 : rcon_value = 8'h10;
                6'd48 : rcon_value = 8'h20;
                6'd56 : rcon_value = 8'h40;
                default: rcon_value = 8'd0;
            endcase

            key_word_new = key_words_ff[idx_ff-NKEY_WORD] ^ (subword_out ^ {rcon_value, 24'd0});
        end else if (idx_ff[2:0] == 3'd4) begin
            subword_in = temp_word;
            key_word_new = key_words_ff[idx_ff-NKEY_WORD] ^ subword_out;
        end else begin
            key_word_new = key_words_ff[idx_ff-NKEY_WORD] ^ temp_word;
        end
    end
end

always_ff @(posedge clk or negedge rst_async_n) begin : key_regs
    if(~rst_async_n) begin
        idx_ff  <= 6'd0;
        busy_ff <= 1'b0;
        done_ff <= 1'b0;

        for(int word_idx = 0; word_idx < NEXP_WORD; word_idx++) begin
            key_words_ff[word_idx] <= 32'd0;
        end
    end else begin
        done_ff <= 1'b0;

        if (i_start && !busy_ff) begin
            for(int word_idx = 0; word_idx < NKEY_WORD; word_idx++) begin
                key_words_ff[word_idx] <= i_key[NBW_KEY-1-word_idx*NBW_WORD-:NBW_WORD];
            end
            for(int word_idx = NKEY_WORD; word_idx < NEXP_WORD; word_idx++) begin
                key_words_ff[word_idx] <= 32'd0;
            end

            idx_ff  <= 6'd8;
            busy_ff <= 1'b1;
        end else if (busy_ff) begin
            key_words_ff[idx_ff] <= key_word_new;

            if (idx_ff == 6'd59) begin
                idx_ff  <= 6'd0;
                busy_ff <= 1'b0;
                done_ff <= 1'b1;
            end else begin
                idx_ff <= idx_ff + 1'b1;
            end
        end
    end
end

endmodule : aes_ke
