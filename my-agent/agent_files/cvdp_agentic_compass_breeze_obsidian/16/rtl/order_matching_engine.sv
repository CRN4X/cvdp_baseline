module order_matching_engine #(
    parameter PRICE_WIDTH = 16
)(
    input                        clk,
    input                        rst,
    input                        start,
    input      [8*PRICE_WIDTH-1:0] bid_orders,
    input      [8*PRICE_WIDTH-1:0] ask_orders,
    output reg                   match_valid,
    output reg [PRICE_WIDTH-1:0] matched_price,
    output reg                   done,
    output reg                   latency_error
);

  reg [PRICE_WIDTH-1:0] best_bid;
  reg [PRICE_WIDTH-1:0] best_ask;
  reg [5:0] cycle_count;
  reg busy;

  integer i;
  reg [PRICE_WIDTH-1:0] bid_i;
  reg [PRICE_WIDTH-1:0] ask_i;
  reg [PRICE_WIDTH-1:0] next_best_bid;
  reg [PRICE_WIDTH-1:0] next_best_ask;

  always @(posedge clk or posedge rst) begin
    if (rst) begin
      best_bid       <= {PRICE_WIDTH{1'b0}};
      best_ask       <= {PRICE_WIDTH{1'b0}};
      match_valid    <= 1'b0;
      matched_price  <= {PRICE_WIDTH{1'b0}};
      done           <= 1'b0;
      latency_error  <= 1'b0;
      cycle_count    <= 6'd0;
      busy           <= 1'b0;
    end else begin
      done <= 1'b0;

      if (start && !busy) begin
        next_best_bid = bid_orders[0 +: PRICE_WIDTH];
        next_best_ask = ask_orders[0 +: PRICE_WIDTH];

        for (i = 1; i < 8; i = i + 1) begin
          bid_i = bid_orders[i*PRICE_WIDTH +: PRICE_WIDTH];
          ask_i = ask_orders[i*PRICE_WIDTH +: PRICE_WIDTH];
          if (bid_i > next_best_bid)
            next_best_bid = bid_i;
          if (ask_i < next_best_ask)
            next_best_ask = ask_i;
        end

        best_bid <= next_best_bid;
        best_ask <= next_best_ask;
        cycle_count <= 6'd0;
        busy        <= 1'b1;
      end else if (busy) begin
        cycle_count <= cycle_count + 6'd1;
        if (cycle_count == 6'd19) begin
          busy <= 1'b0;
          done <= 1'b1;
          if (best_bid >= best_ask) begin
            match_valid   <= 1'b1;
            matched_price <= best_ask;
          end else begin
            match_valid   <= 1'b0;
            matched_price <= {PRICE_WIDTH{1'b0}};
          end
          latency_error <= 1'b0;
        end
      end
    end
  end

endmodule
