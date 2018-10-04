--[[---
File:    drivers/ili9225.lua
From:    https://github.com/stuartpb/spitblit
Version: 0.1.0
Author:  Stuart P. Bentley <s@stuartpb.com>
License: MIT
---]]--

return function(screen)
  screen = screen or {}
  screen.pins = screen.pins or {}
  screen.pins.rs = screen.pins.rs or 2 -- GPIO4
  screen.pins.cs = screen.pins.cs or 8 -- GPIO15
  screen.pins.rst = screen.pins.rst or 4 -- GPIO2
  screen.pins.led = screen.pins.led or 1 -- GPIO5

  if screen.cpufreq == nil then
    screen.cpufreq = node.CPU160MHZ
  end

  -- fixed specifications
  screen.width = 176
  screen.height = 220

  screen.bpc = 'r5g6b5'

  -- methods
  function screen:initspi(opts)

    -- Use full frequency
    if self.cpufreq then node.setcpufreq(self.cpufreq) end

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
      self.clock_div or 2)
  end

  function screen:initgpio()
    -- Set our pins to output

    -- Register Select pin (aka Command/Data)
    gpio.mode(self.pins.rs, gpio.OUTPUT)
    -- Chip Select pin
    gpio.mode(self.pins.cs, gpio.OUTPUT)
    -- Reset pin
    gpio.mode(self.pins.rst, gpio.OUTPUT)
    -- LED backlight pin
    gpio.mode(self.pins.led, gpio.OUTPUT)
  end

  function screen:setreg(bytes)
    local spisend = spi.send
    local gpiowrite = gpio.write
    local LOW = gpio.LOW
    local HIGH = gpio.HIGH

    local rs = self.pins.rs

    -- Select chip
    gpiowrite(self.pins.cs, LOW)

    for i = 1, #bytes, 3 do
      -- Select index register
      gpiowrite(rs, LOW)
      -- Send register index selection
      spisend(1, 0, bytes[i])

      -- Select data register
      gpiowrite(rs, HIGH)
      -- Send data bytes
      spisend(1, bytes[i + 1], bytes[i + 2])
    end

    -- Deselect chip
    gpiowrite(self.pins.cs, HIGH)
  end

  function screen:light(setting)
    if setting == 0 or setting == false or setting == gpio.LOW then
      setting = gpio.LOW
    else
      setting = gpio.HIGH
    end

    gpio.write(self.pins.led, setting)
  end

  function screen:init()
    self:initspi()
    self:initgpio()
    self:light(1)

    -- Cycle the reset pin
    gpio.write(self.pins.rst, gpio.HIGH)
    tmr.delay(1)
    gpio.write(self.pins.rst, gpio.LOW)
    tmr.delay(10)
    gpio.write(self.pins.rst, gpio.HIGH)
    tmr.delay(50)

    -- Clear the power control registers (prep for power-on sequence)
    self:setreg{
      0x10, 0, 0,
      0x11, 0, 0,
      0x12, 0, 0,
      0x13, 0, 0,
      0x14, 0, 0
    }

    -- Give the power control registers a little time to set
    tmr.delay(40)

    -- Power-on sequence (see datasheet page 104, 13.4, Figure 42)

    self:setreg{
    -- Power Control 2 (see datasheet page 64, 8.2.13)
    -- 00: Leave boost circuits off
    -- 1: Generate unamplified voltage
    -- 8: Set boost converter voltage (VCI1) to 2.58 volts
      0x11, 0x00, 0x18,

    -- Power Control 3 (see datasheet page 65, 8.2.14)
    -- 6: Set the gate voltage multipliers to 6x (high) and -4x (low)
    -- 121: Operating frequencies for the driving circuits
      0x12, 0x61, 0x21,

    -- Power Control 4 (see datasheet page 67, 8.2.15)
    -- 6f (1101111): Set gamma voltage to 4.68 volts
      0x13, 0x00, 0x6f,

    -- Power Control 5 (see datasheet page 67, 8.2.16)
    -- 49: Set panel supply high voltage to 3.76V (4.68*(.4015+.0055*0x49))
    -- 5f: Set alternating amplitude to 4.72V (4.68*(.534+.006*(0x5f-16)))
      0x14, 0x49, 0x5f,

    -- Power Control 1 (see datasheet page 63, 8.2.12)
    -- 8: Set driving capability to Medium Fast 1
      0x10, 0x08, 0x00
    }
    -- Give these settings time to propagate
    tmr.delay(10)

    -- Power Control 2 again:
    -- 10 (APON): Automatically start the boost circuits
    -- 3: Generate amplified voltage
    -- b: Set boost converter voltage (VCI1) to 2.76 volts
    self:setreg{0x11, 0x10, 0x3b}

    -- Wait for boost circuits to do their thing
    tmr.delay(50)

    -- Rest of registers

    self:setreg{
    -- Driver Output Control (see datasheet page 51, 8.2.4)
    -- 0: Normal polarity
    -- 1 (SS): Count X coordinates left-to-right
    -- 1c: Drive all 220 lines of the screen
      0x01, 0x01, 0x1c,

    -- LCD Driving Waveform Control (see datasheet page 54, 8.2.5)
    -- 0100: Single-line inversion (see http://www.techmind.org/lcd/)
      0x02, 0x01, 0x00,

    -- Entry Mode (see datasheet page 56, 8.2.6)
    -- 10 (BGR): Read in RGB order
    -- (in testing, 0 caused colors to read in BGR order, regardless of SS)
    -- 3: Increase addresses both horizontally and vertically
    -- 0: Portrait traversal (increment X addr to end before doing Y)
      0x03, 0x10, 0x30,

    -- Display Control 1 (see datasheet page 58, 8.2.7)
    -- 0000: Display off (we'll turn it on later)
      0x07, 0x00, 0x00,

    -- Display Control 2 (see datasheet page 59, 8.2.8)
    -- (The instruction table refers to this as "Blank Period Control 1")
    -- 08: 8 lines of front porch
    -- 08: 8 lines of back porch
      0x08, 0x08, 0x08,

    -- Frame Cycle Control (see datasheet page 60, 8.2.9)
    -- 1: 8 clock cycle gate delay
    -- 1: 8 clock cycle source delay
    -- 00: 16 clock cycles per line
      0x0b, 0x11, 0x00,

    -- RGB Input Interface Control 1 (see datasheet page 61, 8.2.10)
    -- 0000: We don't use the RGB Input Interface so this doesn't matter
      0x0c, 0x00, 0x00,

    -- Oscillator Control (see datasheet page 62, 8.2.11)
    -- 0d (1101): Oscillate at 444.4KHz
    -- 01: Enable oscillator
      0x0f, 0x0d, 0x01,

    -- VCI Recycling (see datasheet page 68, 8.2.17)
    -- 0020: 2 clock cycles (for what? I can't even tell)
      0x15, 0x00, 0x20,

    -- RAM Address Set (see datasheet page 69, 8.2.18)
    -- Start at 0x0000 by setting the high and low addresses to 0
      0x20, 0x00, 0x00,
      0x21, 0x00, 0x00,

    -- Gate Scan Control (see datasheet page 70, 8.2.22)
    -- 0000: start scanning from gate 1
      0x30, 0x00, 0x00,

    -- Vertical Scroll Control (see datasheet pages 71-72, 8.2.23-8.2.24)
    -- (The numbering for these in section headings is messed up)
    -- db: If we vertically scroll, do the whole screen
      0x31, 0x00, 0xdb,
      0x32, 0x00, 0x00,
      0x33, 0x00, 0x00,

    -- Partial Screen Driving Position (see datasheet page 72, 8.2.25)
    -- db: Set partial driving to end at the last line
    -- (the datasheet says not to do this if you're not using it but whatever)
      0x34, 0x00, 0xdb,
      0x35, 0x00, 0x00,

    -- Horizontal and Vertical RAM Address Position
    -- (see datasheet page 74, 8.2.26)
    -- Set the window to the entire extents of the screen
      0x36, 0x00, 0xaf,
      0x37, 0x00, 0x00,
      0x38, 0x00, 0xdb,
      0x39, 0x00, 0x00,

    -- Gamma Control (see datasheet page 75, 8.2.27)
    -- (see also Gamma Correction, datasheet page 83, section 12)
    -- Set gamma fine adjustment for positive polarity output to 0x8a8800
      0x50, 0x00, 0x00,
      0x51, 0x08, 0x08,
      0x52, 0x08, 0x0a,
    -- Set gradient adjustment for positive polarity output to 0x0a
      0x53, 0x00, 0x0a,
    -- Set gamma fine adjustment for negative polarity output to 0x0088a8
      0x54, 0x0a, 0x08,
      0x55, 0x08, 0x08,
      0x56, 0x00, 0x00,
    -- Set gradient adjustment for negative polarity output to 0xa0
      0x57, 0x0a, 0x00,
    -- Set amplitude adjustment for positive polarity output to 0x710
      0x58, 0x07, 0x10,
    -- Set amplitude adjustment for negative polarity output to 0x710
      0x59, 0x07, 0x10,

    -- Display Control 1 again:
    -- 12: Ready the display to operate, but don't turn on
      0x07, 0x00, 0x12
    }
    -- Wait for the display operation to ready
    tmr.delay(50)
    -- 10: Enable tearing mitigation (frame sync)
    -- 17: Turn display on (and invert grayscale?)
    self:setreg{0x07, 0x10, 0x17}
  end

  function screen:fill(...)
    -- Select index register
    gpio.write(self.pins.rs, gpio.LOW)
    -- Select chip
    gpio.write(self.pins.cs, gpio.LOW)
    -- Send register index selection
    spi.send(1, 0, 0x22)

    -- Select data register
    gpio.write(self.pins.rs, gpio.HIGH)
    -- Send data bytes
    spi.send(1, ...)
    -- Deselect chip
    gpio.write(self.pins.cs, gpio.HIGH)
  end

  function screen:jump(x, y)
    self:setreg{
      0x20, 0x00, x,
      0x21, 0x00, y
    }
  end

  function screen:window(x0, x1, y0, y1, vertical)

    if vertical == nil then
      vertical = (x1 < x0) ~= (y1 < y0)
    end

    local modelo = vertical and 8 or 0

    if x1 < x0 then
      x0, x1 = x1, x0
    else
      modelo = modelo + 0x10
    end
    if y1 < y0 then
      y0, y1 = y1, y0
    else
      modelo = modelo + 0x20
    end

    self:setreg{
    -- Set window extents
      0x36, 0x00, x1,
      0x37, 0x00, x0,
      0x38, 0x00, y1,
      0x39, 0x00, y0,

    -- Set entry mode
      0x03, 0x10, modelo
    }
  end

  return screen
end
