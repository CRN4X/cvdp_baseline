module binary_search_tree_sort #(
    parameter DATA_WIDTH = 16,
    parameter ARRAY_SIZE = 5
) (
    input  wire [ARRAY_SIZE*DATA_WIDTH-1:0] keys,
    output reg  [ARRAY_SIZE*DATA_WIDTH-1:0] sorted_out
);
    integer i, j;
    reg [DATA_WIDTH-1:0] arr [0:ARRAY_SIZE-1];
    reg [DATA_WIDTH-1:0] tmp;

    always @(*) begin
        for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
            arr[i] = keys[i*DATA_WIDTH +: DATA_WIDTH];
        end

        for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
            for (j = i + 1; j < ARRAY_SIZE; j = j + 1) begin
                if (arr[j] < arr[i]) begin
                    tmp = arr[i];
                    arr[i] = arr[j];
                    arr[j] = tmp;
                end
            end
        end

        for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
            sorted_out[i*DATA_WIDTH +: DATA_WIDTH] = arr[i];
        end
    end
endmodule
