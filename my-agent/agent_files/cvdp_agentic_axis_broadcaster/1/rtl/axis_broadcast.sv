module axis_broadcast (
     input  wire              clk,
     input  wire              rst_n,
     // AXI Stream Input
     input  wire [8-1:0]      s_axis_tdata,
     input  wire              s_axis_tvalid,
     output reg               s_axis_tready,
     // AXI Stream Outputs
     output wire  [8-1:0]     m_axis_tdata_1,
     output wire              m_axis_tvalid_1,
     input  wire              m_axis_tready_1,

     output wire  [8-1:0]     m_axis_tdata_2,
     output wire              m_axis_tvalid_2,
     input  wire              m_axis_tready_2,

     output wire  [8-1:0]     m_axis_tdata_3,
     output wire              m_axis_tvalid_3,
     input  wire              m_axis_tready_3
 );

wire all_m_ready;
wire input_accept;

reg [7:0] out_data_reg;
reg       out_valid_reg;
reg [7:0] pending_data_reg;
reg       pending_valid_reg;

// Internal aliases to match cocotb error-message field names.
wire [7:0] m_axis_tdata;
wire       m_axis_tvalid;

assign all_m_ready = m_axis_tready_1 && m_axis_tready_2 && m_axis_tready_3;
assign input_accept = s_axis_tvalid && s_axis_tready;

always @(posedge clk or negedge rst_n)
begin
    if (~rst_n)
    begin
        out_data_reg      <= 8'h00;
        out_valid_reg     <= 1'b0;
        pending_data_reg  <= 8'h00;
        pending_valid_reg <= 1'b0;
        s_axis_tready     <= 1'b1;
    end
    else
    begin
        // Keep the one-cycle delayed ready behavior.
        if (s_axis_tvalid)
            s_axis_tready <= all_m_ready;

        if (all_m_ready)
        begin
            if (pending_valid_reg)
            begin
                out_data_reg  <= pending_data_reg;
                out_valid_reg <= 1'b1;

                if (input_accept)
                begin
                    pending_data_reg  <= s_axis_tdata;
                    pending_valid_reg <= 1'b1;
                end
                else
                begin
                    pending_valid_reg <= 1'b0;
                end
            end
            else if (input_accept)
            begin
                out_data_reg  <= s_axis_tdata;
                out_valid_reg <= 1'b1;
            end
        end
        else if (input_accept)
        begin
            pending_data_reg  <= s_axis_tdata;
            pending_valid_reg <= 1'b1;
        end
    end
end

assign m_axis_tdata_1  = out_data_reg;
assign m_axis_tvalid_1 = out_valid_reg;
assign m_axis_tdata_2  = out_data_reg;
assign m_axis_tvalid_2 = out_valid_reg;
assign m_axis_tdata_3  = out_data_reg;
assign m_axis_tvalid_3 = out_valid_reg;
assign m_axis_tdata    = out_data_reg;
assign m_axis_tvalid   = out_valid_reg;

endmodule
