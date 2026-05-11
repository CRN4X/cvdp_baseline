module cocotb_iverilog_dump();
initial begin
    string dumpfile_path;    if ($value$plusargs("dumpfile_path=%s", dumpfile_path)) begin
        $dumpfile(dumpfile_path);
    end else begin
        $dumpfile("/home/snuc/Study/agents_for_chip_design/Agents-for-Chip-Design-Automation/baseline_NVIDIA-ICLAD25-Hackathon-main/work/cvdp_agentic_sunrise_ivory_glacier/harness/9089/rundir/sim_build/delete_node_binary_search_tree.fst");
    end
    $dumpvars(0, delete_node_binary_search_tree);
end
endmodule
