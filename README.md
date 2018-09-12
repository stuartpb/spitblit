# spitblit

This is intended to be a collection of pure-Lua low-level drivers for various TFT displays over SPI for NodeMCU running on the ESP8266 (and/or possibly ESP32).

Right now, it only has support for the ILI9225, because that's all I have, but I'm trying to factor the interface to be portable to other modules.

## Version 0.0.0

This project follows Semantic Versioning.

See CHANGELOG.md for version history.

## API

TODO - Right now at v0.0.0, the API is still forming as I read other libraries and write my own implementation, so there's nothing clear enough to document yet (what I have so far in my head is really just a mess of bits and pieces that don't quite fit together yet).

For reference, though, here's how I envisioned the first step for the code as it's currently written:

```
local spitblit = require('spitblit')
local pins = {rs = 2, cs = 4, rst = 8, led = 1}
local screen = spitblit.create(require('ili9225'), pins)
```

However, I'm realizing now that that's one level too complex for the design I have in mind, so I'm probably going to simplify with my next commit.

See docs/ili9225.md for my influences.
