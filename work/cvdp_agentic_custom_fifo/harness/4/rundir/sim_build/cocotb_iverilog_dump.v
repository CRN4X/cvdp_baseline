module cocotb_iverilog_dump();
initial begin
    string dumpfile_path;    if ($value$plusargs("dumpfile_path=%s", dumpfile_path)) begin
        $dumpfile(dumpfile_path);
    end else begin
        $dumpfile("/code/rundir/sim_build/fifo_buffer.fst");
    end
    $dumpvars(0, fifo_buffer);
end
endmodule
