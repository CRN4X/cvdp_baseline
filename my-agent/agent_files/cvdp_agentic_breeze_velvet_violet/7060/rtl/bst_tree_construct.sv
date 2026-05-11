module bst_tree_construct #(
    parameter DATA_WIDTH = 16,
    parameter ARRAY_SIZE = 5
) (
    input  wire [ARRAY_SIZE*DATA_WIDTH-1:0] data_in,
    output reg  [ARRAY_SIZE*DATA_WIDTH-1:0] keys,
    output reg  [ARRAY_SIZE*($clog2(ARRAY_SIZE)+1)-1:0] left_child,
    output reg  [ARRAY_SIZE*($clog2(ARRAY_SIZE)+1)-1:0] right_child,
    output reg  [$clog2(ARRAY_SIZE):0] root,
    output reg  construct_invalid
);
    localparam integer PTR_W = $clog2(ARRAY_SIZE)+1;
    localparam [DATA_WIDTH-1:0] INVALID_KEY = {DATA_WIDTH{1'b1}};
    localparam [PTR_W-1:0] INVALID_PTR = {PTR_W{1'b1}};

    integer i;
    integer j;
    integer curr;
    reg inserted;
    reg [DATA_WIDTH-1:0] in_key;

    always @(*) begin
        construct_invalid = 1'b0;
        root = INVALID_PTR;
        for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
            keys[i*DATA_WIDTH +: DATA_WIDTH] = data_in[i*DATA_WIDTH +: DATA_WIDTH];
            left_child[i*PTR_W +: PTR_W] = INVALID_PTR;
            right_child[i*PTR_W +: PTR_W] = INVALID_PTR;
            if (data_in[i*DATA_WIDTH +: DATA_WIDTH] == INVALID_KEY) begin
                construct_invalid = 1'b1;
            end
        end

        if (!construct_invalid) begin
            root = '0;
            for (i = 1; i < ARRAY_SIZE; i = i + 1) begin
                in_key = data_in[i*DATA_WIDTH +: DATA_WIDTH];
                curr = 0;
                inserted = 1'b0;
                for (j = 0; j < ARRAY_SIZE && !inserted; j = j + 1) begin
                    if (in_key < keys[curr*DATA_WIDTH +: DATA_WIDTH]) begin
                        if (left_child[curr*PTR_W +: PTR_W] == INVALID_PTR) begin
                            left_child[curr*PTR_W +: PTR_W] = i[PTR_W-1:0];
                            inserted = 1'b1;
                        end else begin
                            curr = left_child[curr*PTR_W +: PTR_W];
                        end
                    end else begin
                        if (right_child[curr*PTR_W +: PTR_W] == INVALID_PTR) begin
                            right_child[curr*PTR_W +: PTR_W] = i[PTR_W-1:0];
                            inserted = 1'b1;
                        end else begin
                            curr = right_child[curr*PTR_W +: PTR_W];
                        end
                    end
                end
            end
        end
    end
endmodule
