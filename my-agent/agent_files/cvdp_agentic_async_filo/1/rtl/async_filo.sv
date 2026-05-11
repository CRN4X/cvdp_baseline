module async_filo #(
    parameter int DATA_WIDTH = 16,
    parameter int DEPTH      = 8
) (
    input  logic                  w_clk,
    input  logic                  w_rst,
    input  logic                  push,
    input  logic                  r_clk,
    input  logic                  r_rst,
    input  logic                  pop,
    input  logic [DATA_WIDTH-1:0] w_data,
    output logic [DATA_WIDTH-1:0] r_data,
    output logic                  r_empty,
    output logic                  w_full
);

  localparam int ADDR_W = (DEPTH <= 2) ? 1 : $clog2(DEPTH);
  localparam int PTR_W  = $clog2(DEPTH + 1);

  logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

  logic [PTR_W-1:0] w_depth_bin;
  logic [PTR_W-1:0] w_depth_gray;
  logic [PTR_W-1:0] w_next_depth;

  logic pop_tgl_r;
  logic wq1_pop_tgl, wq2_pop_tgl, wq2_pop_tgl_d;

  logic [PTR_W-1:0] rq1_wgray, rq2_wgray;
  logic [PTR_W-1:0] r_depth_bin;

  function automatic [PTR_W-1:0] bin2gray(input [PTR_W-1:0] bin);
    bin2gray = (bin >> 1) ^ bin;
  endfunction

  function automatic [PTR_W-1:0] gray2bin(input [PTR_W-1:0] gray);
    integer i;
    begin
      gray2bin[PTR_W-1] = gray[PTR_W-1];
      for (i = PTR_W - 2; i >= 0; i = i - 1) begin
        gray2bin[i] = gray2bin[i+1] ^ gray[i];
      end
    end
  endfunction

  always_comb begin
    w_next_depth = w_depth_bin;

    if ((wq2_pop_tgl ^ wq2_pop_tgl_d) && (w_next_depth != '0)) begin
      w_next_depth = w_next_depth - 1'b1;
    end

    if (push && (w_next_depth < DEPTH[PTR_W-1:0])) begin
      w_next_depth = w_next_depth + 1'b1;
    end
  end

  always_comb begin
    r_depth_bin = gray2bin(rq2_wgray);
  end

  always_ff @(posedge w_clk) begin
    if (w_rst) begin
      w_depth_bin    <= '0;
      w_depth_gray   <= '0;
      wq1_pop_tgl    <= 1'b0;
      wq2_pop_tgl    <= 1'b0;
      wq2_pop_tgl_d  <= 1'b0;
      w_full         <= 1'b0;
    end else begin
      wq1_pop_tgl   <= pop_tgl_r;
      wq2_pop_tgl   <= wq1_pop_tgl;
      wq2_pop_tgl_d <= wq2_pop_tgl;

      if (push && (w_next_depth > w_depth_bin)) begin
        mem[w_depth_bin[ADDR_W-1:0]] <= w_data;
      end

      w_depth_bin  <= w_next_depth;
      w_depth_gray <= bin2gray(w_next_depth);
      w_full       <= (w_next_depth == DEPTH[PTR_W-1:0]);
    end
  end

  always_ff @(posedge r_clk) begin
    if (r_rst) begin
      rq1_wgray <= '0;
      rq2_wgray <= '0;
      pop_tgl_r <= 1'b0;
      r_empty   <= 1'b1;
      r_data    <= '0;
    end else begin
      rq1_wgray <= w_depth_gray;
      rq2_wgray <= rq1_wgray;

      r_empty <= (r_depth_bin == '0);

      if (pop && (r_depth_bin != '0)) begin
        r_data    <= mem[r_depth_bin - 1'b1];
        pop_tgl_r <= ~pop_tgl_r;
      end
    end
  end

endmodule
