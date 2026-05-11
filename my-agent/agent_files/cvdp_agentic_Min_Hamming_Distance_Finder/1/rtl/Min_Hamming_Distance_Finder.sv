module Min_Hamming_Distance_Finder
#(
    parameter BIT_WIDTH       = 8,
    parameter REFERENCE_COUNT = 4
)
(
    input  wire [BIT_WIDTH-1:0]                 input_query,
    input  wire [REFERENCE_COUNT*BIT_WIDTH-1:0] references,
    output reg  [$clog2(REFERENCE_COUNT)-1:0]   best_match_index,
    output reg  [$clog2(BIT_WIDTH+1)-1:0]       min_distance
);

    localparam DIST_WIDTH = $clog2(BIT_WIDTH + 1);

    wire [REFERENCE_COUNT*DIST_WIDTH-1:0] all_distances;

    genvar ref_idx;
    generate
        for (ref_idx = 0; ref_idx < REFERENCE_COUNT; ref_idx = ref_idx + 1) begin : distance_calc
            Bit_Difference_Counter #(
                .BIT_WIDTH(BIT_WIDTH)
            ) bit_difference_counter_i (
                .input_A(input_query),
                .input_B(references[ref_idx*BIT_WIDTH +: BIT_WIDTH]),
                .bit_difference_count(all_distances[ref_idx*DIST_WIDTH +: DIST_WIDTH])
            );
        end
    endgenerate

    integer i;
    always @(*) begin
        best_match_index = 0;
        min_distance = all_distances[0 +: DIST_WIDTH];

        for (i = 1; i < REFERENCE_COUNT; i = i + 1) begin
            if (all_distances[i*DIST_WIDTH +: DIST_WIDTH] < min_distance) begin
                min_distance = all_distances[i*DIST_WIDTH +: DIST_WIDTH];
                best_match_index = i[$clog2(REFERENCE_COUNT)-1:0];
            end
        end
    end

endmodule
