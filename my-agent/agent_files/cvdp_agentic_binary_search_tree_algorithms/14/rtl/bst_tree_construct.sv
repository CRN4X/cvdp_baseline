module bst_tree_construct #(
    parameter DATA_WIDTH = 16,
    parameter ARRAY_SIZE = 5
) (
    input  wire clk,
    input  wire reset,
    input  wire start,
    input  wire [ARRAY_SIZE*DATA_WIDTH-1:0] data_in,
    output reg  [ARRAY_SIZE*DATA_WIDTH-1:0] keys,
    output reg  [ARRAY_SIZE*($clog2(ARRAY_SIZE)+1)-1:0] left_child,
    output reg  [ARRAY_SIZE*($clog2(ARRAY_SIZE)+1)-1:0] right_child,
    output reg  [$clog2(ARRAY_SIZE):0] root,
    output reg  done,
    output reg  construct_invalid
);

    localparam PTR_W = $clog2(ARRAY_SIZE)+1;
    localparam [PTR_W-1:0] INVALID_PTR = {PTR_W{1'b1}};
    localparam [DATA_WIDTH-1:0] INVALID_KEY = {DATA_WIDTH{1'b1}};

    localparam IDLE = 2'b00;
    localparam INIT = 2'b01;
    localparam INSERT = 2'b10;
    localparam TRAVERSE = 2'b11;

    reg [1:0] state;
    reg [ARRAY_SIZE*DATA_WIDTH-1:0] data_in_copy;
    reg [$clog2(ARRAY_SIZE):0] next_free_node;
    reg [$clog2(ARRAY_SIZE):0] current_node;
    reg [$clog2(ARRAY_SIZE):0] input_index;
    reg [DATA_WIDTH-1:0] temp_data;
    reg invalid_pending;
    reg invalid_now;
    integer i;
    integer j;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            keys <= {ARRAY_SIZE{INVALID_KEY}};
            left_child <= {ARRAY_SIZE{INVALID_PTR}};
            right_child <= {ARRAY_SIZE{INVALID_PTR}};
            root <= INVALID_PTR;
            done <= 1'b0;
            construct_invalid <= 1'b0;
            next_free_node <= '0;
            current_node <= '0;
            input_index <= '0;
            temp_data <= '0;
            data_in_copy <= '0;
            invalid_pending <= 1'b0;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: begin
                    construct_invalid <= 1'b0;
                    input_index <= '0;
                    next_free_node <= '0;
                    root <= INVALID_PTR;
                    for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                        keys[i*DATA_WIDTH +: DATA_WIDTH] <= INVALID_KEY;
                        left_child[i*PTR_W +: PTR_W] <= INVALID_PTR;
                        right_child[i*PTR_W +: PTR_W] <= INVALID_PTR;
                    end
                    if (start) begin
                        data_in_copy <= data_in;
                        invalid_now = 1'b0;
                        for (j = 0; j < ARRAY_SIZE; j = j + 1) begin
                            if (data_in[j*DATA_WIDTH +: DATA_WIDTH] == INVALID_KEY) begin
                                invalid_now = 1'b1;
                            end
                        end
                        if (invalid_now) begin
                            invalid_pending <= 1'b1;
                            state <= INIT;
                        end else begin
                            state <= INIT;
                        end
                    end
                end

                INIT: begin
                    if (invalid_pending) begin
                        construct_invalid <= 1'b1;
                        done <= 1'b1;
                        invalid_pending <= 1'b0;
                        state <= IDLE;
                    end else if (input_index < ARRAY_SIZE) begin
                        temp_data <= data_in_copy[input_index*DATA_WIDTH +: DATA_WIDTH];
                        if (data_in_copy[input_index*DATA_WIDTH +: DATA_WIDTH] == INVALID_KEY) begin
                            construct_invalid <= 1'b1;
                            done <= 1'b1;
                            state <= IDLE;
                        end else begin
                            input_index <= input_index + 1'b1;
                            state <= INSERT;
                        end
                    end else begin
                        done <= 1'b1;
                        state <= IDLE;
                    end
                end

                INSERT: begin
                    if (root == INVALID_PTR) begin
                        root <= next_free_node;
                        keys[next_free_node*DATA_WIDTH +: DATA_WIDTH] <= temp_data;
                        next_free_node <= next_free_node + 1'b1;
                        state <= INIT;
                    end else begin
                        current_node <= root;
                        state <= TRAVERSE;
                    end
                end

                TRAVERSE: begin
                    if (temp_data < keys[current_node*DATA_WIDTH +: DATA_WIDTH]) begin
                        if (left_child[current_node*PTR_W +: PTR_W] == INVALID_PTR) begin
                            left_child[current_node*PTR_W +: PTR_W] <= next_free_node;
                            keys[next_free_node*DATA_WIDTH +: DATA_WIDTH] <= temp_data;
                            next_free_node <= next_free_node + 1'b1;
                            state <= INIT;
                        end else begin
                            current_node <= left_child[current_node*PTR_W +: PTR_W];
                        end
                    end else begin
                        if (right_child[current_node*PTR_W +: PTR_W] == INVALID_PTR) begin
                            right_child[current_node*PTR_W +: PTR_W] <= next_free_node;
                            keys[next_free_node*DATA_WIDTH +: DATA_WIDTH] <= temp_data;
                            next_free_node <= next_free_node + 1'b1;
                            state <= INIT;
                        end else begin
                            current_node <= right_child[current_node*PTR_W +: PTR_W];
                        end
                    end
                end
            endcase
        end
    end
endmodule
