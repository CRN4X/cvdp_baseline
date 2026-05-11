module pcie_endpoint #(
    parameter int ADDR_WIDTH = 64,
    parameter int DATA_WIDTH = 128
) (
    input  logic                  clk,
    input  logic                  rst_n,

    input  logic [DATA_WIDTH-1:0] pcie_rx_tlp,
    input  logic                  pcie_rx_valid,
    output logic                  pcie_rx_ready,

    output logic [DATA_WIDTH-1:0] pcie_tx_tlp,
    output logic                  pcie_tx_valid,
    input  logic                  pcie_tx_ready,

    input  logic                  dma_request,
    output logic                  dma_complete,

    output logic                  msix_interrupt
);

    logic [DATA_WIDTH-1:0] tlp_decoded_data;
    logic                  tlp_valid;
    logic [ADDR_WIDTH-1:0] dma_address;
    logic [DATA_WIDTH-1:0] dma_data;

    assign pcie_rx_ready = 1'b1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tlp_decoded_data <= '0;
            tlp_valid        <= 1'b0;
            pcie_tx_tlp      <= '0;
            pcie_tx_valid    <= 1'b0;
            dma_address      <= '0;
            dma_data         <= '0;
            dma_complete     <= 1'b0;
            msix_interrupt   <= 1'b0;
        end else begin
            dma_complete   <= 1'b0;
            msix_interrupt <= 1'b0;

            if (pcie_rx_valid) begin
                tlp_decoded_data <= pcie_rx_tlp;
                tlp_valid        <= 1'b1;
                dma_data         <= pcie_rx_tlp;
            end

            if (tlp_valid) begin
                if (!pcie_tx_valid || pcie_tx_ready) begin
                    pcie_tx_tlp   <= tlp_decoded_data;
                    pcie_tx_valid <= 1'b1;
                    tlp_valid     <= 1'b0;
                end
            end else if (pcie_tx_valid && pcie_tx_ready) begin
                pcie_tx_valid <= 1'b0;
            end

            if (dma_request) begin
                dma_address    <= dma_address + ADDR_WIDTH'(4);
                dma_complete   <= 1'b1;
                msix_interrupt <= 1'b1;
            end
        end
    end

endmodule
