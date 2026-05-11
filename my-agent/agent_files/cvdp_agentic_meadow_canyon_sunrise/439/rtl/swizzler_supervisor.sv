`timescale 1ns/1ps

module swizzler_supervisor #(
  parameter integer NUM_LANES           = 4,
  parameter integer DATA_WIDTH          = 8,
  parameter integer REGISTER_OUTPUT     = 1,
  parameter integer ENABLE_PARITY_CHECK = 1,
  parameter integer OP_MODE_WIDTH       = 2,
  parameter integer SWIZZLE_MAP_WIDTH   = $clog2(NUM_LANES)+1,
  parameter [DATA_WIDTH-1:0] EXPECTED_CHECKSUM = 8'hA5
)(
  input  wire                              clk,
  input  wire                              rst_n,
  input  wire                              bypass,
  input  wire [NUM_LANES*DATA_WIDTH-1:0]   data_in,
  input  wire [NUM_LANES*SWIZZLE_MAP_WIDTH-1:0] swizzle_map_flat,
  input  wire [OP_MODE_WIDTH-1:0]          operation_mode,
  output reg  [NUM_LANES*DATA_WIDTH-1:0]   final_data_out,
  output reg                               top_error
);

  wire [NUM_LANES*DATA_WIDTH-1:0] swizzler_data;
  wire                            parity_error;
  wire                            invalid_mapping_error;

  // Input conditioning hook. Kept as pass-through for this configuration.
  wire [NUM_LANES*DATA_WIDTH-1:0] conditioned_data_in;
  assign conditioned_data_in = data_in;

  swizzler #(
    .NUM_LANES(NUM_LANES),
    .DATA_WIDTH(DATA_WIDTH),
    .REGISTER_OUTPUT(REGISTER_OUTPUT),
    .ENABLE_PARITY_CHECK(ENABLE_PARITY_CHECK),
    .OP_MODE_WIDTH(OP_MODE_WIDTH),
    .SWIZZLE_MAP_WIDTH(SWIZZLE_MAP_WIDTH)
  ) u_swizzler (
    .clk(clk),
    .rst_n(rst_n),
    .bypass(bypass),
    .data_in(conditioned_data_in),
    .swizzle_map_flat(swizzle_map_flat),
    .operation_mode(operation_mode),
    .data_out(swizzler_data),
    .parity_error(parity_error),
    .invalid_mapping_error(invalid_mapping_error)
  );

  reg [NUM_LANES*DATA_WIDTH-1:0] manipulated_data;
  reg [DATA_WIDTH-1:0] checksum;
  reg checksum_mismatch;
  integer i;

  always @* begin
    manipulated_data = swizzler_data;
    for (i = 0; i < NUM_LANES; i = i + 1) begin
      manipulated_data[DATA_WIDTH*i] = ~swizzler_data[DATA_WIDTH*i];
    end

    checksum = {DATA_WIDTH{1'b0}};
    for (i = 0; i < NUM_LANES; i = i + 1) begin
      checksum = checksum ^ manipulated_data[DATA_WIDTH*i +: DATA_WIDTH];
    end
    checksum_mismatch = (checksum != EXPECTED_CHECKSUM);
  end

  wire error_comb;
  assign error_comb = invalid_mapping_error |
                      (ENABLE_PARITY_CHECK ? parity_error : 1'b0) |
                      checksum_mismatch;

  generate
    if (REGISTER_OUTPUT) begin : GEN_REG_OUT
      always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
          final_data_out <= {NUM_LANES*DATA_WIDTH{1'b0}};
          top_error <= 1'b0;
        end else begin
          final_data_out <= manipulated_data;
          top_error <= error_comb;
        end
      end
    end else begin : GEN_COMB_OUT
      always @* begin
        final_data_out = manipulated_data;
        top_error = error_comb;
      end
    end
  endgenerate

endmodule
