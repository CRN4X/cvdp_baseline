module cocotb_iverilog_dump();
initial begin
    string dumpfile_path;    if ($value$plusargs("dumpfile_path=%s", dumpfile_path)) begin
        $dumpfile(dumpfile_path);
    end else begin
        $dumpfile("/code/rundir/sim_build/spi_complex_mult.fst");
    end
    $dumpvars(0, spi_complex_mult);
end
endmodule
