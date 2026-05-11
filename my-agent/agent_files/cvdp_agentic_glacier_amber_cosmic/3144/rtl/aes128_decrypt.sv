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

// ----------------------------------------
// - Internal Parameters
// ----------------------------------------
localparam NBW_BYTE   = 'd8;
localparam NBW_EX_KEY = 'd1408;

// ----------------------------------------
// - Wires/Registers creation
// ----------------------------------------
logic [NBW_BYTE-1:0]   current_data_nx[4][4];
logic [NBW_BYTE-1:0]   current_data_ff[4][4];
logic [NBW_BYTE-1:0]   AddRoundKey[4][4];
logic [NBW_BYTE-1:0]   SubBytes[4][4];
logic [NBW_BYTE-1:0]   ShiftRows[4][4];
logic [NBW_BYTE-1:0]   xtimes02[4][4];
logic [NBW_BYTE-1:0]   xtimes04[4][4];
logic [NBW_BYTE-1:0]   xtimes08[4][4];
logic [NBW_BYTE-1:0]   xtimes09[4][4];
logic [NBW_BYTE-1:0]   xtimes0b[4][4];
logic [NBW_BYTE-1:0]   xtimes0d[4][4];
logic [NBW_BYTE-1:0]   xtimes0e[4][4];
logic [NBW_BYTE-1:0]   MixColumns[4][4];
logic                  key_done;
logic [3:0]            round_ff;
logic [NBW_EX_KEY-1:0] expanded_key;

