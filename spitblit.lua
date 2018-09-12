return {
  version = '0.0.0',
  create = function(model, pins)
    local cr = model.reg.ctrl

    local rs = pins.rs
    local cs = pins.cs

    local writepin = gpio.write
    local LOW = gpio.LOW
    local HIGH = gpio.HIGH

    local send = spi.send

    local cmd = LOW
    local dat = HIGH

    local function push(cord, word)
      writepin(rs, cord)
      writepin(cs, LOW)
      send(1, word / 256, word % 256)
      writepin(cs, HIGH)
    end
    local function writereg(reg, data)
      push(cmd, reg)
      push(dat, data)
    end
    local function writeregs(regs, data)
      for i = 1, #regs do
        writereg(regs[i], data[i])
      end
    end

    local coordOrientations = {

    }

    local object = {}
    function object:init()
      node.setcpufreq(node.CPU160MHZ)

      spi.setup(1, spi.MASTER, spi.CPOL_LOW, spi.CPHA_LOW, spi.DATABITS_8, 2)

      gpio.mode(rs, gpio.OUTPUT)
      gpio.mode(pins.rst, gpio.OUTPUT)
      gpio.mode(cs, gpio.OUTPUT)
      gpio.mode(pins.led, gpio.OUTPUT)

      writepin(pins.led, HIGH)

      -- start initial sequence
      writeregs(cr.power, {0, 0, 0, 0, 0})

      -- power on
      writereg(cr.power[2], 0x0018)
      writereg(cr.power[3], 0x6121)
      writereg(cr.power[4], 0x006f)
      writereg(cr.power[5], 0x495f)
      writereg(cr.power[1], 0x0800)
      tmr.delay(10)
      writereg(cr.power[2], 0x103b)
      tmr.delay(50)

      writereg(cr.driver_output, 0x011c)
      writereg(cr.lcd_ac_driving, 0x0100)
      writereg(model.reg.entry_mode, 0x1030)
      writereg(cr.disp[1], 0x0000)
      writereg(cr.blank_period[1], 0x0808)
      writereg(cr.frame_cycle, 0x1100)
      writereg(cr.interface, 0x0000)
      writereg(cr.osc, 0x0d01)
      writereg(model.reg.vci_recycling, 0x0029)
      writereg(model.reg.set.gram_haddr, 0x0000)
      writereg(model.reg.set.gram_vaddr, 0x0000)

      writereg(cr.gate_scan, 0x0000)
      writeregs(cr.vertical_scroll, {0xdb, 0, 0})
      writeregs(model.reg.pos.partial_driving, {0xdb, 0})
      writeregs(model.reg.addr.hwin, {0xaf, 0})
      writeregs(model.reg.addr.vwin, {0xdb, 0})

      writeregs(cr.gamma,
        {0, 0x808, 0x80a, 0xa, 0xa08, 0x808, 0, 0xa00, 0x710, 0x710})

      writereg(cr.disp[1], 0x0012)
      tmr.delay(50)
      writereg(cr.disp[1], 0x1017)
    end
    return object
  end
}
