module multi_digit_bcd_add_sub #(
    parameter N = 4
) (
    input  [4*N-1:0] A,
    input  [4*N-1:0] B,
    input            add_sub,      // 1: add, 0: subtract (A - B)
    output [4*N-1:0] result,
    output           carry_borrow
);

wire [N:0] carry_chain;
wire final_carry;

assign carry_chain[0] = add_sub ? 1'b0 : 1'b1;

genvar i;
generate
    for (i = 0; i < N; i = i + 1) begin : gen_bcd_digits
        wire [3:0] b_digit_eff;
        assign b_digit_eff = add_sub ? B[(i*4) +: 4] : (4'd9 - B[(i*4) +: 4]);

        bcd_adder u_bcd_adder (
            .a   (A[(i*4) +: 4]),
            .b   (b_digit_eff),
            .cin (carry_chain[i]),
            .sum (result[(i*4) +: 4]),
            .cout(carry_chain[i+1])
        );
    end
endgenerate

assign final_carry = carry_chain[N];
assign carry_borrow = add_sub ? final_carry : ~final_carry;

endmodule
