module uart_rx_to_axis #(
    parameter int CLK_FREQ      = 100,
    parameter int BIT_RATE      = 115200,
    parameter int BIT_PER_WORD  = 8,
    parameter int PARITY_BIT    = 0,  // 0: none, 1: odd, 2: even
    parameter int STOP_BITS_NUM = 1
) (
    input  logic                    aclk,
    input  logic                    aresetn,
    input  logic                    RX,
    output logic [BIT_PER_WORD-1:0] tdata,
    output logic                    tuser,
    output logic                    tvalid
);

    localparam int CYCLES_PER_BIT = (CLK_FREQ * 1000000) / BIT_RATE;
    localparam int HALF_BIT_CYC   = (CYCLES_PER_BIT > 1) ? (CYCLES_PER_BIT/2) : 1;

    typedef enum logic [2:0] {
        IDLE,
        START,
        DATA,
        PARITY,
        STOP1,
        STOP2,
        OUT_RDY
    } state_t;

    state_t state;

    logic [$clog2(CYCLES_PER_BIT+1)-1:0] baud_cnt;
    logic [$clog2(BIT_PER_WORD+1)-1:0]   bit_cnt;
    logic [BIT_PER_WORD-1:0]             data_shift;
    logic                                 parity_acc;
    logic                                 parity_err;
    logic                                 rx_d;

    logic expected_parity;
    always_comb begin
        case (PARITY_BIT)
            1: expected_parity = ~parity_acc; // odd parity
            2: expected_parity =  parity_acc; // even parity
            default: expected_parity = 1'b0;
        endcase
    end

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            state      <= IDLE;
            baud_cnt   <= '0;
            bit_cnt    <= '0;
            data_shift <= '0;
            parity_acc <= 1'b0;
            parity_err <= 1'b0;
            rx_d       <= 1'b1;
            tdata      <= '0;
            tuser      <= 1'b0;
            tvalid     <= 1'b0;
        end else begin
            rx_d   <= RX;
            tvalid <= 1'b0;

            case (state)
                IDLE: begin
                    bit_cnt    <= '0;
                    parity_acc <= 1'b0;
                    parity_err <= 1'b0;
                    // falling-edge detect for start bit
                    if (rx_d && !RX) begin
                        baud_cnt <= HALF_BIT_CYC - 1;
                        state    <= START;
                    end
                end

                START: begin
                    if (baud_cnt != 0) begin
                        baud_cnt <= baud_cnt - 1'b1;
                    end else begin
                        // validate centered start bit sample
                        if (RX == 1'b0) begin
                            baud_cnt <= CYCLES_PER_BIT - 1;
                            bit_cnt  <= '0;
                            state    <= DATA;
                        end else begin
                            state <= IDLE;
                        end
                    end
                end

                DATA: begin
                    if (baud_cnt != 0) begin
                        baud_cnt <= baud_cnt - 1'b1;
                    end else begin
                        data_shift[bit_cnt] <= RX; // UART is LSB first
                        parity_acc          <= parity_acc ^ RX;
                        baud_cnt            <= CYCLES_PER_BIT - 1;

                        if (bit_cnt == BIT_PER_WORD-1) begin
                            if (PARITY_BIT == 0) begin
                                state <= STOP1;
                            end else begin
                                state <= PARITY;
                            end
                        end else begin
                            bit_cnt <= bit_cnt + 1'b1;
                        end
                    end
                end

                PARITY: begin
                    if (baud_cnt != 0) begin
                        baud_cnt <= baud_cnt - 1'b1;
                    end else begin
                        parity_err <= (RX != expected_parity);
                        baud_cnt   <= CYCLES_PER_BIT - 1;
                        state      <= STOP1;
                    end
                end

                STOP1: begin
                    if (baud_cnt != 0) begin
                        baud_cnt <= baud_cnt - 1'b1;
                    end else begin
                        if (RX == 1'b1) begin
                            if (STOP_BITS_NUM == 2) begin
                                baud_cnt <= CYCLES_PER_BIT - 1;
                                state    <= STOP2;
                            end else begin
                                tdata  <= data_shift;
                                tuser  <= (PARITY_BIT == 0) ? 1'b0 : parity_err;
                                tvalid <= 1'b1;
                                state  <= OUT_RDY;
                            end
                        end else begin
                            state <= IDLE;
                        end
                    end
                end

                STOP2: begin
                    if (baud_cnt != 0) begin
                        baud_cnt <= baud_cnt - 1'b1;
                    end else begin
                        if (RX == 1'b1) begin
                            tdata  <= data_shift;
                            tuser  <= (PARITY_BIT == 0) ? 1'b0 : parity_err;
                            tvalid <= 1'b1;
                            state  <= OUT_RDY;
                        end else begin
                            state <= IDLE;
                        end
                    end
                end

                OUT_RDY: begin
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
