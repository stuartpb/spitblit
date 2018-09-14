--[[---
File:    drivers/ili9225.lua
From:    https://github.com/stuartpb/spitblit
Version: 0.0.0
Author:  Stuart P. Bentley <s@stuartpb.com>
License: MIT
---]]--

return function(pins)
  -- Register Select pin (aka Command/Data)
  local rs = pins.rs
  -- Chip Select pin
  local cs = pins.cs

  local setpin = gpio.write
  local LOW = gpio.LOW
  local HIGH = gpio.HIGH

  local spisend = spi.send

  local function setreg(reg, hibyte, lobyte)
    -- Select index register
    setpin(rs, LOW)
    -- Start first transfer
    setpin(cs, LOW)
    -- Send register index selection
    spisend(1, 0, reg)
    -- End first transfer
    setpin(cs, HIGH)

    -- Select data register
    setpin(rs, HIGH)
    -- Start second transfer
    setpin(cs, LOW)
    -- Send data bytes
    spisend(1, hibyte, lobyte)
    -- End second transfer
    setpin(cs, HIGH)
  end

  local screen = {}
  function screen:init()
    -- Use full frequency
    node.setcpufreq(node.CPU160MHZ)

    -- Set up SPI:
    spi.setup(
      -- HSPI in Master mode
      1, spi.MASTER,
      -- Clock polarity and phase low
      spi.CPOL_LOW, spi.CPHA_LOW,
      -- 8 bits per item, so we can transmit image data from strings
      -- (spi.send doesn't know how to send multiple characters at once)
      spi.DATABITS_8,
      -- Use a clock divider of 2
      -- (40MHz, only ~100 times faster than the maximum on the datasheet :P)
      2)

    -- Set our pins to output
    gpio.mode(rs, gpio.OUTPUT)
    gpio.mode(cs, gpio.OUTPUT)
    gpio.mode(pins.rst, gpio.OUTPUT)
    gpio.mode(pins.led, gpio.OUTPUT)

    -- Turn on the backlight
    setpin(pins.led, HIGH)

    -- Cycle the reset pin
    setpin(pins.rst, gpio.HIGH)
    tmr.delay(1)
    setpin(pins.rst, gpio.LOW)
    tmr.delay(10)
    setpin(pins.rst, gpio.HIGH)
    tmr.delay(50)

    -- Clear the power control registers (prep for power-on sequence)
    setreg(0x10, 0, 0)
    setreg(0x11, 0, 0)
    setreg(0x12, 0, 0)
    setreg(0x13, 0, 0)
    setreg(0x14, 0, 0)

    -- Give the power control registers a little time to set
    tmr.delay(40)

    -- Power-on sequence (see datasheet page 104, 13.4, Figure 42)

    -- Power Control 2 (see datasheet page 64, 8.2.13)
    -- 00: Leave boost circuits off
    -- 1: Generate unamplified voltage
    -- 8: Set boost converter voltage (VCI1) to 2.58 volts
    setreg(0x11, 0x00, 0x18)

    -- Power Control 3 (see datasheet page 65, 8.2.14)
    -- 6: Set the gate voltage multipliers to 6x (high) and -4x (low)
    -- 121: Operating frequencies for the driving circuits
    setreg(0x12, 0x61, 0x21)

    -- Power Control 4 (see datasheet page 67, 8.2.15)
    -- 6f (1101111): Set gamma voltage to 4.68 volts
    setreg(0x13, 0x00, 0x6f)

    -- Power Control 5 (see datasheet page 67, 8.2.16)
    -- 49: Set panel supply high voltage to 3.76V (4.68*(.4015+.0055*0x49))
    -- 5f: Set alternating amplitude to 4.72V (4.68*(.534+.006*(0x5f-16)))
    setreg(0x14, 0x49, 0x5f)

    -- Power Control 1 (see datasheet page 63, 8.2.12)
    -- 8: Set driving capability to Medium Fast 1
    setreg(0x10, 0x08, 0x00)

    -- Give these settings time to propagate
    tmr.delay(10)

    -- Power Control 2 again:
    -- 10 (APON): Automatically start the boost circuits
    -- 3: Generate amplified voltage
    -- b: Set boost converter voltage (VCI1) to 2.76 volts
    setreg(0x11, 0x10, 0x3b)

    -- Wait for boost circuits to do their thing
    tmr.delay(50)

    -- Rest of registers

    -- Driver Output Control (see datasheet page 51, 8.2.4)
    -- 0: Normal polarity
    -- 1 (SS): Reverse line order, for some reason
    -- 1c: Drive all 220 lines of the screen
    setreg(0x01, 0x01, 0x1c)

    -- LCD Driving Waveform Control (see datasheet page 54, 8.2.5)
    -- 0100: Single-line inversion (see http://www.techmind.org/lcd/)
    setreg(0x02, 0x01, 0x00)

    -- Entry Mode (see datasheet page 56, 8.2.6)
    -- 10 (BGR): Swap Blue and Red channels (RGB, after SS line order reverse)
    -- 3: Increase addresses both horizontally and vertically
    -- 0: Horizontal address orientation
    setreg(0x03, 0x10, 0x30)

    -- Display Control 1 (see datasheet page 58, 8.2.7)
    -- 0000: Display off (we'll turn it on later)
    setreg(0x07, 0x00, 0x00)

    -- Display Control 2 (see datasheet page 59, 8.2.8)
    -- (The instruction table refers to this as "Blank Period Control 1")
    -- 08: 8 lines of front porch
    -- 08: 8 lines of back porch
    setreg(0x08, 0x08, 0x08)

    -- Frame Cycle Control (see datasheet page 60, 8.2.9)
    -- 1: 8 clock cycle gate delay
    -- 1: 8 clock cycle source delay
    -- 00: 16 clock cycles per line
    setreg(0x0b, 0x11, 0x00)

    -- RGB Input Interface Control 1 (see datasheet page 61, 8.2.10)
    -- 0000: We don't use the RGB Input Interface so this doesn't matter
    setreg(0x0c, 0x00, 0x00)

    -- Oscillator Control (see datasheet page 62, 8.2.11)
    -- 0d (1101): Oscillate at 444.4KHz
    -- 01: Enable oscillator
    setreg(0x0f, 0x0d, 0x01)

    -- VCI Recycling (see datasheet page 68, 8.2.17)
    -- 0020: 2 clock cycles (for what? I can't even tell)
    setreg(0x15, 0x00, 0x20)

    -- RAM Address Set (see datasheet page 69, 8.2.18)
    -- Start at 0x0000 by setting the high and low addresses to 0
    setreg(0x20, 0x00, 0x00)
    setreg(0x21, 0x00, 0x00)

    -- Gate Scan Control (see datasheet page 70, 8.2.22)
    -- 0000: start scanning from gate 1
    setreg(0x30, 0x00, 0x00)

    -- Vertical Scroll Control (see datasheet pages 71-72, 8.2.23-8.2.24)
    -- (The numbering for these in section headings is messed up)
    -- db: If we vertically scroll, do the whole screen
    setreg(0x31, 0x00, 0xdb)
    setreg(0x32, 0x00, 0x00)
    setreg(0x33, 0x00, 0x00)

    -- Partial Screen Driving Position (see datasheet page 72, 8.2.25)
    -- db: Set partial driving to end at the last line
    -- (the datasheet says not to do this if you're not using it but whatever)
    setreg(0x34, 0x00, 0xdb)
    setreg(0x35, 0x00, 0x00)

    -- Horizontal and Vertical RAM Address Position
    -- (see datasheet page 74, 8.2.26)
    -- Set the window to the entire extents of the screen
    setreg(0x36, 0x00, 0xaf)
    setreg(0x37, 0x00, 0x00)
    setreg(0x38, 0x00, 0xdb)
    setreg(0x39, 0x00, 0x00)

    -- Gamma Control (see datasheet page 75, 8.2.27)
    -- (see also Gamma Correction, datasheet page 83, section 12)
    -- Set gamma fine adjustment for positive polarity output to 0x8a8800
    setreg(0x50, 0x00, 0x00)
    setreg(0x51, 0x08, 0x08)
    setreg(0x52, 0x08, 0x0a)
    -- Set gradient adjustment for positive polarity output to 0x0a
    setreg(0x53, 0x00, 0x0a)
    -- Set gamma fine adjustment for negative polarity output to 0x0088a8
    setreg(0x54, 0x0a, 0x08)
    setreg(0x55, 0x08, 0x08)
    setreg(0x56, 0x00, 0x00)
    -- Set gradient adjustment for negative polarity output to 0xa0
    setreg(0x57, 0x0a, 0x00)
    -- Set amplitude adjustment for positive polarity output to 0x710
    setreg(0x58, 0x07, 0x10)
    -- Set amplitude adjustment for negative polarity output to 0x710
    setreg(0x59, 0x07, 0x10)

    -- Display Control 1 again:
    -- 12: Ready the display to operate, but don't turn on
    setreg(0x07, 0x00, 0x12)
    -- Wait for the display operation to ready
    tmr.delay(50)
    -- 10: Enable tearing mitigation (frame sync)
    -- 17: Turn display on (and invert grayscale?)
    setreg(0x07, 0x10, 0x17)
  end
  function screen:fill(...)
    -- Select index register
    setpin(rs, LOW)
    -- Start first transfer
    setpin(cs, LOW)
    -- Send register index selection
    spisend(1, 0, 0x22)
    -- End first transfer
    setpin(cs, HIGH)

    -- Select data register
    setpin(rs, HIGH)
    -- Start second transfer
    setpin(cs, LOW)
    -- Send data bytes
    spisend(1, ...)
    -- End second transfer
    setpin(cs, HIGH)
  end
  function screen:jump(h, v)
    setreg(0x20, 0x00, h)
    setreg(0x21, 0x00, v)
  end
  function screen:window(x0, x1, y0, y1, landscape)
    local modelo = landscape and 8 or 0
    if x1 < x0 then
      x0, x1 = x1, x0
      modelo = modelo + 0x10
    end
    if y1 < y0 then
      y0, y1 = y1, y0
      modelo = modelo + 0x20
    end

    -- Set window extents
    setreg(0x36, 0x00, x1)
    setreg(0x37, 0x00, x0)
    setreg(0x38, 0x00, y1)
    setreg(0x39, 0x00, y0)

    -- Set entry mode
    setreg(0x03, 0x10, modelo)
  end
  return screen
end
