# spitblit

This is intended to be a collection of pure-Lua low-level drivers for various TFT displays over SPI for NodeMCU running on the ESP8266 (and/or possibly ESP32).

Right now, it only has support for the ILI9225, because that's all I have, but I'm trying to factor the interface to be portable to other modules.

## Version 0.1.0

This project follows Semantic Versioning.

See CHANGELOG.md for version history.

## API

Each module in the `drivers` directory implements a constructor for a screen of that kind, which will return a table exposing the `screen` interface defined below.

Drivers may provide unit-specific extensions to this interface: see the corresponding documentation in `docs`.

### Constructor

The constructor for a screen takes parameters defining the hardware interface (such as pin addresses) for the screen it will drive.

See the documentation for the specific screen for all the parameters that are required and/or optional for that screen's driver constructor.

### `screen:init()`

This method runs all initialization procedures required to set up the screen, including setting a window that encompasses the entire screen and turning on the backlight.

If you won't need to re-initialize the screen at any point, and you don't have any dangling references to the driver's constructor, you may free up the memory taken up by these initialization procedures by setting `screen.init = null` after calling it.

### `screen.width` and `screen.height`

The dimensions of the screen implemented by this driver, in pixels.

Note that this is based on the *native orientation* of the screen, as defined in the datasheet: unlike most consumer displays, your screen may be specified in portrait orientation, with a `width` that is less than its `height`. spitblit does not perform any sort of coordinate transformation (such details are left to higher-level wrappers around the spitblit interface): if you want to send rotated images to the screen, you'll want to set a window with addresses that decrease in either the `x` or `y` axis (depending on which way you rotate the screen). See the definition of `screen:window` described below (noting that this kind of rotation is what the default value of `vertical` is based around).

### `screen:window(x0, y0, x1, y1, vertical)`

This function sets the region of the screen that pixels will fill, going from `x0` to `x1` and from `y0` to `y1`. (If `x0`/`y0` is greater than `x1`/`y1`, the X/Y values will decrement; otherwise, they will increment.)

The `vertical` parameter defines whether pixels should fill up/down before they fill left/right (in other words, if the image should be rotated). by default, this is true if one axis is in descending order, and the other axis is in ascending order (if `x0` is greater than `x1` and `y0` is less than `y1`, or vice versa), and false otherwise.

Under the default behavior for `vertical`, changing the order of the `x0`/`y0` and `x1`/`y1` parameters will rotate the image: if you want to *flip* the image (eg. `x1` is less than `x0` and `y0` is less than `y1` and you want to draw a series of rows from right to left), you should specify this explicitly (in the previous example, that would be an explicit fifth parameter of `false`).

Note that setting the window does *not* set the address: if you want to start filling from the first position and your drawing code hasn't already moved you there, you will need to explicitly call `screen:jump(x0, y0)` immediately after calling this method.

### `screen:jump(x, y)`

Moves the current fill address to the given position, so that subsequent calls to `screen:fill(bytes)` will proceed starting from that position.

For example, if you wanted to implement a `setPixel` method directly on top of `spitblit` (which you cold do, though it wouldn't be as efficient as keeping an internal buffer and just redrawing the modified region of the screen), you could do it with a call to `jump` moving to that coordinate (assuming that the pixel is within the defined window), followed by a call to `fill` with the bytes of that pixel's color.

### `screen.bpc`

The color format of the screen, in terms of bits-per-channel.

Right now, the only format specified is `'r5g6b5'`, for the 16-bit RGB color used by the ILI9225. However, some other color formats that future screens are potentially expected to use are:

- `'r8g8b8'`, for 24-bit color
- `'r2g3b2'`, for 8-bit color
- `'w8'`, for 8-bit grayscale
- `'w1'` or `'k1'`, for 1-bit black-and-white (white or black high, respectively)

Screens defining color in a different format than bits-per-channel color (ie. an indexed palette) will probably have their color format defined by a different parameter: such screens are not yet supported, so such parameters are not yet specified.

### `screen:fill(bytes)`

Sends pixel data from `bytes` to the screen. This function passes its arguments to `spi.send` under the hood, so it supports all the same input formats as `spi.send` (lists and/or tables of numbers and/or strings).

### `screen:light()`

Sets the brightness of the screen backlight. Currently only supports turning the backlight on or off (by passing `true` / `1` or `false` / `0`, respectively).