function automatic [NBW_BYTE-1:0] xtime(input [NBW_BYTE-1:0] x);
    xtime = x[NBW_BYTE-1] ? ({x[NBW_BYTE-2:0], 1'b0} ^ 8'h1B) : {x[NBW_BYTE-2:0], 1'b0};
endfunction

// ----------------------------------------
// - Output assignment
// ----------------------------------------
assign o_done = (round_ff == 4'd0);

generate
    for(genvar i = 0; i < 4; i++) begin : out_row
        for(genvar j = 0; j < 4; j++) begin : out_col
            assign o_data[NBW_DATA-(4*j+i)*NBW_BYTE-1-:NBW_BYTE] = current_data_ff[i][j];
        end
    end
endgenerate

always_ff @(posedge clk or negedge rst_async_n) begin : inv_cypher_regs
    if(!rst_async_n) begin
        round_ff <= 4'd0;
        for(int i = 0; i < 4; i++) begin
            for(int j = 0; j < 4; j++) begin
                current_data_ff[i][j] <= 8'd0;
            end
        end
    end else begin
        if(i_start & o_done) begin
            round_ff <= 4'd1;
        end else if(round_ff >= 4'd1 && round_ff < 4'd11) begin
            round_ff <= round_ff + 1'b1;
        end else if(round_ff == 4'd11) begin
            round_ff <= 4'd0;
        end else begin
            round_ff <= 4'd0;
        end

        for(int i = 0; i < 4; i++) begin
            for(int j = 0; j < 4; j++) begin
                current_data_ff[i][j] <= current_data_nx[i][j];
            end
        end
    end
end

always_comb begin : next_data
    for(int i = 0; i < 4; i++) begin
        for(int j = 0; j < 4; j++) begin
            if(i_start & o_done) begin
                current_data_nx[i][j] = i_data[NBW_DATA-(i+4*j)*NBW_BYTE-1-:NBW_BYTE];
            end else begin
                if(round_ff == 4'd1) begin
                    current_data_nx[i][j] = AddRoundKey[i][j];
                end else if(round_ff >= 4'd2 && round_ff <= 4'd10) begin
                    current_data_nx[i][j] = MixColumns[i][j];
                end else if(round_ff == 4'd11) begin
                    current_data_nx[i][j] = AddRoundKey[i][j];
                end else begin
                    current_data_nx[i][j] = current_data_ff[i][j];
                end
            end
        end
    end
end

generate
    for(genvar i = 0; i < 4; i++) begin : row
        for(genvar j = 0; j < 4; j++) begin : col
            inv_sbox uu_inv_sbox0 (
                .i_data(ShiftRows[i][j]),
                .o_data(SubBytes[i][j])
            );
        end
    end
endgenerate

always_comb begin : decypher_logic
    // Shift Rows logic (inverse)
    // Line 0: No shift
    ShiftRows[0][0] = current_data_ff[0][0];
    ShiftRows[0][1] = current_data_ff[0][1];
    ShiftRows[0][2] = current_data_ff[0][2];
    ShiftRows[0][3] = current_data_ff[0][3];

    // Line 1: Shift 1 right
    ShiftRows[1][0] = current_data_ff[1][3];
    ShiftRows[1][1] = current_data_ff[1][0];
    ShiftRows[1][2] = current_data_ff[1][1];
    ShiftRows[1][3] = current_data_ff[1][2];

    // Line 2: Shift 2 right
    ShiftRows[2][0] = current_data_ff[2][2];
    ShiftRows[2][1] = current_data_ff[2][3];
    ShiftRows[2][2] = current_data_ff[2][0];
    ShiftRows[2][3] = current_data_ff[2][1];

    // Line 3: Shift 3 right
    ShiftRows[3][0] = current_data_ff[3][1];
    ShiftRows[3][1] = current_data_ff[3][2];
    ShiftRows[3][2] = current_data_ff[3][3];
    ShiftRows[3][3] = current_data_ff[3][0];

    // Add Round Key logic
    for(int i = 0; i < 4; i++) begin
        for(int j = 0; j < 4; j++) begin
            if(round_ff > 4'd0) begin
                if(round_ff == 4'd1) begin
                    AddRoundKey[i][j] = current_data_ff[i][j] ^ expanded_key[NBW_EX_KEY-(11-round_ff)*NBW_KEY-(i+4*j)*NBW_BYTE-1-:NBW_BYTE];
                end else begin
                    AddRoundKey[i][j] = SubBytes[i][j] ^ expanded_key[NBW_EX_KEY-(11-round_ff)*NBW_KEY-(i+4*j)*NBW_BYTE-1-:NBW_BYTE];
                end
            end else begin
                AddRoundKey[i][j] = '0;
            end
        end
    end

    // Mix Columns logic (inverse)
    for(int i = 0; i < 4; i++) begin
        for(int j = 0; j < 4; j++) begin
            xtimes02[i][j] = xtime(AddRoundKey[i][j]);
            xtimes04[i][j] = xtime(xtimes02[i][j]);
            xtimes08[i][j] = xtime(xtimes04[i][j]);

            xtimes0e[i][j] = xtimes08[i][j] ^ xtimes04[i][j] ^ xtimes02[i][j];
            xtimes0b[i][j] = xtimes08[i][j] ^ xtimes02[i][j] ^ AddRoundKey[i][j];
            xtimes0d[i][j] = xtimes08[i][j] ^ xtimes04[i][j] ^ AddRoundKey[i][j];
            xtimes09[i][j] = xtimes08[i][j] ^ AddRoundKey[i][j];
        end
    end

    for(int col = 0; col < 4; col++) begin
        MixColumns[0][col] = xtimes0e[0][col] ^ xtimes0b[1][col] ^ xtimes0d[2][col] ^ xtimes09[3][col];
        MixColumns[1][col] = xtimes09[0][col] ^ xtimes0e[1][col] ^ xtimes0b[2][col] ^ xtimes0d[3][col];
        MixColumns[2][col] = xtimes0d[0][col] ^ xtimes09[1][col] ^ xtimes0e[2][col] ^ xtimes0b[3][col];
        MixColumns[3][col] = xtimes0b[0][col] ^ xtimes0d[1][col] ^ xtimes09[2][col] ^ xtimes0e[3][col];
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
