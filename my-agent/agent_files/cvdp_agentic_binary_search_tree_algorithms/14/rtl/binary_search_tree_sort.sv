module binary_search_tree_sort #(
    parameter DATA_WIDTH = 16,
    parameter ARRAY_SIZE = 5
) (
    input  wire clk,
    input  wire reset,
    input  wire start,
    input  wire [ARRAY_SIZE*DATA_WIDTH-1:0] keys,
    input  wire [ARRAY_SIZE*($clog2(ARRAY_SIZE)+1)-1:0] left_child,
    input  wire [ARRAY_SIZE*($clog2(ARRAY_SIZE)+1)-1:0] right_child,
    input  wire [$clog2(ARRAY_SIZE):0] root,
    output reg  [ARRAY_SIZE*DATA_WIDTH-1:0] sorted_out,
    output reg  done,
    output reg  sort_invalid
);

    localparam PTR_W = $clog2(ARRAY_SIZE)+1;
    localparam [PTR_W-1:0] INVALID_PTR = {PTR_W{1'b1}};
    localparam [DATA_WIDTH-1:0] INVALID_KEY = {DATA_WIDTH{1'b1}};

    localparam S_IDLE = 2'b00;
    localparam S_TRAVERSE_LEFT = 2'b01;
    localparam S_PROCESS_NODE = 2'b10;
    localparam S_TRAVERSE_RIGHT = 2'b11;

    reg [1:0] state;
    reg [ARRAY_SIZE*PTR_W-1:0] stack;
    reg [$clog2(ARRAY_SIZE):0] sp;
    reg [$clog2(ARRAY_SIZE):0] current_node;
    reg [$clog2(ARRAY_SIZE):0] output_index;
    integer i;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= S_IDLE;
            done <= 1'b0;
            sort_invalid <= 1'b0;
            sorted_out <= {ARRAY_SIZE{INVALID_KEY}};
            stack <= {ARRAY_SIZE{INVALID_PTR}};
            sp <= '0;
            current_node <= INVALID_PTR;
            output_index <= '0;
        end else begin
            done <= 1'b0;
            case (state)
                S_IDLE: begin
                    sort_invalid <= 1'b0;
                    output_index <= '0;
                    sp <= '0;
                    sorted_out <= {ARRAY_SIZE{INVALID_KEY}};
                    for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                        stack[i*PTR_W +: PTR_W] <= INVALID_PTR;
                    end
                    if (start) begin
                        if (root == INVALID_PTR) begin
                            sort_invalid <= 1'b1;
                            done <= 1'b1;
                        end else begin
                            current_node <= root;
                            state <= S_TRAVERSE_LEFT;
                        end
                    end
                end

                S_TRAVERSE_LEFT: begin
                    if (current_node != INVALID_PTR) begin
                        stack[sp*PTR_W +: PTR_W] <= current_node;
                        sp <= sp + 1'b1;
                        current_node <= left_child[current_node*PTR_W +: PTR_W];
                    end else begin
                        state <= S_PROCESS_NODE;
                    end
                end

                S_PROCESS_NODE: begin
                    if (sp > 0) begin
                        sp <= sp - 1'b1;
                        current_node <= stack[(sp-1'b1)*PTR_W +: PTR_W];
                        sorted_out[output_index*DATA_WIDTH +: DATA_WIDTH] <= keys[stack[(sp-1'b1)*PTR_W +: PTR_W]*DATA_WIDTH +: DATA_WIDTH];
                        output_index <= output_index + 1'b1;
                        state <= S_TRAVERSE_RIGHT;
                    end else begin
                        done <= 1'b1;
                        state <= S_IDLE;
                    end
                end

                S_TRAVERSE_RIGHT: begin
                    current_node <= right_child[current_node*PTR_W +: PTR_W];
                    state <= S_TRAVERSE_LEFT;
                end
            endcase
        end
    end
endmodule
