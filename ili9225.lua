return {
  lcd = {
    w = 176,
    h = 220
  },
  reg = {
    ctrl = {
      driver_output = 0x01,
      lcd_ac_driving = 0x02,
      disp = {0x07},
      blank_period = {0x08},
      frame_cycle = 0x0b,
      interface = 0x0c,
      osc = 0x0f,
      power = {0x10, 0x11, 0x12, 0x13, 0x14},
      gate_scan = 0x30,
      vertical_scroll = {0x31, 0x32, 0x33},
      gamma = {0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59}
    },
    set = {
      gram_haddr = 0x20,
      gram_vaddr = 0x21
    },
    pos = {
      partial_driving = {0x34, 0x35}
    },
    addr = {
      hwin = {0x36, 0x37},
      vwin = {0x38, 0x39}
    }
    entry_mode = 0x03,
    vci_recycling = 0x15,
    gram_data = 0x22,
  }
}
