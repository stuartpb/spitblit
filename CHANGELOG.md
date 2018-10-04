# spitblit changelog

## v0.1.0

Initial release, with one driver (ili9225.lua) implementing five core methods and three constant properties:

- `screen:init(opts)`
- `screen:window(x0, x1, y0, y1, vertical)`
- `screen:jump(x, y)`
- `screen:fill()`
- `screen:light()`
- `screen.width`
- `screen.height`
- `screen.bpc`

### ili9225

The driver also exposes three non-interface methods for low-level use:

- `screen:initspi()`
- `screen:initgpio()`
- `screen:setreg()`

## v0.0.0

Effectively unversioned. Any file carrying a "v0.0.0" designation is from early enough in development that I hadn't settled on an interface to document.
