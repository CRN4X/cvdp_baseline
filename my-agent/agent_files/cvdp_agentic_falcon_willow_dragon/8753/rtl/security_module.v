module security_module #(
    parameter p_unlock_code_0 = 8'hAB,
    parameter p_unlock_code_1 = 8'hCD
) (
    input  wire       i_capture_pulse,
    input  wire       presetn,
    input  wire [9:0] paddr,
    input  wire       pwrite,
    input  wire [7:0] pwdata,
    output reg        secure_enable
);

    localparam ST_LOCKED = 2'd0;
    localparam ST_STAGE1 = 2'd1;
    localparam ST_UNLOCK = 2'd2;

    reg [1:0] state;

    always @(posedge i_capture_pulse or negedge presetn) begin
        if (!presetn) begin
            state         <= ST_LOCKED;
            secure_enable <= 1'b0;
        end else begin
            case (state)
                ST_LOCKED: begin
                    if (pwrite && (paddr == 10'd0) && (pwdata == p_unlock_code_0))
                        state <= ST_STAGE1;
                    else
                        state <= ST_LOCKED;
                    secure_enable <= 1'b0;
                end
                ST_STAGE1: begin
                    if (pwrite && (paddr == 10'd1) && (pwdata == p_unlock_code_1)) begin
                        state         <= ST_UNLOCK;
                        secure_enable <= 1'b1;
                    end else begin
                        state         <= ST_LOCKED;
                        secure_enable <= 1'b0;
                    end
                end
                default: begin
                    state         <= ST_UNLOCK;
                    secure_enable <= 1'b1;
                end
            endcase
        end
    end

endmodule
