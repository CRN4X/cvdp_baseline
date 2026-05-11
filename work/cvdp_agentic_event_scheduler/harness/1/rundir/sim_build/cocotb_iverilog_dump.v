module cocotb_iverilog_dump();
initial begin
    string dumpfile_path;    if ($value$plusargs("dumpfile_path=%s", dumpfile_path)) begin
        $dumpfile(dumpfile_path);
    end else begin
        $dumpfile("/code/rundir/sim_build/event_scheduler.fst");
    end
    $dumpvars(0, event_scheduler);
end
endmodule
