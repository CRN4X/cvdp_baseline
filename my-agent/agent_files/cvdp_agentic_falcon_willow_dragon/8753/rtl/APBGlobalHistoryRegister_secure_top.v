module APBGlobalHistoryRegister_secure_top #(
    parameter p_unlock_code_0 = 8'hAB,
    parameter p_unlock_code_1 = 8'hCD
) (
    input  wire         pclk,
    input  wire         presetn,
    input  wire [9:0]   paddr,
    input  wire         pselx,
    input  wire         penable,
    input  wire         pwrite,
    input  wire [7:0]   pwdata,
    input  wire         history_shift_valid,
    input  wire         clk_gate_en,
    input  wire         i_capture_pulse,
    output wire         pready,
    output wire [7:0]   prdata,
    output wire         pslverr,
    output wire         history_full,
    output wire         history_empty,
    output wire         error_flag,
    output wire         interrupt_full,
    output wire         interrupt_error
);

    wire secure_enable;

    security_module #(
        .p_unlock_code_0(p_unlock_code_0),
        .p_unlock_code_1(p_unlock_code_1)
    ) u_security_module (
        .i_capture_pulse(i_capture_pulse),
        .presetn(presetn),
        .paddr(paddr),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .secure_enable(secure_enable)
    );

    APBGlobalHistoryRegister u_apb_ghr (
        .pclk(pclk),
        .presetn(presetn),
        .paddr(paddr),
        .pselx(pselx),
        .penable(penable),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .history_shift_valid(history_shift_valid),
        .clk_gate_en(clk_gate_en),
        .secure_enable(secure_enable),
        .pready(pready),
        .prdata(prdata),
        .pslverr(pslverr),
        .history_full(history_full),
        .history_empty(history_empty),
        .error_flag(error_flag),
        .interrupt_full(interrupt_full),
        .interrupt_error(interrupt_error)
    );

endmodule
