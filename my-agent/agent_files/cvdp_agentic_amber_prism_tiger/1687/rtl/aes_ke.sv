module aes_ke #(
    parameter NBW_KEY = 'd256,
    parameter NBW_OUT = 'd1920
) (
    input logic               clk,
    input logic               rst_async_n,
    input logic               i_start,
    input logic [NBW_KEY-1:0] i_key,
    output logic              o_idle,
    output logic              o_done,
    output logic [NBW_OUT-1:0] o_expanded_key
);

// ----------------------------------------
// - Parameters
// ----------------------------------------
localparam NBW_BYTE   = 'd8;
localparam NBW_WORD   = 'd32;
localparam NBW_DATA   = 'd128;
localparam NUM_WORDS  = 'd60;
localparam INIT_WORDS = 'd8;
localparam NUM_ROUNDS = 'd14;

// ----------------------------------------
// - Wires/registers creation
// ----------------------------------------
logic [NBW_BYTE-1:0] Rcon [0:6];
logic [NBW_KEY-1:0]  valid_key;
logic [NBW_OUT-1:0]  expanded_key_nx;
logic [NBW_OUT-1:0]  expanded_key_ff;
logic [NBW_KEY-1:0]  key_ff;
logic                key_exp_steps_ff;
logic [NBW_WORD-1:0] key_words [0:NUM_WORDS-1];

// ----------------------------------------
// - Output assignment
// ----------------------------------------
assign o_expanded_key = expanded_key_ff;
assign o_done = key_exp_steps_ff;
assign o_idle = ~key_exp_steps_ff;

// ----------------------------------------
// - Registers
// ----------------------------------------
always_ff @(posedge clk or negedge rst_async_n) begin : reset_regs
    if(~rst_async_n) begin
        key_ff           <= {NBW_KEY{1'b0}};
        expanded_key_ff  <= {NBW_OUT{1'b0}};
        key_exp_steps_ff <= 1'b0;
    end else begin
        if(i_start) begin
            key_ff <= i_key;
        end

        expanded_key_ff  <= expanded_key_nx;
        key_exp_steps_ff <= i_start;
    end
end

// ----------------------------------------
// - Operation logic
// ----------------------------------------
always_comb begin : key_select
    if (i_start) begin
        valid_key = i_key;
    end else begin
        valid_key = key_ff;
    end
end

assign Rcon[0] = 8'h01;
assign Rcon[1] = 8'h02;
assign Rcon[2] = 8'h04;
assign Rcon[3] = 8'h08;
assign Rcon[4] = 8'h10;
assign Rcon[5] = 8'h20;
assign Rcon[6] = 8'h40;

generate
    for(genvar i = 0; i < INIT_WORDS; i++) begin : initial_words
        assign key_words[i] = valid_key[NBW_KEY-i*NBW_WORD-1-:NBW_WORD];
    end
endgenerate

generate
    for(genvar i = INIT_WORDS; i < NUM_WORDS; i++) begin : expanded_words
        if((i % 8) == 0) begin : every_8th
            logic [NBW_WORD-1:0] rot_word;
            logic [NBW_WORD-1:0] sub_word;
            logic [NBW_WORD-1:0] temp_word;

            assign rot_word = {key_words[i-1][NBW_WORD-NBW_BYTE-1:0], key_words[i-1][NBW_WORD-1-:NBW_BYTE]};

            sbox uu_sbox0 (
                .i_data(rot_word[NBW_WORD-1-:NBW_BYTE]),
                .o_data(sub_word[NBW_WORD-1-:NBW_BYTE])
            );
            sbox uu_sbox1 (
                .i_data(rot_word[NBW_WORD-NBW_BYTE-1-:NBW_BYTE]),
                .o_data(sub_word[NBW_WORD-NBW_BYTE-1-:NBW_BYTE])
            );
            sbox uu_sbox2 (
                .i_data(rot_word[NBW_WORD-2*NBW_BYTE-1-:NBW_BYTE]),
                .o_data(sub_word[NBW_WORD-2*NBW_BYTE-1-:NBW_BYTE])
            );
            sbox uu_sbox3 (
                .i_data(rot_word[NBW_WORD-3*NBW_BYTE-1-:NBW_BYTE]),
                .o_data(sub_word[NBW_WORD-3*NBW_BYTE-1-:NBW_BYTE])
            );

            assign temp_word = {sub_word[NBW_WORD-1-:NBW_BYTE] ^ Rcon[(i/8)-1], sub_word[NBW_WORD-NBW_BYTE-1:0]};
            assign key_words[i] = key_words[i-INIT_WORDS] ^ temp_word;
        end else if((i % 8) == 4) begin : every_4th
            logic [NBW_WORD-1:0] sub_word;

            sbox uu_sbox0 (
                .i_data(key_words[i-1][NBW_WORD-1-:NBW_BYTE]),
                .o_data(sub_word[NBW_WORD-1-:NBW_BYTE])
            );
            sbox uu_sbox1 (
                .i_data(key_words[i-1][NBW_WORD-NBW_BYTE-1-:NBW_BYTE]),
                .o_data(sub_word[NBW_WORD-NBW_BYTE-1-:NBW_BYTE])
            );
            sbox uu_sbox2 (
                .i_data(key_words[i-1][NBW_WORD-2*NBW_BYTE-1-:NBW_BYTE]),
                .o_data(sub_word[NBW_WORD-2*NBW_BYTE-1-:NBW_BYTE])
            );
            sbox uu_sbox3 (
                .i_data(key_words[i-1][NBW_WORD-3*NBW_BYTE-1-:NBW_BYTE]),
                .o_data(sub_word[NBW_WORD-3*NBW_BYTE-1-:NBW_BYTE])
            );

            assign key_words[i] = key_words[i-INIT_WORDS] ^ sub_word;
        end else begin : normal
            assign key_words[i] = key_words[i-INIT_WORDS] ^ key_words[i-1];
        end
    end
endgenerate

generate
    for(genvar r = 0; r < (NUM_ROUNDS + 1); r++) begin : round_keys
        assign expanded_key_nx[NBW_OUT-r*NBW_DATA-1-:NBW_DATA] =
            {key_words[4*r], key_words[4*r+1], key_words[4*r+2], key_words[4*r+3]};
    end
endgenerate

endmodule : aes_ke
