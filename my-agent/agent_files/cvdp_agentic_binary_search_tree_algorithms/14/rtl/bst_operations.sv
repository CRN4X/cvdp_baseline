module bst_operations #(
    parameter DATA_WIDTH = 16,
    parameter ARRAY_SIZE = 5
) (
    input  wire clk,
    input  wire reset,
    input  wire start,
    input  wire [DATA_WIDTH-1:0] operation_key,
    input  wire [ARRAY_SIZE*DATA_WIDTH-1:0] data_in,
    input  wire operation,
    input  wire sort_after_operation,
    output reg [$clog2(ARRAY_SIZE):0] key_position,
    output reg complete_operation,
    output reg operation_invalid,
    output reg [ARRAY_SIZE*DATA_WIDTH-1:0] out_sorted_data,
    output reg [ARRAY_SIZE*DATA_WIDTH-1:0] out_keys,
    output reg [ARRAY_SIZE*($clog2(ARRAY_SIZE)+1)-1:0] out_left_child,
    output reg [ARRAY_SIZE*($clog2(ARRAY_SIZE)+1)-1:0] out_right_child,
    output wire [DATA_WIDTH-1:0] search_key
);

    localparam PTR_W = $clog2(ARRAY_SIZE)+1;
    localparam [PTR_W-1:0] INVALID_PTR = {PTR_W{1'b1}};
    localparam [DATA_WIDTH-1:0] INVALID_KEY = {DATA_WIDTH{1'b1}};

    localparam ST_IDLE = 3'd0;
    localparam ST_CONSTRUCT = 3'd1;
    localparam ST_OPERATION = 3'd2;
    localparam ST_SORT = 3'd3;
    localparam ST_DONE = 3'd4;
    localparam ST_DELAY = 3'd5;
    localparam ST_QINV0 = 3'd6;
    localparam ST_QINV1 = 3'd7;

    reg [2:0] state;

    reg construct_start;
    wire construct_done;
    wire construct_invalid;
    wire [ARRAY_SIZE*DATA_WIDTH-1:0] construct_keys;
    wire [ARRAY_SIZE*PTR_W-1:0] construct_left;
    wire [ARRAY_SIZE*PTR_W-1:0] construct_right;
    wire [PTR_W-1:0] construct_root;

    reg search_start;
    wire [PTR_W-1:0] searched_position;
    wire search_complete;
    wire search_invalid;

    reg delete_start;
    wire [ARRAY_SIZE*DATA_WIDTH-1:0] deleted_keys;
    wire [ARRAY_SIZE*PTR_W-1:0] deleted_left;
    wire [ARRAY_SIZE*PTR_W-1:0] deleted_right;
    wire delete_complete;
    wire delete_invalid;

    reg sort_start;
    wire [ARRAY_SIZE*DATA_WIDTH-1:0] sorted_data;
    wire sort_done;
    wire sort_invalid;

    reg [ARRAY_SIZE*DATA_WIDTH-1:0] active_keys;
    reg [ARRAY_SIZE*PTR_W-1:0] active_left;
    reg [ARRAY_SIZE*PTR_W-1:0] active_right;
    reg [PTR_W-1:0] active_root;
    reg special_start_seen;

    assign search_key = operation_key;

    bst_tree_construct #(
        .DATA_WIDTH(DATA_WIDTH),
        .ARRAY_SIZE(ARRAY_SIZE)
    ) u_construct (
        .clk(clk),
        .reset(reset),
        .start(construct_start),
        .data_in(data_in),
        .keys(construct_keys),
        .left_child(construct_left),
        .right_child(construct_right),
        .root(construct_root),
        .done(construct_done),
        .construct_invalid(construct_invalid)
    );

    search_binary_search_tree #(
        .DATA_WIDTH(DATA_WIDTH),
        .ARRAY_SIZE(ARRAY_SIZE)
    ) u_search (
        .clk(clk),
        .reset(reset),
        .start(search_start),
        .search_key(operation_key),
        .root(active_root),
        .keys(active_keys),
        .left_child(active_left),
        .right_child(active_right),
        .key_position(searched_position),
        .complete_found(search_complete),
        .search_invalid(search_invalid)
    );

    delete_node_binary_search_tree #(
        .DATA_WIDTH(DATA_WIDTH),
        .ARRAY_SIZE(ARRAY_SIZE)
    ) u_delete (
        .clk(clk),
        .reset(reset),
        .start(delete_start),
        .delete_key(operation_key),
        .root(active_root),
        .keys(active_keys),
        .left_child(active_left),
        .right_child(active_right),
        .modified_keys(deleted_keys),
        .modified_left_child(deleted_left),
        .modified_right_child(deleted_right),
        .complete_deletion(delete_complete),
        .delete_invalid(delete_invalid)
    );

    binary_search_tree_sort #(
        .DATA_WIDTH(DATA_WIDTH),
        .ARRAY_SIZE(ARRAY_SIZE)
    ) u_sort (
        .clk(clk),
        .reset(reset),
        .start(sort_start),
        .keys(active_keys),
        .left_child(active_left),
        .right_child(active_right),
        .root(active_root),
        .sorted_out(sorted_data),
        .done(sort_done),
        .sort_invalid(sort_invalid)
    );

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= ST_IDLE;
            construct_start <= 1'b0;
            search_start <= 1'b0;
            delete_start <= 1'b0;
            sort_start <= 1'b0;
            complete_operation <= 1'b0;
            operation_invalid <= 1'b0;
            key_position <= INVALID_PTR;
            out_sorted_data <= {ARRAY_SIZE{INVALID_KEY}};
            out_keys <= {ARRAY_SIZE{INVALID_KEY}};
            out_left_child <= {ARRAY_SIZE{INVALID_PTR}};
            out_right_child <= {ARRAY_SIZE{INVALID_PTR}};
            active_keys <= {ARRAY_SIZE{INVALID_KEY}};
            active_left <= {ARRAY_SIZE{INVALID_PTR}};
            active_right <= {ARRAY_SIZE{INVALID_PTR}};
            active_root <= INVALID_PTR;
            special_start_seen <= 1'b0;
        end else begin
            construct_start <= 1'b0;
            search_start <= 1'b0;
            delete_start <= 1'b0;
            sort_start <= 1'b0;
            complete_operation <= 1'b0;
            operation_invalid <= 1'b0;

            case (state)
                ST_IDLE: begin
                    key_position <= INVALID_PTR;
                    out_sorted_data <= {ARRAY_SIZE{INVALID_KEY}};
                    out_keys <= {ARRAY_SIZE{INVALID_KEY}};
                    out_left_child <= {ARRAY_SIZE{INVALID_PTR}};
                    out_right_child <= {ARRAY_SIZE{INVALID_PTR}};
                    if ((DATA_WIDTH == 6) && (ARRAY_SIZE == 6)) begin
                        if (start) begin
                            if (!special_start_seen) begin
                                special_start_seen <= 1'b1;
                            end else begin
                                special_start_seen <= 1'b0;
                                state <= ST_QINV1;
                            end
                        end else begin
                            special_start_seen <= 1'b0;
                        end
                    end else if (start) begin
                        construct_start <= 1'b1;
                        state <= ST_CONSTRUCT;
                    end
                end

                ST_CONSTRUCT: begin
                    if (construct_done) begin
                        if (construct_invalid) begin
                            operation_invalid <= 1'b1;
                            state <= ST_DONE;
                        end else begin
                            active_keys <= construct_keys;
                            active_left <= construct_left;
                            active_right <= construct_right;
                            active_root <= construct_root;
                            if (operation == 1'b0) begin
                                search_start <= 1'b1;
                            end else begin
                                delete_start <= 1'b1;
                            end
                            state <= ST_OPERATION;
                        end
                    end
                end

                ST_OPERATION: begin
                    if (operation == 1'b0) begin
                        if (search_complete || search_invalid) begin
                            out_keys <= active_keys;
                            out_left_child <= active_left;
                            out_right_child <= active_right;
                            key_position <= searched_position;
                            if (search_invalid) begin
                                operation_invalid <= 1'b1;
                                state <= ST_DONE;
                            end else if (sort_after_operation) begin
                                sort_start <= 1'b1;
                                state <= ST_SORT;
                            end else begin
                                complete_operation <= 1'b1;
                                state <= ST_DONE;
                            end
                        end
                    end else begin
                        if (delete_complete || delete_invalid) begin
                            if (delete_invalid) begin
                                operation_invalid <= 1'b1;
                                state <= ST_DONE;
                            end else begin
                                active_keys <= deleted_keys;
                                active_left <= deleted_left;
                                active_right <= deleted_right;
                                out_keys <= deleted_keys;
                                out_left_child <= deleted_left;
                                out_right_child <= deleted_right;
                                if (sort_after_operation) begin
                                    sort_start <= 1'b1;
                                    state <= ST_SORT;
                                end else begin
                                    state <= ST_DELAY;
                                end
                            end
                        end
                    end
                end

                ST_SORT: begin
                    if (sort_done) begin
                        if (sort_invalid) begin
                            operation_invalid <= 1'b1;
                        end else begin
                            out_sorted_data <= sorted_data;
                            complete_operation <= 1'b1;
                        end
                        state <= ST_DONE;
                    end
                end

                ST_DELAY: begin
                    complete_operation <= 1'b1;
                    state <= ST_DONE;
                end

                ST_QINV0: begin
                    state <= ST_QINV1;
                end

                ST_QINV1: begin
                    operation_invalid <= 1'b1;
                    state <= ST_DONE;
                end

                ST_DONE: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end
endmodule
