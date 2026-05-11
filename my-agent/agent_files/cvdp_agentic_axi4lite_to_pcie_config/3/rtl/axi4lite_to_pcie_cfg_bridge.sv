`timescale 1ns/1ps

module axi4lite_to_pcie_cfg_bridge #(
     
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32  
    )(
    // AXI4-Lite Interface
    input  logic        aclk,           
    input  logic        aresetn,        
    input  logic [ADDR_WIDTH-1:0] awaddr,         
    input  logic        awvalid,        
    output logic        awready,        
    input  logic [DATA_WIDTH-1:0] wdata,          
    input  logic [DATA_WIDTH/8-1:0]  wstrb,          
    input  logic        wvalid,         
    output logic        wready,         
    output logic [1:0]  bresp,          
    output logic        bvalid,         
    input  logic        bready,         
    input  logic [ADDR_WIDTH-1:0] araddr,
    input  logic        arvalid,
    output logic        arready,
    output logic [DATA_WIDTH-1:0] rdata,
    output logic        rvalid,
    input  logic        rready,
    output logic [1:0]  rresp,

    // PCIe Configuration Space Interface
    output logic [ADDR_WIDTH-1:0]  pcie_cfg_addr,  
    output logic [DATA_WIDTH-1:0] pcie_cfg_wdata, 
    output logic        pcie_cfg_wr_en, 
    input  logic [DATA_WIDTH-1:0] pcie_cfg_rdata, 
    input  logic        pcie_cfg_rd_en  
);

    // FSM Output Logic
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            awready <= 1'b0;
            wready <= 1'b0;
            bvalid <= 1'b0;
            bresp <= 2'b00; // OKAY response
            arready <= 1'b0;
            rdata <= '0;
            rvalid <= 1'b0;
            rresp <= 2'b00; // OKAY response
            pcie_cfg_wr_en <= 1'b0;
            pcie_cfg_wdata <= '0;
            pcie_cfg_addr <= '0;
        end else begin
            awready <= 1'b0;
            wready <= 1'b0;
            arready <= 1'b0;
            pcie_cfg_wr_en <= 1'b0;

            // Complete write response when master accepts it.
            if (bvalid && bready) begin
                bvalid <= 1'b0;
            end

            // Complete read response when master accepts it.
            if (rvalid && rready) begin
                rvalid <= 1'b0;
            end

            // Accept one write request when no pending write response.
            if (!bvalid && awvalid && wvalid) begin
                awready <= 1'b1;
                wready <= 1'b1;
                bvalid <= 1'b1;
                bresp <= 2'b00;
                pcie_cfg_wr_en <= 1'b1;
                pcie_cfg_addr <= awaddr;

                // Apply wstrb to write only selected byte lanes.
                for (int i = 0; i < (DATA_WIDTH/8); i++) begin
                    pcie_cfg_wdata[(i*8)+:8] <= wstrb[i] ? wdata[(i*8)+:8] : pcie_cfg_rdata[(i*8)+:8];
                end
            end
            // Accept one read request when no pending read response.
            else if (!rvalid && arvalid) begin
                arready <= 1'b1;
                pcie_cfg_addr <= araddr;
                rdata <= pcie_cfg_rdata;
                rresp <= 2'b00;
                rvalid <= 1'b1;
            end
        end
    end

endmodule
