module cocotb_iverilog_dump();
initial begin
    string dumpfile_path;    if ($value$plusargs("dumpfile_path=%s", dumpfile_path)) begin
        $dumpfile(dumpfile_path);
    end else begin
        $dumpfile("/code/rundir/sim_build/cic_decimator.fst");
    end
    $dumpvars(0, cic_decimator);
end
endmodule
