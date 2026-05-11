import cocotb
from cocotb.triggers import Timer

async def clock_gen(dut):
    """Simple clock generator: toggles every 5 ns (10 ns period)."""
    while True:
        dut.clk.value = 0
        await Timer(5, unit="ns")
        dut.clk.value = 1
        await Timer(5, unit="ns")

@cocotb.test()
async def fsm_test(dut):
    """Cocotb testbench for dynamic FSM with assertions mimicking the provided SV testbench."""
    # Start the clock generator.
    cocotb.start_soon(clock_gen(dut))
    
    # Initialize configuration maps.
    # The state map packs 8 entries (state0..state7) of 8 bits each.
    # For example: state0 = 0x10, state1 = 0x20, ..., state7 = 0x80.
    dut.config_state_map_flat.value = 0x8070605040302010

    # For the transition map: 16 entries (8 bits each) for state 0.
    # Rightmost (element0): input_signal==0 => 0.
    # Element4 is set to 8 (invalid, to trigger error) and the rest are 0.
    # This 128-bit constant is represented in hexadecimal.
    dut.config_transition_map_flat.value = int("00000000000000000000000800000000", 16)
    
    # Apply reset: drive reset high for 12 ns, then low.
    dut.reset.value = 1
    dut.input_signal.value = 0
    await Timer(12, unit="ns")
    dut.reset.value = 0
    await Timer(10, unit="ns")
    
    # Test with input_signal = 1.
    dut.input_signal.value = 1
    await Timer(10, unit="ns")
    dut._log.info(
        f"Test 1: encoded_state = {int(dut.encoded_state.value):02x}, "
        f"dynamic_encoded_state = {int(dut.dynamic_encoded_state.value):02x}, "
        f"error_flag = {int(dut.error_flag.value)}, "
        f"operation_result = {int(dut.operation_result.value)}"
    )
    # Assertions for Test 1.
    assert int(dut.encoded_state.value) == 0x10, \
        f"Test 1: Expected encoded_state 0x10, got {int(dut.encoded_state.value):02x}"
    assert int(dut.dynamic_encoded_state.value) == 0x11, \
        f"Test 1: Expected dynamic_encoded_state 0x11, got {int(dut.dynamic_encoded_state.value):02x}"
    assert int(dut.error_flag.value) == 0, \
        f"Test 1: Expected error_flag 0, got {int(dut.error_flag.value)}"
    assert int(dut.operation_result.value) == 17, \
        f"Test 1: Expected operation_result 17, got {int(dut.operation_result.value)}"
    
    # Test with input_signal = 2.
    dut.input_signal.value = 2
    await Timer(10, unit="ns")
    dut._log.info(
        f"Test 2: encoded_state = {int(dut.encoded_state.value):02x}, "
        f"dynamic_encoded_state = {int(dut.dynamic_encoded_state.value):02x}, "
        f"error_flag = {int(dut.error_flag.value)}, "
        f"operation_result = {int(dut.operation_result.value)}"
    )
    # Assertions for Test 2.
    assert int(dut.encoded_state.value) == 0x10, \
        f"Test 2: Expected encoded_state 0x10, got {int(dut.encoded_state.value):02x}"
    assert int(dut.dynamic_encoded_state.value) == 0x12, \
        f"Test 2: Expected dynamic_encoded_state 0x12, got {int(dut.dynamic_encoded_state.value):02x}"
    assert int(dut.error_flag.value) == 0, \
        f"Test 2: Expected error_flag 0, got {int(dut.error_flag.value)}"
    assert int(dut.operation_result.value) == 18, \
        f"Test 2: Expected operation_result 18, got {int(dut.operation_result.value)}"
    
    # Test with input_signal = 3.
    dut.input_signal.value = 3
    await Timer(10, unit="ns")
    dut._log.info(
        f"Test 3: encoded_state = {int(dut.encoded_state.value):02x}, "
        f"dynamic_encoded_state = {int(dut.dynamic_encoded_state.value):02x}, "
        f"error_flag = {int(dut.error_flag.value)}, "
        f"operation_result = {int(dut.operation_result.value)}"
    )
    # Assertions for Test 3.
    assert int(dut.encoded_state.value) == 0x10, \
        f"Test 3: Expected encoded_state 0x10, got {int(dut.encoded_state.value):02x}"
    assert int(dut.dynamic_encoded_state.value) == 0x13, \
        f"Test 3: Expected dynamic_encoded_state 0x13, got {int(dut.dynamic_encoded_state.value):02x}"
    assert int(dut.error_flag.value) == 0, \
        f"Test 3: Expected error_flag 0, got {int(dut.error_flag.value)}"
    assert int(dut.operation_result.value) == 19, \
        f"Test 3: Expected operation_result 19, got {int(dut.operation_result.value)}"
    
    # Test error condition with input_signal = 4.
    dut.input_signal.value = 4
    await Timer(10, unit="ns")
    dut._log.info(
        f"Test 4 (error): encoded_state = {int(dut.encoded_state.value):02x}, "
        f"dynamic_encoded_state = {int(dut.dynamic_encoded_state.value):02x}, "
        f"error_flag = {int(dut.error_flag.value)}, "
        f"operation_result = {int(dut.operation_result.value)}"
    )
    # Assertions for Test 4.
    assert int(dut.encoded_state.value) == 0x10, \
        f"Test 4: Expected encoded_state 0x10, got {int(dut.encoded_state.value):02x}"
    assert int(dut.dynamic_encoded_state.value) == 0x14, \
        f"Test 4: Expected dynamic_encoded_state 0x14, got {int(dut.dynamic_encoded_state.value):02x}"
    assert int(dut.error_flag.value) == 1, \
        f"Test 4: Expected error_flag 1, got {int(dut.error_flag.value)}"
    assert int(dut.operation_result.value) == 20, \
        f"Test 4: Expected operation_result 20, got {int(dut.operation_result.value)}"
    
    # Return to a valid input: input_signal = 0.
    dut.input_signal.value = 0
    await Timer(10, unit="ns")
    dut._log.info(
        f"Test 5: encoded_state = {int(dut.encoded_state.value):02x}, "
        f"dynamic_encoded_state = {int(dut.dynamic_encoded_state.value):02x}, "
        f"error_flag = {int(dut.error_flag.value)}, "
        f"operation_result = {int(dut.operation_result.value)}"
    )
    # Assertions for Test 5.
    assert int(dut.encoded_state.value) == 0x10, \
        f"Test 5: Expected encoded_state 0x10, got {int(dut.encoded_state.value):02x}"
    assert int(dut.dynamic_encoded_state.value) == 0x10, \
        f"Test 5: Expected dynamic_encoded_state 0x10, got {int(dut.dynamic_encoded_state.value):02x}"
    assert int(dut.error_flag.value) == 0, \
        f"Test 5: Expected error_flag 0, got {int(dut.error_flag.value)}"
    assert int(dut.operation_result.value) == 16, \
        f"Test 5: Expected operation_result 16, got {int(dut.operation_result.value)}"

