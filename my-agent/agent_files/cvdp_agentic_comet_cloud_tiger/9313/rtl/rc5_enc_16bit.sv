module rc5_enc_16bit (
    input  wire        clock,
    input  wire        reset,
    input  wire        enc_start,
    input  wire [15:0] p,
    output reg  [15:0] c,
    output reg         enc_done
);

    localparam [7:0] S0 = 8'hAB;
    localparam [7:0] S1 = 8'h29;
    localparam [7:0] S2 = 8'h6E;
    localparam [7:0] S3 = 8'hC1;

    localparam [2:0] ST_IDLE = 3'd0;
    localparam [2:0] ST_ADD  = 3'd1;
    localparam [2:0] ST_MSB  = 3'd2;
    localparam [2:0] ST_LSB  = 3'd3;
    localparam [2:0] ST_OUT  = 3'd4;

    reg [2:0] state;
    reg [7:0] A;
    reg [7:0] B;

    function automatic [7:0] rotl8;
        input [7:0] data;
        input [2:0] shamt;
        begin
            rotl8 = (data << shamt) | (data >> (3'd8 - shamt));
        end
    endfunction

    always @(posedge clock) begin
        if (!reset) begin
            state    <= ST_IDLE;
            A        <= 8'h00;
            B        <= 8'h00;
            c        <= 16'h0000;
            enc_done <= 1'b0;
        end else begin
            case (state)
                ST_IDLE: begin
                    enc_done <= 1'b0;
                    if (enc_start) begin
                        A     <= p[15:8];
                        B     <= p[7:0];
                        state <= ST_ADD;
                    end
                end

                ST_ADD: begin
                    A     <= A + S0;
                    B     <= B + S1;
                    state <= ST_MSB;
                end

                ST_MSB: begin
                    A     <= rotl8((A ^ B), B[2:0]) + S2;
                    state <= ST_LSB;
                end

                ST_LSB: begin
                    B     <= rotl8((B ^ A), A[2:0]) + S3;
                    state <= ST_OUT;
                end

                ST_OUT: begin
                    c        <= {A, B};
                    enc_done <= 1'b1;
                    state    <= ST_IDLE;
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
