module cocotb_iverilog_dump();
initial begin
    string dumpfile_path;    if ($value$plusargs("dumpfile_path=%s", dumpfile_path)) begin
        $dumpfile(dumpfile_path);
    end else begin
        $dumpfile("/home/snuc/Study/agents_for_chip_design/Agents-for-Chip-Design-Automation/baseline_NVIDIA-ICLAD25-Hackathon-main/work/cvdp_agentic_garden_sapphire_amber/harness/307/rundir/sim_build/event_scheduler.fst");
    end
    $dumpvars(0, event_scheduler);
end
endmodule
