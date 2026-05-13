module csr_apb_interface (
    input  wire        pclk,
    input  wire        presetn,
    input  wire        pselx,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [31:0] paddr,
    input  wire [31:0] pwdata,
    output reg  [31:0] prdata,
    output reg         pslverr,
    output wire [1:0]  current_state
);

localparam [31:0] DATA_REG_ADDR      = 32'h10;
localparam [31:0] CONTROL_REG_ADDR   = 32'h14;
localparam [31:0] INTERRUPT_REG_ADDR = 32'h18;
localparam [31:0] ISR_REG_ADDR       = 32'h1C;

localparam [1:0] IDLE        = 2'd0;
localparam [1:0] SETUP       = 2'd1;
localparam [1:0] READ_STATE  = 2'd2;
localparam [1:0] WRITE_STATE = 2'd3;

reg [1:0] state;
reg [31:0] data_reg;
reg [31:0] control_reg;
reg [31:0] interrupt_reg;
reg [31:0] isr_reg;

assign current_state = state;

always @(posedge pclk or negedge presetn) begin
    if (!presetn) begin
        state         <= IDLE;
        data_reg      <= 32'h0;
        control_reg   <= 32'h0;
        interrupt_reg <= 32'h0;
        isr_reg       <= 32'h0;
        prdata        <= 32'h0;
        pslverr       <= 1'b0;
    end else begin
        if (!pselx) begin
            state <= IDLE;
        end else if (!penable) begin
            state <= SETUP;
            pslverr <= 1'b0;
        end else if (pwrite) begin
            state <= WRITE_STATE;
            case (paddr)
                DATA_REG_ADDR: begin
                    data_reg <= pwdata;
                end

                CONTROL_REG_ADDR: begin
                    control_reg <= pwdata;
                end

                INTERRUPT_REG_ADDR: begin
                    interrupt_reg <= pwdata;
                    isr_reg[3:0] <= isr_reg[3:0] & ~pwdata[3:0];
                end

                ISR_REG_ADDR: begin
                    pslverr <= 1'b1;
                end

                default: begin
                    pslverr <= 1'b1;
                end
            endcase
        end else begin
            state <= READ_STATE;
            case (paddr)
                DATA_REG_ADDR:      prdata <= data_reg;
                CONTROL_REG_ADDR:   prdata <= control_reg;
                INTERRUPT_REG_ADDR: prdata <= interrupt_reg;
                ISR_REG_ADDR:       prdata <= isr_reg;
                default:            prdata <= 32'h0;
            endcase
        end
    end
end

endmodule
