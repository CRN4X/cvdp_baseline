module cocotb_iverilog_dump();
initial begin
    string dumpfile_path;    if ($value$plusargs("dumpfile_path=%s", dumpfile_path)) begin
        $dumpfile(dumpfile_path);
    end else begin
        $dumpfile("/home/snuc/Study/agents_for_chip_design/Agents-for-Chip-Design-Automation/baseline_NVIDIA-ICLAD25-Hackathon-main/work/cvdp_agentic_comet_cloud_tiger/harness/9313/rundir/sim_build/rc5_enc_16bit.fst");
    end
    $dumpvars(0, rc5_enc_16bit);
end
endmodule
