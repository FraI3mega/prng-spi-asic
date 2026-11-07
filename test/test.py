# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles
import random


def xorshift16(state):
    state &= 0xFFFF
    state ^= (state << 7) & 0xFFFF
    state ^= (state >> 9) & 0xFFFF
    state ^= (state << 8) & 0xFFFF
    return state & 0xFFFF


CS, SCK, MOSI = 0, 1, 2

pins = 0b0000_0001  # idle: CS high, SCK low, MOSI low


def set_pin(dut, pin, value):
    global pins
    pins = (pins & ~(1 << pin)) | ((value & 1) << pin)
    dut.uio_in.value = pins


async def init(dut):
    dut._log.info("Initializing")
    clock = Clock(dut.clk, 62.5, unit="ns")  # 16MHz
    cocotb.start_soon(clock.start())
    dut._log.info("Resetting")
    dut.ena.value = 1
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    dut.uio_in.value = 0b0000_0001
    await ClockCycles(dut.clk, 5)
    dut._log.info("Init done")


async def exchange_byte(dut, byte, half_period=8):
    in_byte = 0
    for i in range(7, -1, -1):
        set_pin(dut, MOSI, (byte >> i) & 1)
        await ClockCycles(dut.clk, half_period)

        miso = dut.uio_out.value
        assert miso.is_resolvable, "MISO (uio_out) is X/Z"
        in_byte |= ((int(miso) >> 3) & 1) << i
        set_pin(dut, SCK, 1)
        await ClockCycles(dut.clk, half_period)
        set_pin(dut, SCK, 0)
    return in_byte


async def init_xor(dut, state):
    set_pin(dut, CS, 0)
    await ClockCycles(dut.clk, 5)

    await exchange_byte(dut, 0x02)
    await exchange_byte(dut, (state & 0xFF00) >> 8)
    await exchange_byte(dut, (state & 0xFF))

    await ClockCycles(dut.clk, 5)
    set_pin(dut, CS, 1)
    await ClockCycles(dut.clk, 10)
    assert dut.uio_out.value == 0x00

    set_pin(dut, CS, 0)
    await ClockCycles(dut.clk, 5)

    await exchange_byte(dut, 0x03)
    b1 = await exchange_byte(dut, 0x00)
    b2 = await exchange_byte(dut, 0x00)
    assert b1 << 8 | b2 == state


@cocotb.test()
async def test_reset(dut):
    await init(dut)
    assert dut.uio_out.value == 0x00


@cocotb.test()
async def test_spi_ping(dut):
    await init(dut)
    assert dut.uio_out.value == 0x00

    set_pin(dut, CS, 0)
    await ClockCycles(dut.clk, 5)
    out_byte1 = await exchange_byte(dut, 0x01)
    out_byte2 = await exchange_byte(dut, 0x00)
    dut._log.info("b1 %02x b2 %02x", out_byte1, out_byte2)
    assert out_byte2 == 0xAA

    await ClockCycles(dut.clk, 5)
    set_pin(dut, CS, 1)
    await ClockCycles(dut.clk, 5)
    dut._log.info("%02x", dut.uio_out.value)
    assert dut.uio_out.value == 0x00


@cocotb.test()
async def test_xorshift_init(dut):
    await init(dut)
    assert dut.uio_out.value == 0x00

    state = random.randint(0x0001, 0xFFFF)  # 0xAABB
    # init xorshift
    set_pin(dut, CS, 0)
    await ClockCycles(dut.clk, 5)

    await exchange_byte(dut, 0x02)
    await exchange_byte(dut, (state & 0xFF00) >> 8)
    await exchange_byte(dut, (state & 0xFF))

    await ClockCycles(dut.clk, 5)
    set_pin(dut, CS, 1)
    await ClockCycles(dut.clk, 10)
    assert dut.uio_out.value == 0x00

    set_pin(dut, CS, 0)
    await ClockCycles(dut.clk, 5)

    await exchange_byte(dut, 0x03)
    b1 = await exchange_byte(dut, 0x00)
    b2 = await exchange_byte(dut, 0x00)
    assert b1 << 8 | b2 == state

    await ClockCycles(dut.clk, 5)
    set_pin(dut, CS, 1)


@cocotb.test()
async def test_xorshift_interrupt_init(dut):
    await init(dut)
    assert dut.uio_out.value == 0x00

    state = random.randint(0x0001, 0xFFFF)  # 0xAABB
    # init xorshift
    await init_xor(dut, state)

    await exchange_byte(dut, 0x03)
    b1 = await exchange_byte(dut, 0x00)
    b2 = await exchange_byte(dut, 0x00)
    sent_state = b1 << 8 | b2

    state = xorshift16(state)
    assert sent_state == state

    # interrupt init
    set_pin(dut, CS, 0)
    await ClockCycles(dut.clk, 5)

    await exchange_byte(dut, 0x02)
    await exchange_byte(dut, (state & 0xFF00) >> 8)

    await ClockCycles(dut.clk, 5)
    set_pin(dut, CS, 1)
    await ClockCycles(dut.clk, 10)

    set_pin(dut, CS, 0)
    await ClockCycles(dut.clk, 5)

    await exchange_byte(dut, 0x03)
    b1 = await exchange_byte(dut, 0x00)
    b2 = await exchange_byte(dut, 0x00)
    sent_state = b1 << 8 | b2

    state = xorshift16(state)
    assert sent_state == state

    await ClockCycles(dut.clk, 5)
    set_pin(dut, CS, 1)


@cocotb.test()
async def test_xorshift_cycle(dut):
    await init(dut)
    assert dut.uio_out.value == 0x00

    state = random.randint(0x0001, 0xFFFF)  # 0xAABB
    # init xorshift
    await init_xor(dut, state)

    # query next
    await exchange_byte(dut, 0x03)
    b1 = await exchange_byte(dut, 0x00)
    b2 = await exchange_byte(dut, 0x00)
    sent_state = b1 << 8 | b2

    state = xorshift16(state)
    assert sent_state == state

    for i in range(20):
        await exchange_byte(dut, 0x03)
        b1 = await exchange_byte(dut, 0x00)
        b2 = await exchange_byte(dut, 0x00)
        sent_state = b1 << 8 | b2

        state = xorshift16(state)
        assert sent_state == state


# @cocotb.test()
# async def test_project(dut):
#     await init(dut)
#
#     # Reset
#     dut._log.info("Reset")
#     dut.ena.value = 1
#     dut.ui_in.value = 0xAA
#     dut.uio_in.value = 1
#     dut.rst_n.value = 0
#     await ClockCycles(dut.clk, 10)
#     dut.rst_n.value = 1
#     dut.uio_in.value = 0
#
#     dut._log.info("Correct after init")
#
#     await ClockCycles(dut.clk, 1)
#
#     assert dut.uo_out.value == 0xAA
#
#     dut._log.info("Correct after 1. cycle")
#     # Wait for one clock cycle to see the output values
#     await ClockCycles(dut.clk, 1)
#
#     state = xorshift16(state)
#     assert dut.uo_out.value == (state & 0x00FF)
#
#     for _ in range(100):
#         await ClockCycles(dut.clk, 1)
#         state = xorshift16(state)
#         assert dut.uo_out.value == (state & 0x00FF)
#
#     # Keep testing the module by changing the input values, waiting for
#     # one or more clock cycles, and asserting the expected output values.
