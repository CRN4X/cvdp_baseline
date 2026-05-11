module APBGlobalHistoryRegister (
    input  wire         pclk,
    input  wire         presetn,

    input  wire [9:0]   paddr,
    input  wire         pselx,
    input  wire         penable,
    input  wire         pwrite,
    input  wire [7:0]   pwdata,
    input  wire         history_shift_valid,
    input  wire         clk_gate_en,
    input  wire         secure_enable,

    output reg          pready,
    output reg  [7:0]   prdata,
    output reg          pslverr,
    output reg          history_full,
    output reg          history_empty,
    output reg          error_flag,
    output reg          interrupt_full,
    output reg          interrupt_error
);

    localparam ADDR_CTRL_REG    = 10'h0;
    localparam ADDR_TRAIN_HIS   = 10'h1;
    localparam ADDR_PREDICT_HIS = 10'h2;
    localparam WIDTH            = 8;

    reg [WIDTH-1:0] control_register;
    reg [WIDTH-1:0] train_history;
    reg [WIDTH-1:0] predict_history;

    wire apb_valid;
    wire pclk_gated;
    wire predict_valid;
    wire predict_taken;
    wire train_mispredicted;
    wire train_taken;

    assign apb_valid = pselx & penable;
    assign pclk_gated = (~clk_gate_en) & pclk;

    always @(posedge pclk_gated or negedge presetn) begin
        if (!presetn) begin
            pready  <= 1'b0;
            pslverr <= 1'b0;
        end else begin
            pready <= 1'b1;
            if (apb_valid) begin
                if (paddr > ADDR_PREDICT_HIS)
                    pslverr <= 1'b1;
                else
                    pslverr <= 1'b0;
            end
        end
    end

    always @(posedge pclk_gated or negedge presetn) begin
        if (!presetn) begin
            control_register <= 8'h00;
            train_history    <= 8'h00;
        end else if (apb_valid && pwrite) begin
            case (paddr)
                ADDR_CTRL_REG:  control_register[3:0] <= pwdata[3:0];
                ADDR_TRAIN_HIS: train_history[6:0]    <= pwdata[6:0];
                default: ;
            endcase
        end
    end

    always @(posedge pclk_gated or negedge presetn) begin
        if (!presetn) begin
            prdata <= 8'h00;
        end else if (apb_valid) begin
            case (paddr)
                ADDR_CTRL_REG:    prdata <= {4'b0, control_register[3:0]};
                ADDR_TRAIN_HIS:   prdata <= {1'b0, train_history[6:0]};
                ADDR_PREDICT_HIS: prdata <= predict_history;
                default:          prdata <= 8'h00;
            endcase
        end else begin
            prdata <= 8'h00;
        end
    end

    assign predict_valid      = control_register[0];
    assign predict_taken      = control_register[1];
    assign train_mispredicted = control_register[2];
    assign train_taken        = control_register[3];

    always @(posedge history_shift_valid or negedge presetn) begin
        if (!presetn) begin
            predict_history <= 8'h00;
        end else if (secure_enable) begin
            if (train_mispredicted)
                predict_history <= {train_history[WIDTH-2:0], train_taken};
            else if (predict_valid)
                predict_history <= {predict_history[WIDTH-2:0], predict_taken};
        end
    end

    always @(*) begin
        error_flag       = pslverr;
        interrupt_error  = pslverr;
        if (predict_history == 8'hFF) begin
            history_full    = 1'b1;
            interrupt_full  = 1'b1;
            history_empty   = 1'b0;
        end else if (predict_history == 8'h00) begin
            history_full    = 1'b0;
            interrupt_full  = 1'b0;
            history_empty   = 1'b1;
        end else begin
            history_full    = 1'b0;
            interrupt_full  = 1'b0;
            history_empty   = 1'b0;
        end
    end

endmodule
