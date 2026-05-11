module custom_byte_enable_ram #(
    parameter int XLEN  = 32,
    parameter int LINES = 8192,
    parameter int ADDR_WIDTH = $clog2(LINES)
) (
    input  logic                  clk,
    input  logic [ADDR_WIDTH-1:0] addr_a,
    input  logic                  en_a,
    input  logic [(XLEN/8)-1:0]   be_a,
    input  logic [XLEN-1:0]       data_in_a,
    output logic [XLEN-1:0]       data_out_a,
    input  logic [ADDR_WIDTH-1:0] addr_b,
    input  logic                  en_b,
    input  logic [(XLEN/8)-1:0]   be_b,
    input  logic [XLEN-1:0]       data_in_b,
    output logic [XLEN-1:0]       data_out_b
);

    localparam int BYTES = XLEN / 8;

    logic [XLEN-1:0] ram [0:LINES-1];
    logic [XLEN-1:0] wr_word;
    integer i;

    initial begin
        for (i = 0; i < LINES; i = i + 1) begin
            ram[i] = '0;
        end
    end

    always_ff @(posedge clk) begin
        if (en_a && en_b && (addr_a == addr_b)) begin
            wr_word = ram[addr_a];
            for (i = 0; i < BYTES; i = i + 1) begin
                if (be_a[i]) begin
                    wr_word[i*8 +: 8] = data_in_a[i*8 +: 8];
                end else if (be_b[i]) begin
                    wr_word[i*8 +: 8] = data_in_b[i*8 +: 8];
                end
            end
            ram[addr_a] <= wr_word;
        end else begin
            if (en_a) begin
                wr_word = ram[addr_a];
                for (i = 0; i < BYTES; i = i + 1) begin
                    if (be_a[i]) begin
                        wr_word[i*8 +: 8] = data_in_a[i*8 +: 8];
                    end
                end
                ram[addr_a] <= wr_word;
            end

            if (en_b) begin
                wr_word = ram[addr_b];
                for (i = 0; i < BYTES; i = i + 1) begin
                    if (be_b[i]) begin
                        wr_word[i*8 +: 8] = data_in_b[i*8 +: 8];
                    end
                end
                ram[addr_b] <= wr_word;
            end
        end
    end

    always_comb begin
        data_out_a = ram[addr_a];
        data_out_b = ram[addr_b];
    end

endmodule
