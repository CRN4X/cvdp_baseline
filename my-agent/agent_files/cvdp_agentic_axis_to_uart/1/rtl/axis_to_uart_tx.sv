module axis_to_uart_tx #(
    parameter int CLK_FREQ     = 100,
    parameter int BIT_RATE     = 115200,
    parameter int BIT_PER_WORD = 8,
    parameter int PARITY_BIT   = 1,
    parameter int STOP_BITS_NUM = 1
) (
    input  logic                    aclk,
    input  logic                    aresetn,
    input  logic [BIT_PER_WORD-1:0] tdata,
    input  logic                    tvalid,
    output logic                    tready,
    output logic                    TX
);

    localparam int CYCLES_PER_PERIOD = ((CLK_FREQ * 1_000_000) / BIT_RATE);
    localparam int CLKCNT_W = (CYCLES_PER_PERIOD > 1) ? $clog2(CYCLES_PER_PERIOD) : 1;
    localparam int BITCNT_W = (BIT_PER_WORD > 1) ? $clog2(BIT_PER_WORD) : 1;

    typedef enum logic [2:0] {
        IDLE,
        START,
        DATA,
        PARITY,
        STOP1,
        STOP2
    } state_t;

    state_t state;

    logic [BIT_PER_WORD-1:0] data_reg;
    logic [BITCNT_W-1:0]     bit_count;
    logic [CLKCNT_W-1:0]     clk_count;
    logic                    parity_calc;

    function automatic logic compute_parity(input logic [BIT_PER_WORD-1:0] d);
        logic p;
        begin
            p = ^d;
            case (PARITY_BIT)
                1: compute_parity = ~p; // odd
                2: compute_parity = p;  // even
                default: compute_parity = 1'b0;
            endcase
        end
    endfunction

    assign tready = (state == IDLE);

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            state       <= IDLE;
            data_reg    <= '0;
            bit_count   <= '0;
            clk_count   <= '0;
            parity_calc <= 1'b0;
            TX          <= 1'b1;
        end else begin
            case (state)
                IDLE: begin
                    TX        <= 1'b1;
                    clk_count <= '0;
                    bit_count <= '0;
                    if (tvalid) begin
                        data_reg    <= tdata;
                        parity_calc <= compute_parity(tdata);
                        TX          <= 1'b0;
                        state       <= START;
                    end
                end

                START: begin
                    if (clk_count == CYCLES_PER_PERIOD-1) begin
                        clk_count <= '0;
                        bit_count <= '0;
                        TX        <= data_reg[0];
                        state     <= DATA;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                DATA: begin
                    if (clk_count == CYCLES_PER_PERIOD-1) begin
                        clk_count <= '0;
                        if (bit_count == BIT_PER_WORD-1) begin
                            if (PARITY_BIT != 0) begin
                                TX    <= parity_calc;
                                state <= PARITY;
                            end else begin
                                TX    <= 1'b1;
                                state <= STOP1;
                            end
                        end else begin
                            bit_count <= bit_count + 1'b1;
                            TX        <= data_reg[bit_count + 1'b1];
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                PARITY: begin
                    if (clk_count == CYCLES_PER_PERIOD-1) begin
                        clk_count <= '0;
                        TX        <= 1'b1;
                        state     <= STOP1;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                STOP1: begin
                    if (clk_count == CYCLES_PER_PERIOD-1) begin
                        clk_count <= '0;
                        TX        <= 1'b1;
                        if (STOP_BITS_NUM == 2) begin
                            state <= STOP2;
                        end else begin
                            state <= IDLE;
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                STOP2: begin
                    if (clk_count == CYCLES_PER_PERIOD-1) begin
                        clk_count <= '0;
                        TX        <= 1'b1;
                        state     <= IDLE;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                default: begin
                    state <= IDLE;
                    TX    <= 1'b1;
                end
            endcase
        end
    end

endmodule
