module pcie_endpoint #(
    parameter int ADDR_WIDTH = 64,
    parameter int DATA_WIDTH = 128,
    parameter int MEM_DEPTH  = 256
) (
    input  logic                   clk,
    input  logic                   rst_n,

    input  logic [DATA_WIDTH-1:0]  pcie_rx_tlp,
    input  logic                   pcie_rx_valid,

    output logic [DATA_WIDTH-1:0]  pcie_tx_tlp,
    output logic                   pcie_tx_valid,
    input  logic                   pcie_tx_ready,

    input  logic                   dma_request,
    output logic [ADDR_WIDTH-1:0]  dma_address,
    output logic [DATA_WIDTH-1:0]  dma_data,
    output logic                   dma_complete,

    output logic                   msix_interrupt,
    input  logic                   msix_ack
);

    localparam int MEM_AW = (MEM_DEPTH <= 2) ? 1 : $clog2(MEM_DEPTH);

    typedef enum logic [1:0] {
        PCIE_IDLE,
        PCIE_DECODE,
        PCIE_TX
    } pcie_state_t;

    typedef enum logic [1:0] {
        DMA_IDLE,
        DMA_ACTIVE,
        DMA_DONE
    } dma_state_t;

    typedef enum logic [1:0] {
        MSIX_IDLE,
        MSIX_ASSERT
    } msix_state_t;

    pcie_state_t pcie_state;
    dma_state_t  dma_state;
    msix_state_t msix_state;

    logic [DATA_WIDTH-1:0] memory [0:MEM_DEPTH-1];
    logic [MEM_AW-1:0]     wr_ptr;
    logic [MEM_AW-1:0]     rd_ptr;

    logic [DATA_WIDTH-1:0] decoded_data;
    logic                  tx_pending;

    integer i;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pcie_state     <= PCIE_IDLE;
            dma_state      <= DMA_IDLE;
            msix_state     <= MSIX_IDLE;
            pcie_tx_tlp    <= '0;
            pcie_tx_valid  <= 1'b0;
            dma_address    <= '0;
            dma_data       <= '0;
            dma_complete   <= 1'b0;
            msix_interrupt <= 1'b0;
            wr_ptr         <= '0;
            rd_ptr         <= '0;
            decoded_data   <= '0;
            tx_pending     <= 1'b0;
            for (i = 0; i < MEM_DEPTH; i = i + 1) begin
                memory[i] <= '0;
            end
        end else begin
            dma_complete <= 1'b0;

            // PCIe transaction handling
            case (pcie_state)
                PCIE_IDLE: begin
                    pcie_tx_valid <= 1'b0;
                    if (pcie_rx_valid) begin
                        decoded_data <= pcie_rx_tlp;
                        pcie_state   <= PCIE_DECODE;
                    end
                end

                PCIE_DECODE: begin
                    // Treat the incoming TLP payload as write data and retain a readback path.
                    memory[wr_ptr] <= decoded_data;
                    wr_ptr         <= wr_ptr + {{(MEM_AW-1){1'b0}}, 1'b1};
                    pcie_tx_tlp    <= decoded_data;
                    tx_pending     <= 1'b1;
                    pcie_state     <= PCIE_TX;
                end

                PCIE_TX: begin
                    if (tx_pending) begin
                        pcie_tx_valid <= 1'b1;
                        if (pcie_tx_ready) begin
                            pcie_tx_valid <= 1'b0;
                            tx_pending    <= 1'b0;
                            rd_ptr        <= rd_ptr + {{(MEM_AW-1){1'b0}}, 1'b1};
                            pcie_state    <= PCIE_IDLE;
                        end
                    end else begin
                        pcie_tx_valid <= 1'b0;
                        pcie_state    <= PCIE_IDLE;
                    end
                end

                default: pcie_state <= PCIE_IDLE;
            endcase

            // DMA engine interface
            case (dma_state)
                DMA_IDLE: begin
                    if (dma_request) begin
                        dma_address <= {{(ADDR_WIDTH-MEM_AW){1'b0}}, rd_ptr};
                        dma_data    <= memory[rd_ptr];
                        dma_state   <= DMA_ACTIVE;
                    end
                end

                DMA_ACTIVE: begin
                    dma_complete <= 1'b1;
                    dma_state    <= DMA_DONE;
                end

                DMA_DONE: begin
                    dma_state <= DMA_IDLE;
                end

                default: dma_state <= DMA_IDLE;
            endcase

            // MSI-X interrupt management
            case (msix_state)
                MSIX_IDLE: begin
                    if (dma_complete) begin
                        msix_interrupt <= 1'b1;
                        msix_state     <= MSIX_ASSERT;
                    end
                end

                MSIX_ASSERT: begin
                    if (msix_ack) begin
                        msix_interrupt <= 1'b0;
                        msix_state     <= MSIX_IDLE;
                    end
                end

                default: msix_state <= MSIX_IDLE;
            endcase
        end
    end

endmodule
