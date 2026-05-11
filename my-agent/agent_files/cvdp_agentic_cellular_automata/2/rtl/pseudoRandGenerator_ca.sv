module pseudoRandGenerator_ca (
    input  logic        clock,
    input  logic        reset,
    input  logic [15:0] CA_seed,
    input  logic [1:0]  rule_sel,
    output logic [15:0] CA_out
);

    logic [15:0] next_CA_out;
    integer i;

    function automatic logic compute_next_bit (
        input logic [15:0] state,
        input integer idx,
        input logic [1:0] rule
    );
        logic left_bit;
        logic center_bit;
        logic right_bit;
        logic [2:0] neighborhood;
        begin
            left_bit   = state[(idx == 0) ? 15 : (idx - 1)];
            center_bit = state[idx];
            right_bit  = state[(idx == 15) ? 0 : (idx + 1)];
            neighborhood = {left_bit, center_bit, right_bit};

            case (rule)
                2'b01: begin // Rule 110
                    case (neighborhood)
                        3'b111: compute_next_bit = 1'b0;
                        3'b110: compute_next_bit = 1'b1;
                        3'b101: compute_next_bit = 1'b1;
                        3'b100: compute_next_bit = 1'b0;
                        3'b011: compute_next_bit = 1'b1;
                        3'b010: compute_next_bit = 1'b1;
                        3'b001: compute_next_bit = 1'b1;
                        default: compute_next_bit = 1'b0;
                    endcase
                end
                default: begin // Rule 30 (also default for invalid selection)
                    case (neighborhood)
                        3'b111: compute_next_bit = 1'b0;
                        3'b110: compute_next_bit = 1'b0;
                        3'b101: compute_next_bit = 1'b0;
                        3'b100: compute_next_bit = 1'b1;
                        3'b011: compute_next_bit = 1'b1;
                        3'b010: compute_next_bit = 1'b1;
                        3'b001: compute_next_bit = 1'b1;
                        default: compute_next_bit = 1'b0;
                    endcase
                end
            endcase
        end
    endfunction

    always_comb begin
        for (i = 0; i < 16; i = i + 1) begin
            next_CA_out[i] = compute_next_bit(CA_out, i, rule_sel);
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            CA_out <= CA_seed;
        end else begin
            CA_out <= next_CA_out;
        end
    end

endmodule
