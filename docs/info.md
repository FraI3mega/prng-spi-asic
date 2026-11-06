<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

The module has an internal 16-bit xorshift prng, accessible over spi.

## How to test

Connect to the chip according to the provided pinout. Afterwards initialize the PRNG with a 2-byte seed. The next query of the state should return the initial state.

### Command Table

| Command | Arguments | Description |
| --------------- | --------------- | --------------- |
| 0x01 | None | Communication test, should return 0xAA |
| 0x02 | 2-byte seed | Initializes the generator with the provided seed |
| 0x03 | None | Sends back 2-byte PRNG state |

## External hardware

Requires an SPI Master connected on the defined pins.
