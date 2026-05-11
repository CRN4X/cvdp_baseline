module cocotb_iverilog_dump();
initial begin
    string dumpfile_path;    if ($value$plusargs("dumpfile_path=%s", dumpfile_path)) begin
        $dumpfile(dumpfile_path);
    end else begin
        $dumpfile("/home/snuc/Study/agents_for_chip_design/Agents-for-Chip-Design-Automation/baseline_NVIDIA-ICLAD25-Hackathon-main/work/cvdp_agentic_falcon_willow_dragon/harness/8753/rundir/sim_build/APBGlobalHistoryRegister_secure_top.fst");
    end
    $dumpvars(0, APBGlobalHistoryRegister_secure_top);
end
endmodule
