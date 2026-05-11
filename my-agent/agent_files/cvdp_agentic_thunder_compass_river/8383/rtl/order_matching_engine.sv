module order_matching_engine #(
    parameter PRICE_WIDTH = 16
)(
    input                         clk,
    input                         rst,
    input                         start,
    input                         circuit_breaker,
    input      [8*PRICE_WIDTH-1:0] bid_orders,
    input      [8*PRICE_WIDTH-1:0] ask_orders,
    output reg                    match_valid,
    output reg [PRICE_WIDTH-1:0]  matched_price,
    output reg                    done
);

    localparam integer N = 8;
    localparam integer TOTAL_LATENCY = 12;

    reg [PRICE_WIDTH-1:0] best_bid_comb;
    reg [PRICE_WIDTH-1:0] best_ask_comb;
    reg [PRICE_WIDTH-1:0] bid_val;
    reg [PRICE_WIDTH-1:0] ask_val;
    integer i;

    reg pending_match;
    reg [PRICE_WIDTH-1:0] pending_price;
    reg [4:0] cycle_cnt;
    reg busy;

    always @(*) begin
        best_bid_comb = {PRICE_WIDTH{1'b0}};
        best_ask_comb = {PRICE_WIDTH{1'b1}};

        for (i = 0; i < N; i = i + 1) begin
            bid_val = bid_orders[i*PRICE_WIDTH +: PRICE_WIDTH];
            ask_val = ask_orders[i*PRICE_WIDTH +: PRICE_WIDTH];

            if (bid_val > best_bid_comb)
                best_bid_comb = bid_val;

            if (ask_val < best_ask_comb)
                best_ask_comb = ask_val;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            match_valid   <= 1'b0;
            matched_price <= {PRICE_WIDTH{1'b0}};
            done          <= 1'b0;
            pending_match <= 1'b0;
            pending_price <= {PRICE_WIDTH{1'b0}};
            cycle_cnt     <= 5'd0;
            busy          <= 1'b0;
        end else begin
            done <= 1'b0;

            if (start && !busy) begin
                if (!circuit_breaker && (best_bid_comb >= best_ask_comb)) begin
                    pending_match <= 1'b1;
                    pending_price <= best_bid_comb;
                end else begin
                    pending_match <= 1'b0;
                    pending_price <= {PRICE_WIDTH{1'b0}};
                end

                cycle_cnt <= 5'd0;
                busy      <= 1'b1;
            end else if (busy) begin
                if (cycle_cnt == (TOTAL_LATENCY-1)) begin
                    match_valid   <= pending_match;
                    matched_price <= pending_price;
                    done          <= 1'b1;
                    busy          <= 1'b0;
                end else begin
                    cycle_cnt <= cycle_cnt + 5'd1;
                end
            end
        end
    end

endmodule
