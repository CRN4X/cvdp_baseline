module aes128_decrypt #(
    parameter NBW_KEY  = 'd128,
    parameter NBW_DATA = 'd128
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

localparam NBW_BYTE   = 'd8;
localparam NBW_EX_KEY = 'd1408;

logic [NBW_BYTE-1:0] current_data_ff[4][4];
logic [NBW_BYTE-1:0] current_data_nx[4][4];
logic [NBW_BYTE-1:0] AddRoundKey[4][4];
logic [NBW_BYTE-1:0] SubBytes[4][4];
logic [NBW_BYTE-1:0] ShiftRows[4][4];
logic [NBW_BYTE-1:0] MixColumns[4][4];
logic [NBW_DATA-1:0] pending_data_ff;
logic [NBW_DATA-1:0] pending_data_nx;
logic [3:0]          round_ff;
logic [3:0]          round_nx;
logic                busy_ff;
logic                busy_nx;
logic                wait_key_ff;
logic                wait_key_nx;
logic                key_done;
logic [NBW_EX_KEY-1:0] expanded_key;

function automatic [7:0] xtime(input logic [7:0] a);
    xtime = {a[6:0], 1'b0} ^ (8'h1b & {8{a[7]}});
endfunction

function automatic [7:0] mul09(input logic [7:0] a);
    logic [7:0] a2;
    logic [7:0] a4;
    logic [7:0] a8;
    begin
        a2 = xtime(a);
        a4 = xtime(a2);
        a8 = xtime(a4);
        mul09 = a8 ^ a;
    end
endfunction

function automatic [7:0] mul0b(input logic [7:0] a);
    logic [7:0] a2;
    logic [7:0] a4;
    logic [7:0] a8;
    begin
        a2 = xtime(a);
        a4 = xtime(a2);
        a8 = xtime(a4);
        mul0b = a8 ^ a2 ^ a;
    end
endfunction

function automatic [7:0] mul0d(input logic [7:0] a);
    logic [7:0] a2;
    logic [7:0] a4;
    logic [7:0] a8;
    begin
        a2 = xtime(a);
        a4 = xtime(a2);
        a8 = xtime(a4);
        mul0d = a8 ^ a4 ^ a;
    end
endfunction

function automatic [7:0] mul0e(input logic [7:0] a);
    logic [7:0] a2;
    logic [7:0] a4;
    logic [7:0] a8;
    begin
        a2 = xtime(a);
        a4 = xtime(a2);
        a8 = xtime(a4);
        mul0e = a8 ^ a4 ^ a2;
    end
endfunction

function automatic [7:0] key_byte(
    input logic [3:0] round,
    input int row,
    input int col
);
    int idx;
    begin
        idx = round*NBW_KEY + (row + 4*col)*NBW_BYTE;
        key_byte = expanded_key[NBW_EX_KEY-idx-1-:NBW_BYTE];
    end
endfunction

assign o_done = ~busy_ff;

generate
    for(genvar i = 0; i < 4; i++) begin : out_row
        for(genvar j = 0; j < 4; j++) begin : out_col
            assign o_data[NBW_DATA-(4*j+i)*NBW_BYTE-1-:NBW_BYTE] = current_data_ff[i][j];
        end
    end
endgenerate

always_ff @(posedge clk or negedge rst_async_n) begin
    if(!rst_async_n) begin
        busy_ff         <= 1'b0;
        wait_key_ff     <= 1'b0;
        round_ff        <= 4'd0;
        pending_data_ff <= '0;
        for(int i = 0; i < 4; i++) begin
            for(int j = 0; j < 4; j++) begin
                current_data_ff[i][j] <= '0;
            end
        end
    end else begin
        busy_ff         <= busy_nx;
        wait_key_ff     <= wait_key_nx;
        round_ff        <= round_nx;
        pending_data_ff <= pending_data_nx;
        for(int i = 0; i < 4; i++) begin
            for(int j = 0; j < 4; j++) begin
                current_data_ff[i][j] <= current_data_nx[i][j];
            end
        end
    end
end

