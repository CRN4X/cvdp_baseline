module cache_controller (
    input  logic        clk,
    input  logic        reset,
    input  logic [31:0] address,
    input  logic        read,
    input  logic        write,
    input  logic [31:0] write_data,
    input  logic [31:0] mem_read_data,
    input  logic        mem_ready,
    output logic [31:0] read_data,
    output logic        hit,
    output logic [31:0] mem_address,
    output logic        mem_write,
    output logic [31:0] mem_write_data
);

  logic [31:0] data_array [0:31];
  logic [4:0]  tag_array  [0:31];
  logic        valid_array[0:31];

  logic [4:0] idx;
  logic [4:0] tag;
  logic       line_hit;
  integer     i;

  always_comb begin
    idx = address[4:0];
    tag = address[9:5];
    line_hit = valid_array[idx] && (tag_array[idx] == tag);
    hit = line_hit;
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      for (i = 0; i < 32; i = i + 1) begin
        valid_array[i] <= 1'b0;
        tag_array[i] <= 5'b0;
        data_array[i] <= 32'b0;
      end
      read_data <= 32'b0;
      mem_address <= 32'b0;
      mem_write <= 1'b0;
      mem_write_data <= 32'b0;
    end else begin
      mem_address <= address;
      mem_write <= 1'b0;
      mem_write_data <= write_data;

      if (read) begin
        if (line_hit) begin
          read_data <= data_array[idx];
        end else if (mem_ready) begin
          data_array[idx] <= mem_read_data;
          tag_array[idx] <= tag;
          valid_array[idx] <= 1'b1;
          read_data <= mem_read_data;
        end
      end

      if (write) begin
        mem_write <= 1'b1;
        if (line_hit) begin
          data_array[idx] <= write_data;
        end
      end
    end
  end

endmodule
