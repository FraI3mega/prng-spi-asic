#import "@preview/abbr:0.3.1"

#show heading: set text(font: "IBM Plex Sans")
#set text(font: "IBM Plex Sans")
#show raw: set text(font: "IBM Plex Mono")
#show link: set text(fill: blue.darken(10%))

#show: abbr.show-rule
#abbr.make(
  ("ASIC", "Application-specific integrated circuit"),
  ("FPGA", "Field-programmable gate array"),
  ("PRNG", "Pseudo Random Number Generator"),
  ("SPI", "Serial Peripheral Interface"),
  ("HDL", "Hardware Description Language"),
)

#set document(
  title: [@PRNG:s over @SPI:s in Silicon – Or Making My First @ASIC:s],
  author: "FraI3mega",
  date: datetime(year: 2026, month: 11, day:8),
)
#title()
November 2026

#image("render.png")


#outline()

= It's _relatively_ easy
I want to start off by saying, that if at any point reading this,
you think of trying this out yourself, please do.
Even if you don't plan to spend money on tapeout, doing it digitally is a lot of fun
and you can always put it on an @FPGA:s.
Getting started is way easier than it may seem and the best way to learn is to try it out.
You can find a list resources at the end of the write-up.

= What does @ASIC even mean

An @ASIC:l is basically a chip made to do a specific thing, and do it well.
An example could be a the switching chip in a network switch or the controller in your SSD.
When making them, you first design them digitally, but since you only get one chance with the
real design we need a way to test them out in the real world.
This is where @FPGA:pla come in, you can think of them as reconfigurable chips,
where using code, you can define what they do. If you want to learn more, check out
#link("https://tinytapeout.com/making_asics/")[Tiny Tapeout]

= What I Made
My design contains a 16-bit xorshift @PRNG, with which you can interface over the @SPI bus.
The design has been made to run at 16MHz, with the bus at 1MHz.

= How To Use It

== Commands
The device supports 3 commands:
#table(
  columns: (auto, auto, auto, auto),
  align: center,
  table.header([*Command*], [*Input*], [*Output*], [*Description*]),
  [`0x01`], [---], [`0xAA`], [A basic ping, returns `0xAA` on next byte],
  [`0x02`], [2-byte seed], [---], [Initializes the @PRNG with the given seed],
  [`0x03`], [---], [2-byte state], [Outputs the @PRNG state on the next 2 bytes ],
)

== Initialization
Since reset is inverted, you need to pull it down for at least 5 clock cycles.
Afterwords pull it up, and wait for another 5 cycles.
You can test communication using the `0x01` command.
Next, yous should initialize the @PRNG using the `0x02` command, the seed cannot be equal to `0x00`.
On the next read using the `0x03` command,
the returned state should be equal to the value used to initialize the generator.

== Usage
You can read out the state using `0x03`, the internal state advances only after read.

= Implementation

== xorshift16
The @PRNG that I chose for this project it the standard xorshift based on a 16-bit state.
The only downside of this implementation, is that if the generator is initialized with all zeros,
the output will be stuck at that.

```sv

module xorshift16 (
    input logic [15:0] initial_state,
    input wire initialize,
    input wire clk,
    input logic step,
    output logic [15:0] state
);

  always @(posedge clk) begin
    if (initialize) begin
      state <= initial_state;
    end else if (step) begin
      logic [15:0] next_state;
      next_state = state;
      next_state ^= next_state << 7;
      next_state ^= next_state >> 9;
      next_state ^= next_state << 8;
      state <= next_state;
    end
  end

endmodule
```
I choose to only step on read, to make debugging the chip easier.
Without it, changes in the time between reads, would yield diffrent results.
This eliminates this problem, and makes it deterministic.

== @SPI interface

My implementation is mostly based on the one found on #link("https://www.fpga4fun.com/SPI.html")[fpga4fun], with some changes to support commands.
As such I will only discuss the parts I changed. I've stripped the code just to the interesting stuff.

```sv
  logic [15:0] data_to_send;
  logic [ 7:0] byte_data_sent;
  logic [ 1:0] await_bytes;

  always_ff @(posedge clk) begin
    step <= 1'b0;
    initialize <= 0;
    if (byte_received) begin
    // Byte received
    end else if (CS_active) begin
      // CS is active
    end else if (CS_endmessage) begin
      byte_data_sent <= 8'b0;
      data_to_send <= 16'b0;
      await_bytes <= 0;
    end
  end
```
The last if statement makes sure to clean the data, if the master decides to cut communication early,
this resets it to a known state. Also resetting step and initialize at the start,
was the best way I could come up with.


=== Byte received

```sv
  if (byte_received) begin
    if (await_bytes > 0) begin
      initial_state <= {initial_state[7:0], byte_data_received};
      initialize <= await_bytes == 2'd1;
      await_bytes <= await_bytes - 2'b01;
    end else begin
      case (byte_data_received)
        8'h01:   data_to_send <= 16'hAA00;
        8'h02:   await_bytes <= 2'b10;
        8'h03: begin
          step <= 1'd1;
          data_to_send <= state;
        end``
        default: ;
      endcase
    end
  end
```
Every received byte, we first check if we're waiting for any incoming as data,
if that's the case, we prepare for initializing the @PRNG with it.
Else, the byte is compared to known commands, which decide on the next action.


=== CS is active

```sv
  if (CS_active) begin
    if (SCK_fallingedge) begin
      if (bitcnt == 3'b000) begin
        byte_data_sent <= data_to_send[15:8];  // after that, we send 0s
        data_to_send   <= data_to_send << 8;
      end else byte_data_sent <= {byte_data_sent[6:0], 1'b0};
    end
  end
```

If we hadn't received a byte on this clock cycle, the system sends a bit out on the falling edge of the SPI clock.

= But Why

I'd heard about @FPGA:pls some time ago, but I've always thought that they were way too hard.
I'd also seen some videos on tiny tapeout a year ago, and even did their silwiz tutorial,
but still decided not to pursue it further.
This time after hearing about the asic YSWS from Hack Club, I decided to finally try it.
Looking back at this project, it was way easier than it seemed, and the resources online are pretty great.

= What I Learned And What To Do Differently
For my next project, having a clear idea what to make, as well as taking notes should make it easier.
Making a proper testing harness also would make the process way more dependable.

= Okay, I Also Want To Start
I would recommend that you start off with learning an @HDL, Verilog (specifically SystemVerilog) is a good choice.
For learning it #link("https://hdlbits.01xz.net/wiki/Problem_sets#Getting_Started")[HDLBits] is a great resource.
If you want to learn digital logic #link("https://nandgame.com/")[Nandgame] is a great way to go from making logic gates, to your own cpu.


= Additional resources
- https://chipverify.com/
- https://tinytapeout.com/siliwiz/introduction/
- https://www.youtube.com/watch?v=q6ytRHaTEXI
- https://github.com/TinyTapeout/ttgf-verilog-template
- https://www.youtube.com/watch?v=DdF_nzMW_i8
- https://essenceia.github.io/
- https://fpgacpu.ca/fpga/index.html
- https://verilogguide.readthedocs.io/en/latest/index.html
- https://www.asic-world.com/systemverilog/index.html

#abbr.list()
