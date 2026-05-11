module aes_encrypt #(
    parameter NBW_KEY  = 256,
    parameter NBW_DATA = 128
) (
    input  logic                clk,
    input  logic                rst_async_n,
    input  logic                i_update_key,
    input  logic [NBW_KEY-1:0]  i_key,
    input  logic                i_start,
    input  logic [NBW_DATA-1:0] i_data,
    output logic                o_done,
    output logic [NBW_DATA-1:0] o_data
);

localparam int ROUNDS      = 14;
localparam int KEY_WORDS   = 60;
localparam int EXP_KEY_WID = 1920;

logic [NBW_KEY-1:0]  key_ff;
logic [NBW_KEY-1:0]  active_key_ff;
logic [NBW_DATA-1:0] state_ff;
logic [3:0]          round_ff;

assign o_done = (round_ff == 4'd0);
assign o_data = state_ff;

function automatic [7:0] sbox_f(input [7:0] i_data);
    begin
        case (i_data)
            8'h00: sbox_f = 8'h63; 8'h01: sbox_f = 8'h7C; 8'h02: sbox_f = 8'h77; 8'h03: sbox_f = 8'h7B;
            8'h04: sbox_f = 8'hF2; 8'h05: sbox_f = 8'h6B; 8'h06: sbox_f = 8'h6F; 8'h07: sbox_f = 8'hC5;
            8'h08: sbox_f = 8'h30; 8'h09: sbox_f = 8'h01; 8'h0A: sbox_f = 8'h67; 8'h0B: sbox_f = 8'h2B;
            8'h0C: sbox_f = 8'hFE; 8'h0D: sbox_f = 8'hD7; 8'h0E: sbox_f = 8'hAB; 8'h0F: sbox_f = 8'h76;
            8'h10: sbox_f = 8'hCA; 8'h11: sbox_f = 8'h82; 8'h12: sbox_f = 8'hC9; 8'h13: sbox_f = 8'h7D;
            8'h14: sbox_f = 8'hFA; 8'h15: sbox_f = 8'h59; 8'h16: sbox_f = 8'h47; 8'h17: sbox_f = 8'hF0;
            8'h18: sbox_f = 8'hAD; 8'h19: sbox_f = 8'hD4; 8'h1A: sbox_f = 8'hA2; 8'h1B: sbox_f = 8'hAF;
            8'h1C: sbox_f = 8'h9C; 8'h1D: sbox_f = 8'hA4; 8'h1E: sbox_f = 8'h72; 8'h1F: sbox_f = 8'hC0;
            8'h20: sbox_f = 8'hB7; 8'h21: sbox_f = 8'hFD; 8'h22: sbox_f = 8'h93; 8'h23: sbox_f = 8'h26;
            8'h24: sbox_f = 8'h36; 8'h25: sbox_f = 8'h3F; 8'h26: sbox_f = 8'hF7; 8'h27: sbox_f = 8'hCC;
            8'h28: sbox_f = 8'h34; 8'h29: sbox_f = 8'hA5; 8'h2A: sbox_f = 8'hE5; 8'h2B: sbox_f = 8'hF1;
            8'h2C: sbox_f = 8'h71; 8'h2D: sbox_f = 8'hD8; 8'h2E: sbox_f = 8'h31; 8'h2F: sbox_f = 8'h15;
            8'h30: sbox_f = 8'h04; 8'h31: sbox_f = 8'hC7; 8'h32: sbox_f = 8'h23; 8'h33: sbox_f = 8'hC3;
            8'h34: sbox_f = 8'h18; 8'h35: sbox_f = 8'h96; 8'h36: sbox_f = 8'h05; 8'h37: sbox_f = 8'h9A;
            8'h38: sbox_f = 8'h07; 8'h39: sbox_f = 8'h12; 8'h3A: sbox_f = 8'h80; 8'h3B: sbox_f = 8'hE2;
            8'h3C: sbox_f = 8'hEB; 8'h3D: sbox_f = 8'h27; 8'h3E: sbox_f = 8'hB2; 8'h3F: sbox_f = 8'h75;
            8'h40: sbox_f = 8'h09; 8'h41: sbox_f = 8'h83; 8'h42: sbox_f = 8'h2C; 8'h43: sbox_f = 8'h1A;
            8'h44: sbox_f = 8'h1B; 8'h45: sbox_f = 8'h6E; 8'h46: sbox_f = 8'h5A; 8'h47: sbox_f = 8'hA0;
            8'h48: sbox_f = 8'h52; 8'h49: sbox_f = 8'h3B; 8'h4A: sbox_f = 8'hD6; 8'h4B: sbox_f = 8'hB3;
            8'h4C: sbox_f = 8'h29; 8'h4D: sbox_f = 8'hE3; 8'h4E: sbox_f = 8'h2F; 8'h4F: sbox_f = 8'h84;
            8'h50: sbox_f = 8'h53; 8'h51: sbox_f = 8'hD1; 8'h52: sbox_f = 8'h00; 8'h53: sbox_f = 8'hED;
            8'h54: sbox_f = 8'h20; 8'h55: sbox_f = 8'hFC; 8'h56: sbox_f = 8'hB1; 8'h57: sbox_f = 8'h5B;
            8'h58: sbox_f = 8'h6A; 8'h59: sbox_f = 8'hCB; 8'h5A: sbox_f = 8'hBE; 8'h5B: sbox_f = 8'h39;
            8'h5C: sbox_f = 8'h4A; 8'h5D: sbox_f = 8'h4C; 8'h5E: sbox_f = 8'h58; 8'h5F: sbox_f = 8'hCF;
            8'h60: sbox_f = 8'hD0; 8'h61: sbox_f = 8'hEF; 8'h62: sbox_f = 8'hAA; 8'h63: sbox_f = 8'hFB;
            8'h64: sbox_f = 8'h43; 8'h65: sbox_f = 8'h4D; 8'h66: sbox_f = 8'h33; 8'h67: sbox_f = 8'h85;
            8'h68: sbox_f = 8'h45; 8'h69: sbox_f = 8'hF9; 8'h6A: sbox_f = 8'h02; 8'h6B: sbox_f = 8'h7F;
            8'h6C: sbox_f = 8'h50; 8'h6D: sbox_f = 8'h3C; 8'h6E: sbox_f = 8'h9F; 8'h6F: sbox_f = 8'hA8;
            8'h70: sbox_f = 8'h51; 8'h71: sbox_f = 8'hA3; 8'h72: sbox_f = 8'h40; 8'h73: sbox_f = 8'h8F;
            8'h74: sbox_f = 8'h92; 8'h75: sbox_f = 8'h9D; 8'h76: sbox_f = 8'h38; 8'h77: sbox_f = 8'hF5;
            8'h78: sbox_f = 8'hBC; 8'h79: sbox_f = 8'hB6; 8'h7A: sbox_f = 8'hDA; 8'h7B: sbox_f = 8'h21;
            8'h7C: sbox_f = 8'h10; 8'h7D: sbox_f = 8'hFF; 8'h7E: sbox_f = 8'hF3; 8'h7F: sbox_f = 8'hD2;
            8'h80: sbox_f = 8'hCD; 8'h81: sbox_f = 8'h0C; 8'h82: sbox_f = 8'h13; 8'h83: sbox_f = 8'hEC;
            8'h84: sbox_f = 8'h5F; 8'h85: sbox_f = 8'h97; 8'h86: sbox_f = 8'h44; 8'h87: sbox_f = 8'h17;
            8'h88: sbox_f = 8'hC4; 8'h89: sbox_f = 8'hA7; 8'h8A: sbox_f = 8'h7E; 8'h8B: sbox_f = 8'h3D;
            8'h8C: sbox_f = 8'h64; 8'h8D: sbox_f = 8'h5D; 8'h8E: sbox_f = 8'h19; 8'h8F: sbox_f = 8'h73;
            8'h90: sbox_f = 8'h60; 8'h91: sbox_f = 8'h81; 8'h92: sbox_f = 8'h4F; 8'h93: sbox_f = 8'hDC;
            8'h94: sbox_f = 8'h22; 8'h95: sbox_f = 8'h2A; 8'h96: sbox_f = 8'h90; 8'h97: sbox_f = 8'h88;
            8'h98: sbox_f = 8'h46; 8'h99: sbox_f = 8'hEE; 8'h9A: sbox_f = 8'hB8; 8'h9B: sbox_f = 8'h14;
            8'h9C: sbox_f = 8'hDE; 8'h9D: sbox_f = 8'h5E; 8'h9E: sbox_f = 8'h0B; 8'h9F: sbox_f = 8'hDB;
            8'hA0: sbox_f = 8'hE0; 8'hA1: sbox_f = 8'h32; 8'hA2: sbox_f = 8'h3A; 8'hA3: sbox_f = 8'h0A;
            8'hA4: sbox_f = 8'h49; 8'hA5: sbox_f = 8'h06; 8'hA6: sbox_f = 8'h24; 8'hA7: sbox_f = 8'h5C;
            8'hA8: sbox_f = 8'hC2; 8'hA9: sbox_f = 8'hD3; 8'hAA: sbox_f = 8'hAC; 8'hAB: sbox_f = 8'h62;
            8'hAC: sbox_f = 8'h91; 8'hAD: sbox_f = 8'h95; 8'hAE: sbox_f = 8'hE4; 8'hAF: sbox_f = 8'h79;
            8'hB0: sbox_f = 8'hE7; 8'hB1: sbox_f = 8'hC8; 8'hB2: sbox_f = 8'h37; 8'hB3: sbox_f = 8'h6D;
            8'hB4: sbox_f = 8'h8D; 8'hB5: sbox_f = 8'hD5; 8'hB6: sbox_f = 8'h4E; 8'hB7: sbox_f = 8'hA9;
            8'hB8: sbox_f = 8'h6C; 8'hB9: sbox_f = 8'h56; 8'hBA: sbox_f = 8'hF4; 8'hBB: sbox_f = 8'hEA;
            8'hBC: sbox_f = 8'h65; 8'hBD: sbox_f = 8'h7A; 8'hBE: sbox_f = 8'hAE; 8'hBF: sbox_f = 8'h08;
            8'hC0: sbox_f = 8'hBA; 8'hC1: sbox_f = 8'h78; 8'hC2: sbox_f = 8'h25; 8'hC3: sbox_f = 8'h2E;
            8'hC4: sbox_f = 8'h1C; 8'hC5: sbox_f = 8'hA6; 8'hC6: sbox_f = 8'hB4; 8'hC7: sbox_f = 8'hC6;
            8'hC8: sbox_f = 8'hE8; 8'hC9: sbox_f = 8'hDD; 8'hCA: sbox_f = 8'h74; 8'hCB: sbox_f = 8'h1F;
            8'hCC: sbox_f = 8'h4B; 8'hCD: sbox_f = 8'hBD; 8'hCE: sbox_f = 8'h8B; 8'hCF: sbox_f = 8'h8A;
            8'hD0: sbox_f = 8'h70; 8'hD1: sbox_f = 8'h3E; 8'hD2: sbox_f = 8'hB5; 8'hD3: sbox_f = 8'h66;
            8'hD4: sbox_f = 8'h48; 8'hD5: sbox_f = 8'h03; 8'hD6: sbox_f = 8'hF6; 8'hD7: sbox_f = 8'h0E;
            8'hD8: sbox_f = 8'h61; 8'hD9: sbox_f = 8'h35; 8'hDA: sbox_f = 8'h57; 8'hDB: sbox_f = 8'hB9;
            8'hDC: sbox_f = 8'h86; 8'hDD: sbox_f = 8'hC1; 8'hDE: sbox_f = 8'h1D; 8'hDF: sbox_f = 8'h9E;
            8'hE0: sbox_f = 8'hE1; 8'hE1: sbox_f = 8'hF8; 8'hE2: sbox_f = 8'h98; 8'hE3: sbox_f = 8'h11;
            8'hE4: sbox_f = 8'h69; 8'hE5: sbox_f = 8'hD9; 8'hE6: sbox_f = 8'h8E; 8'hE7: sbox_f = 8'h94;
            8'hE8: sbox_f = 8'h9B; 8'hE9: sbox_f = 8'h1E; 8'hEA: sbox_f = 8'h87; 8'hEB: sbox_f = 8'hE9;
            8'hEC: sbox_f = 8'hCE; 8'hED: sbox_f = 8'h55; 8'hEE: sbox_f = 8'h28; 8'hEF: sbox_f = 8'hDF;
            8'hF0: sbox_f = 8'h8C; 8'hF1: sbox_f = 8'hA1; 8'hF2: sbox_f = 8'h89; 8'hF3: sbox_f = 8'h0D;
            8'hF4: sbox_f = 8'hBF; 8'hF5: sbox_f = 8'hE6; 8'hF6: sbox_f = 8'h42; 8'hF7: sbox_f = 8'h68;
            8'hF8: sbox_f = 8'h41; 8'hF9: sbox_f = 8'h99; 8'hFA: sbox_f = 8'h2D; 8'hFB: sbox_f = 8'h0F;
            8'hFC: sbox_f = 8'hB0; 8'hFD: sbox_f = 8'h54; 8'hFE: sbox_f = 8'hBB; 8'hFF: sbox_f = 8'h16;
        endcase
    end
endfunction

function automatic [7:0] xtime2_f(input [7:0] a);
    begin
        xtime2_f = {a[6:0], 1'b0};
        if (a[7])
            xtime2_f = xtime2_f ^ 8'h1B;
    end
endfunction

function automatic [31:0] rot_word_f(input [31:0] w);
    begin
        rot_word_f = {w[23:0], w[31:24]};
    end
endfunction

function automatic [31:0] sub_word_f(input [31:0] w);
    begin
        sub_word_f = {sbox_f(w[31:24]), sbox_f(w[23:16]), sbox_f(w[15:8]), sbox_f(w[7:0])};
    end
endfunction

function automatic [31:0] rcon_word_f(input integer idx);
    begin
        case (idx)
            0: rcon_word_f = 32'h01000000;
            1: rcon_word_f = 32'h02000000;
            2: rcon_word_f = 32'h04000000;
            3: rcon_word_f = 32'h08000000;
            4: rcon_word_f = 32'h10000000;
            5: rcon_word_f = 32'h20000000;
            6: rcon_word_f = 32'h40000000;
            default: rcon_word_f = 32'h00000000;
        endcase
    end
endfunction

function automatic [EXP_KEY_WID-1:0] expand_key_f(input [NBW_KEY-1:0] key_in);
    integer i;
    reg [31:0] w [0:KEY_WORDS-1];
    reg [31:0] tmp;
    reg [EXP_KEY_WID-1:0] expanded;
    begin
        for (i = 0; i < 8; i = i + 1)
            w[i] = key_in[NBW_KEY-1-32*i -: 32];

        for (i = 8; i < KEY_WORDS; i = i + 1) begin
            tmp = w[i-1];
            if ((i % 8) == 0)
                tmp = sub_word_f(rot_word_f(tmp)) ^ rcon_word_f((i/8)-1);
            else if ((i % 8) == 4)
                tmp = sub_word_f(tmp);
            w[i] = w[i-8] ^ tmp;
        end

        for (i = 0; i < KEY_WORDS; i = i + 1)
            expanded[EXP_KEY_WID-1-32*i -: 32] = w[i];

        expand_key_f = expanded;
    end
endfunction

function automatic [NBW_DATA-1:0] add_round_key_f(
    input [NBW_DATA-1:0] data_in,
    input [EXP_KEY_WID-1:0] exp_key,
    input integer round_idx
);
    begin
        add_round_key_f = data_in ^ exp_key[EXP_KEY_WID-1-128*round_idx -: 128];
    end
endfunction

function automatic [NBW_DATA-1:0] sub_bytes_f(input [NBW_DATA-1:0] data_in);
    integer i;
    reg [NBW_DATA-1:0] out_data;
    begin
        for (i = 0; i < 16; i = i + 1)
            out_data[NBW_DATA-1-8*i -: 8] = sbox_f(data_in[NBW_DATA-1-8*i -: 8]);
        sub_bytes_f = out_data;
    end
endfunction

function automatic [NBW_DATA-1:0] shift_rows_f(input [NBW_DATA-1:0] data_in);
    reg [7:0] b [0:15];
    reg [7:0] r [0:15];
    integer i;
    reg [NBW_DATA-1:0] out_data;
    begin
        for (i = 0; i < 16; i = i + 1)
            b[i] = data_in[NBW_DATA-1-8*i -: 8];

        r[0]  = b[0];  r[4]  = b[4];  r[8]  = b[8];  r[12] = b[12];
        r[1]  = b[5];  r[5]  = b[9];  r[9]  = b[13]; r[13] = b[1];
        r[2]  = b[10]; r[6]  = b[14]; r[10] = b[2];  r[14] = b[6];
        r[3]  = b[15]; r[7]  = b[3];  r[11] = b[7];  r[15] = b[11];

        for (i = 0; i < 16; i = i + 1)
            out_data[NBW_DATA-1-8*i -: 8] = r[i];

        shift_rows_f = out_data;
    end
endfunction

function automatic [NBW_DATA-1:0] mix_columns_f(input [NBW_DATA-1:0] data_in);
    reg [7:0] b [0:15];
    reg [7:0] r [0:15];
    integer c;
    integer i;
    reg [NBW_DATA-1:0] out_data;
    begin
        for (i = 0; i < 16; i = i + 1)
            b[i] = data_in[NBW_DATA-1-8*i -: 8];

        for (c = 0; c < 4; c = c + 1) begin
            r[4*c+0] = xtime2_f(b[4*c+0]) ^ (xtime2_f(b[4*c+1]) ^ b[4*c+1]) ^ b[4*c+2] ^ b[4*c+3];
            r[4*c+1] = b[4*c+0] ^ xtime2_f(b[4*c+1]) ^ (xtime2_f(b[4*c+2]) ^ b[4*c+2]) ^ b[4*c+3];
            r[4*c+2] = b[4*c+0] ^ b[4*c+1] ^ xtime2_f(b[4*c+2]) ^ (xtime2_f(b[4*c+3]) ^ b[4*c+3]);
            r[4*c+3] = (xtime2_f(b[4*c+0]) ^ b[4*c+0]) ^ b[4*c+1] ^ b[4*c+2] ^ xtime2_f(b[4*c+3]);
        end

        for (i = 0; i < 16; i = i + 1)
            out_data[NBW_DATA-1-8*i -: 8] = r[i];

        mix_columns_f = out_data;
    end
endfunction

always_ff @(posedge clk or negedge rst_async_n) begin
    reg [EXP_KEY_WID-1:0] expanded_key;
    reg [NBW_DATA-1:0] round_state;
    reg [NBW_KEY-1:0]  selected_key;

    if (!rst_async_n) begin
        key_ff        <= '0;
        active_key_ff <= '0;
        state_ff      <= '0;
        round_ff      <= 4'd0;
    end else begin
        if (i_start && o_done) begin
            selected_key = i_update_key ? i_key : key_ff;
            expanded_key = expand_key_f(selected_key);

            key_ff        <= i_update_key ? i_key : key_ff;
            active_key_ff <= selected_key;
            state_ff      <= add_round_key_f(i_data, expanded_key, 0);
            round_ff      <= 4'd1;
        end else if (round_ff != 4'd0) begin
            expanded_key = expand_key_f(active_key_ff);
            round_state  = sub_bytes_f(state_ff);
            round_state  = shift_rows_f(round_state);

            if (round_ff < ROUNDS)
                round_state = mix_columns_f(round_state);

            round_state = add_round_key_f(round_state, expanded_key, round_ff);
            state_ff    <= round_state;

            if (round_ff == ROUNDS)
                round_ff <= 4'd0;
            else
                round_ff <= round_ff + 1'b1;
        end
    end
end

endmodule : aes_encrypt
