# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


def xorshift16(state):
    state &= 0xFFFF
    state ^= (state << 7) & 0xFFFF
    state ^= (state >> 9) & 0xFFFF
    state ^= (state << 8) & 0xFFFF
    return state & 0xFFFF


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    state = 0x00AA

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0xAA
    dut.uio_in.value = 1
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    dut.uio_in.value = 0

    dut._log.info("Correct after init")

    await ClockCycles(dut.clk, 1)

    assert dut.uo_out.value == 0xAA


    dut._log.info("Correct after 1. cycle")
    # Wait for one clock cycle to see the output values
    await ClockCycles(dut.clk, 1)

    state = xorshift16(state)
    assert dut.uo_out.value == (state & 0x00FF)


    for _ in range(100):
        await ClockCycles(dut.clk, 1)
        state = xorshift16(state)
        assert dut.uo_out.value == (state & 0x00FF)




    # Keep testing the module by changing the input values, waiting for
    # one or more clock cycles, and asserting the expected output values.
