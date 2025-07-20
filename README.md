# Raylib Bar chart lib
Bar chart widget for [Raylib-zig](https://github.com/Not-Nik/raylib-zig).

Example usage here -> [ZISTORY](https://github.com/RomaricKc1/zistory).

Tested on Zig version `0.15.0-dev.936+fc2c1883b`, `0.14.1`.

> [!NOTE]
> This is configured to work on `wayland`. If you are on `x11`, you'll need to change the display `backend`.

In the raylib dependency.

```zig
const raylib_dep = b.dependency("raylib_zig", .{
    .target = target,
    .optimize = optimize,
    .linux_display_backend = .X11,
});
```

# Usage

The project must have been created using `zig init`.

Run this to add it to your `build.zig.zon`:

```
zig fetch --save git+https://github.com/RomaricKc1/raylib-bar_chart/
```

And add these lines to your `build.zig` file:

```zig
const rl_bar_chart_dep = b.dependency("raylib_bar_chart", .{
    .target = target,
    .optimize = optimize,
});
const rl_bar_chart = rl_bar_chart_dep.module("raylib_bar_chart"); // bar chart widget
```
Now add the modules to your target:

```zig
exe.root_module.addImport("rl_bar_chart", rl_bar_chart);
```
you can then import it in your code.

```zig
const rl_bar_chart = @import("rl_bar_chart");
```

# Checkout another widget
- [Raylib-lists](https://github.com/RomaricKc1/raylib-lists)

