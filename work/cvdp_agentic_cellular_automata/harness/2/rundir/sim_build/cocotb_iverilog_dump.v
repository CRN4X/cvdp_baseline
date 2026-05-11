module cocotb_iverilog_dump();
initial begin
    string dumpfile_path;    if ($value$plusargs("dumpfile_path=%s", dumpfile_path)) begin
        $dumpfile(dumpfile_path);
    end else begin
        $dumpfile("/home/snuc/Study/agents_for_chip_design/Agents-for-Chip-Design-Automation/baseline_NVIDIA-ICLAD25-Hackathon-main/work/cvdp_agentic_cellular_automata/harness/2/rundir/sim_build/pseudoRandGenerator_ca.fst");
    end
    $dumpvars(0, pseudoRandGenerator_ca);
end
endmodule
