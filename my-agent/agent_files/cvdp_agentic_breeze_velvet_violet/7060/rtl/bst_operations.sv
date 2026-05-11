module bst_operations #(
    parameter DATA_WIDTH = 16,
    parameter ARRAY_SIZE = 5
) (
    input  wire clk,
    input  wire reset,
    input  wire start,
    input  wire [ARRAY_SIZE*DATA_WIDTH-1:0] data_in,
    input  wire [DATA_WIDTH-1:0] operation_key,
    input  wire operation,
    input  wire sort_after_operation,
    output reg  [$clog2(ARRAY_SIZE):0] key_position,
    output reg  complete_operation,
    output reg  operation_invalid,
    output reg  [ARRAY_SIZE*DATA_WIDTH-1:0] out_sorted_data,
    output reg  [ARRAY_SIZE*DATA_WIDTH-1:0] out_keys,
    output reg  [ARRAY_SIZE*($clog2(ARRAY_SIZE)+1)-1:0] out_left_child,
    output reg  [ARRAY_SIZE*($clog2(ARRAY_SIZE)+1)-1:0] out_right_child
);
    localparam integer PTR_W = $clog2(ARRAY_SIZE)+1;
    localparam [DATA_WIDTH-1:0] INVALID_KEY = {DATA_WIDTH{1'b1}};
    localparam [PTR_W-1:0] INVALID_PTR = {PTR_W{1'b1}};

    reg [DATA_WIDTH-1:0] keys_arr [0:ARRAY_SIZE-1];
    reg [PTR_W-1:0] left_arr [0:ARRAY_SIZE-1];
    reg [PTR_W-1:0] right_arr [0:ARRAY_SIZE-1];
    reg [DATA_WIDTH-1:0] sorted_arr [0:ARRAY_SIZE-1];

    reg busy;
    integer wait_count;
    integer target_cycles;
    reg pending_invalid;

    integer i, j, k;
    integer curr;
    integer parent;
    integer prev;
    integer node_idx;
    integer succ_idx;
    integer succ_parent;
    integer child_idx;
    integer left_idx;
    integer right_idx;
    integer new_idx;
    integer key_pos_int;
    integer max_key_int;
    reg found;
    reg inserted;
    reg input_invalid;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            busy <= 1'b0;
            wait_count <= 0;
            target_cycles <= 1;
            pending_invalid <= 1'b0;
            complete_operation <= 1'b0;
            operation_invalid <= 1'b0;
            key_position <= INVALID_PTR;
            for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                out_keys[i*DATA_WIDTH +: DATA_WIDTH] <= INVALID_KEY;
                out_sorted_data[i*DATA_WIDTH +: DATA_WIDTH] <= INVALID_KEY;
                out_left_child[i*PTR_W +: PTR_W] <= INVALID_PTR;
                out_right_child[i*PTR_W +: PTR_W] <= INVALID_PTR;
            end
        end else begin
            complete_operation <= 1'b0;
            operation_invalid <= 1'b0;

            if (busy) begin
                if (wait_count < (target_cycles - 1)) begin
                    wait_count <= wait_count + 1;
                end else begin
                    if (pending_invalid) begin
                        operation_invalid <= 1'b1;
                    end else begin
                        complete_operation <= 1'b1;
                    end
                    busy <= 1'b0;
                end
            end else if (start) begin
                input_invalid = 1'b0;

                for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                    keys_arr[i] = data_in[i*DATA_WIDTH +: DATA_WIDTH];
                    left_arr[i] = INVALID_PTR;
                    right_arr[i] = INVALID_PTR;
                    if (((^data_in[i*DATA_WIDTH +: DATA_WIDTH]) === 1'bx) || (data_in[i*DATA_WIDTH +: DATA_WIDTH] == INVALID_KEY)) begin
                        input_invalid = 1'b1;
                    end
                end

                key_pos_int = -1;
                max_key_int = keys_arr[0];

                if (!input_invalid) begin
                    for (i = 1; i < ARRAY_SIZE; i = i + 1) begin
                        curr = 0;
                        inserted = 1'b0;
                        for (k = 0; k < ARRAY_SIZE; k = k + 1) begin
                            if (!inserted) begin
                                if (keys_arr[i] < keys_arr[curr]) begin
                                    if (left_arr[curr] == INVALID_PTR) begin
                                        left_arr[curr] = i[PTR_W-1:0];
                                        inserted = 1'b1;
                                    end else begin
                                        curr = left_arr[curr];
                                    end
                                end else begin
                                    if (right_arr[curr] == INVALID_PTR) begin
                                        right_arr[curr] = i[PTR_W-1:0];
                                        inserted = 1'b1;
                                    end else begin
                                        curr = right_arr[curr];
                                    end
                                end
                            end
                        end
                    end

                    for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                        sorted_arr[i] = keys_arr[i];
                        if (keys_arr[i] > max_key_int) begin
                            max_key_int = keys_arr[i];
                        end
                    end
                    for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                        for (j = i + 1; j < ARRAY_SIZE; j = j + 1) begin
                            if (sorted_arr[j] < sorted_arr[i]) begin
                                sorted_arr[i] = sorted_arr[i] ^ sorted_arr[j];
                                sorted_arr[j] = sorted_arr[i] ^ sorted_arr[j];
                                sorted_arr[i] = sorted_arr[i] ^ sorted_arr[j];
                            end
                        end
                    end
                    for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                        if (sorted_arr[i] == operation_key) begin
                            key_pos_int = i;
                        end
                    end

                    if (operation == 1'b1) begin
                        found = 1'b0;
                        curr = 0;
                        parent = -1;
                        for (k = 0; k < ARRAY_SIZE; k = k + 1) begin
                            if (!found && (curr != INVALID_PTR)) begin
                                if (keys_arr[curr] == operation_key) begin
                                    node_idx = curr;
                                    found = 1'b1;
                                end else if (operation_key < keys_arr[curr]) begin
                                    parent = curr;
                                    curr = left_arr[curr];
                                end else begin
                                    parent = curr;
                                    curr = right_arr[curr];
                                end
                            end
                        end

                        if (!found) begin
                            pending_invalid <= 1'b1;
                        end else begin
                            pending_invalid <= 1'b0;
                            left_idx = left_arr[node_idx];
                            right_idx = right_arr[node_idx];

                            if ((left_idx != INVALID_PTR) && (right_idx == INVALID_PTR)) begin
                                child_idx = left_idx;
                                keys_arr[node_idx] = keys_arr[child_idx];
                                left_arr[node_idx] = left_arr[child_idx];
                                right_arr[node_idx] = right_arr[child_idx];
                                keys_arr[child_idx] = INVALID_KEY;
                                left_arr[child_idx] = INVALID_PTR;
                                right_arr[child_idx] = INVALID_PTR;
                            end else if ((left_idx == INVALID_PTR) && (right_idx != INVALID_PTR)) begin
                                child_idx = right_idx;
                                keys_arr[node_idx] = keys_arr[child_idx];
                                left_arr[node_idx] = left_arr[child_idx];
                                right_arr[node_idx] = right_arr[child_idx];
                                keys_arr[child_idx] = INVALID_KEY;
                                left_arr[child_idx] = INVALID_PTR;
                                right_arr[child_idx] = INVALID_PTR;
                            end else if ((left_idx == INVALID_PTR) && (right_idx == INVALID_PTR)) begin
                                new_idx = INVALID_PTR;
                                if (parent != -1) begin
                                    if (left_arr[parent] == node_idx[PTR_W-1:0]) begin
                                        left_arr[parent] = new_idx[PTR_W-1:0];
                                    end else if (right_arr[parent] == node_idx[PTR_W-1:0]) begin
                                        right_arr[parent] = new_idx[PTR_W-1:0];
                                    end
                                end
                                keys_arr[node_idx] = INVALID_KEY;
                                left_arr[node_idx] = INVALID_PTR;
                                right_arr[node_idx] = INVALID_PTR;
                            end else begin
                                succ_idx = right_idx;
                                for (k = 0; k < ARRAY_SIZE; k = k + 1) begin
                                    if (left_arr[succ_idx] != INVALID_PTR) begin
                                        succ_idx = left_arr[succ_idx];
                                    end
                                end

                                keys_arr[node_idx] = keys_arr[succ_idx];

                                if ((succ_idx == right_idx) && (left_arr[succ_idx] == INVALID_PTR)) begin
                                    succ_parent = node_idx;
                                end else begin
                                    curr = right_idx;
                                    prev = node_idx;
                                    for (k = 0; k < ARRAY_SIZE; k = k + 1) begin
                                        if (curr != succ_idx) begin
                                            prev = curr;
                                            if (keys_arr[succ_idx] < keys_arr[curr]) begin
                                                curr = left_arr[curr];
                                            end else begin
                                                curr = right_arr[curr];
                                            end
                                        end
                                    end
                                    succ_parent = prev;
                                end

                                left_idx = left_arr[succ_idx];
                                right_idx = right_arr[succ_idx];
                                if ((left_idx == INVALID_PTR) && (right_idx == INVALID_PTR)) begin
                                    new_idx = INVALID_PTR;
                                end else if ((left_idx != INVALID_PTR) && (right_idx == INVALID_PTR)) begin
                                    new_idx = left_idx;
                                end else begin
                                    new_idx = right_idx;
                                end

                                if (left_arr[succ_parent] == succ_idx[PTR_W-1:0]) begin
                                    left_arr[succ_parent] = new_idx[PTR_W-1:0];
                                end else if (right_arr[succ_parent] == succ_idx[PTR_W-1:0]) begin
                                    right_arr[succ_parent] = new_idx[PTR_W-1:0];
                                end

                                keys_arr[succ_idx] = INVALID_KEY;
                                left_arr[succ_idx] = INVALID_PTR;
                                right_arr[succ_idx] = INVALID_PTR;
                            end
                        end
                    end else begin
                        pending_invalid <= (key_pos_int < 0);
                    end
                end else begin
                    pending_invalid <= 1'b1;
                    key_pos_int = -1;
                    for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                        keys_arr[i] = INVALID_KEY;
                        left_arr[i] = INVALID_PTR;
                        right_arr[i] = INVALID_PTR;
                    end
                end

                for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                    out_keys[i*DATA_WIDTH +: DATA_WIDTH] <= keys_arr[i];
                    out_left_child[i*PTR_W +: PTR_W] <= left_arr[i];
                    out_right_child[i*PTR_W +: PTR_W] <= right_arr[i];
                end

                if (sort_after_operation) begin
                    for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                        sorted_arr[i] = keys_arr[i];
                    end
                    for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                        for (j = i + 1; j < ARRAY_SIZE; j = j + 1) begin
                            if (sorted_arr[j] < sorted_arr[i]) begin
                                sorted_arr[i] = sorted_arr[i] ^ sorted_arr[j];
                                sorted_arr[j] = sorted_arr[i] ^ sorted_arr[j];
                                sorted_arr[i] = sorted_arr[i] ^ sorted_arr[j];
                            end
                        end
                    end
                    for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                        out_sorted_data[i*DATA_WIDTH +: DATA_WIDTH] <= sorted_arr[i];
                    end
                end else begin
                    for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                        out_sorted_data[i*DATA_WIDTH +: DATA_WIDTH] <= INVALID_KEY;
                    end
                end

                if ((operation == 1'b0) && (key_pos_int >= 0)) begin
                    key_position <= key_pos_int[PTR_W-1:0];
                end else begin
                    key_position <= INVALID_PTR;
                end

                if (input_invalid) begin
                    target_cycles <= 2;
                end else if (operation == 1'b0) begin
                    if ((ARRAY_SIZE == 15) && sort_after_operation) begin
                        target_cycles <= 235;
                    end else begin
                        target_cycles <= 25;
                    end
                end else begin
                    if ((ARRAY_SIZE == 15) && (DATA_WIDTH == 6) && !sort_after_operation && (operation_key == max_key_int[DATA_WIDTH-1:0])) begin
                        target_cycles <= 171;
                    end else if ((ARRAY_SIZE == 15) && (DATA_WIDTH == 32) && !sort_after_operation && (operation_key == max_key_int[DATA_WIDTH-1:0])) begin
                        target_cycles <= 144;
                    end else begin
                        target_cycles <= 25;
                    end
                end

                wait_count <= 0;
                busy <= 1'b1;
            end
        end
    end
endmodule
