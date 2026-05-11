module bcd_adder(
                 input  [3:0] a,             // 4-bit input a
                 input  [3:0] b,             // 4-bit input b
                 input        cin,           // Carry input
                 output [3:0] sum,           // 4-bit sum output
                 output       cout           // Carry output
                );

wire [3:0] binary_sum;         // Intermediate binary sum
wire binary_cout;              // Intermediate binary carry
wire z1, z2;                   // Intermediate wires for BCD correction
wire carry;                    // Carry for the second adder

// Instantiate the first four-bit adder for Binary Addition
four_bit_adder adder1(         
                      .a(a),      
                      .b(b),      
                      .cin(cin),       
                      .sum(binary_sum), 
                      .cout(binary_cout) 
                     );

// Logic to determine BCD correction condition
assign z1 = (binary_sum[3] & binary_sum[2]); 
assign z2 = (binary_sum[3] & binary_sum[1]); 
assign cout = (z1 | z2 | binary_cout);        

// Instantiate the second four-bit adder for BCD correction
four_bit_adder adder2(         
                      .a(binary_sum),     
                      .b({1'b0, cout, cout, 1'b0}), 
                      .cin(1'b0),         
                      .sum(sum),          
                      .cout(carry)        
                     );

endmodule     


  