always_comb begin
    busy_nx         = busy_ff;
    wait_key_nx     = wait_key_ff;
    round_nx        = round_ff;
    pending_data_nx = pending_data_ff;

    for(int i = 0; i < 4; i++) begin
        for(int j = 0; j < 4; j++) begin
            current_data_nx[i][j] = current_data_ff[i][j];
        end
    end

    if(i_start && !busy_ff) begin
        pending_data_nx = i_data;
        if(i_update_key) begin
            busy_nx     = 1'b1;
            wait_key_nx = 1'b1;
            round_nx    = 4'd0;
        end else begin
            busy_nx     = 1'b1;
            wait_key_nx = 1'b0;
            round_nx    = 4'd9;
            for(int i = 0; i < 4; i++) begin
                for(int j = 0; j < 4; j++) begin
                    current_data_nx[i][j] = i_data[NBW_DATA-(4*j+i)*NBW_BYTE-1-:NBW_BYTE] ^ key_byte(4'd10, i, j);
                end
            end
        end
    end else if(wait_key_ff && key_done) begin
        wait_key_nx = 1'b0;
        round_nx    = 4'd9;
        for(int i = 0; i < 4; i++) begin
            for(int j = 0; j < 4; j++) begin
                current_data_nx[i][j] = pending_data_ff[NBW_DATA-(4*j+i)*NBW_BYTE-1-:NBW_BYTE] ^ key_byte(4'd10, i, j);
            end
        end
    end else if(busy_ff && !wait_key_ff) begin
        if(round_ff > 4'd0) begin
            round_nx = round_ff - 1'b1;
            for(int i = 0; i < 4; i++) begin
                for(int j = 0; j < 4; j++) begin
                    current_data_nx[i][j] = MixColumns[i][j];
                end
            end
        end else begin
            busy_nx  = 1'b0;
            round_nx = 4'd0;
            for(int i = 0; i < 4; i++) begin
                for(int j = 0; j < 4; j++) begin
                    current_data_nx[i][j] = AddRoundKey[i][j];
                end
            end
        end
    end
end

generate
    for(genvar i = 0; i < 4; i++) begin : row
        for(genvar j = 0; j < 4; j++) begin : col
            inv_sbox uu_inv_sbox (
                .i_data(ShiftRows[i][j]),
                .o_data(SubBytes[i][j])
            );
        end
    end
endgenerate

always_comb begin
    // InvShiftRows
    ShiftRows[0][0] = current_data_ff[0][0];
    ShiftRows[0][1] = current_data_ff[0][1];
    ShiftRows[0][2] = current_data_ff[0][2];
    ShiftRows[0][3] = current_data_ff[0][3];

    ShiftRows[1][0] = current_data_ff[1][3];
    ShiftRows[1][1] = current_data_ff[1][0];
    ShiftRows[1][2] = current_data_ff[1][1];
    ShiftRows[1][3] = current_data_ff[1][2];

    ShiftRows[2][0] = current_data_ff[2][2];
    ShiftRows[2][1] = current_data_ff[2][3];
    ShiftRows[2][2] = current_data_ff[2][0];
    ShiftRows[2][3] = current_data_ff[2][1];

    ShiftRows[3][0] = current_data_ff[3][1];
    ShiftRows[3][1] = current_data_ff[3][2];
    ShiftRows[3][2] = current_data_ff[3][3];
    ShiftRows[3][3] = current_data_ff[3][0];

    // AddRoundKey with current round index
    for(int i = 0; i < 4; i++) begin
        for(int j = 0; j < 4; j++) begin
            AddRoundKey[i][j] = SubBytes[i][j] ^ key_byte(round_ff, i, j);
        end
    end

    // InvMixColumns (used only for rounds 9..1)
    for(int j = 0; j < 4; j++) begin
        MixColumns[0][j] = mul0e(AddRoundKey[0][j]) ^ mul0b(AddRoundKey[1][j]) ^ mul0d(AddRoundKey[2][j]) ^ mul09(AddRoundKey[3][j]);
        MixColumns[1][j] = mul09(AddRoundKey[0][j]) ^ mul0e(AddRoundKey[1][j]) ^ mul0b(AddRoundKey[2][j]) ^ mul0d(AddRoundKey[3][j]);
        MixColumns[2][j] = mul0d(AddRoundKey[0][j]) ^ mul09(AddRoundKey[1][j]) ^ mul0e(AddRoundKey[2][j]) ^ mul0b(AddRoundKey[3][j]);
        MixColumns[3][j] = mul0b(AddRoundKey[0][j]) ^ mul0d(AddRoundKey[1][j]) ^ mul09(AddRoundKey[2][j]) ^ mul0e(AddRoundKey[3][j]);
    end
end

aes128_key_expansion uu_aes128_key_expansion (
    .clk           (clk                            ),
    .rst_async_n   (rst_async_n                    ),
    .i_start       (i_start & i_update_key & o_done),
    .i_key         (i_key                          ),
    .o_done        (key_done                       ),
    .o_expanded_key(expanded_key                   )
);

endmodule : aes128_decrypt
