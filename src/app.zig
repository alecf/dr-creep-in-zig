//! Windowed shell: the emulation core in a sokol window (Metal on macOS).
//!
//! Keyboard mapping:
//!   arrows + right-ctrl/space = joystick 1 (menu + player 1)
//!   WASD + left-shift         = joystick 2 (player 2)
//!   Escape                    = RUN/STOP (opens the game's options menu)
//!   Enter                     = Return (filename prompts)

const std = @import("std");
const sokol = @import("sokol");
const sapp = sokol.app;
const sg = sokol.gfx;
const sglue = sokol.glue;
const sgl = sokol.gl;
const slog = sokol.log;

const Machine = @import("core/machine.zig").Machine;
const vic = @import("core/vic.zig");
const kernal = @import("core/kernal.zig");

const State = struct {
    machine: *Machine = undefined,
    fs: kernal.Fs = undefined,
    fb: [vic.WIDTH * vic.HEIGHT]u32 = @splat(0xFF000000),
    img: sg.Image = .{},
    view: sg.View = .{},
    smp: sg.Sampler = .{},
    joy1: u8 = 0x1F,
    joy2: u8 = 0x1F,
};
var state: State = .{};

export fn init() void {
    sg.setup(.{
        .environment = sglue.environment(),
        .logger = .{ .func = slog.func },
    });
    sgl.setup(.{ .logger = .{ .func = slog.func } });

    state.img = sg.makeImage(.{
        .usage = .{ .stream_update = true },
        .width = vic.WIDTH,
        .height = vic.HEIGHT,
        .pixel_format = .RGBA8,
    });
    state.view = sg.makeView(.{ .texture = .{ .image = state.img } });
    state.smp = sg.makeSampler(.{
        .min_filter = .NEAREST,
        .mag_filter = .NEAREST,
    });
}

export fn frame() void {
    const m = state.machine;
    m.joy1 = state.joy1;
    m.joy2 = state.joy2;
    _ = m.runFrame();
    vic.renderFrame(m, &state.fb);

    var data = sg.ImageData{};
    data.mip_levels[0] = sg.asRange(&state.fb);
    sg.updateImage(state.img, data);

    // letterbox the 4:3-ish C64 screen into the window
    const win_w: f32 = sapp.widthf();
    const win_h: f32 = sapp.heightf();
    const src_w: f32 = @floatFromInt(vic.WIDTH);
    const src_h: f32 = @floatFromInt(vic.HEIGHT);
    const scale = @min(win_w / src_w, win_h / src_h);
    const draw_w = src_w * scale;
    const draw_h = src_h * scale;
    const x0 = (win_w - draw_w) / 2;
    const y0 = (win_h - draw_h) / 2;

    sgl.defaults();
    sgl.viewport(0, 0, sapp.width(), sapp.height(), true);
    sgl.matrixModeProjection();
    sgl.ortho(0, win_w, win_h, 0, -1, 1);
    sgl.enableTexture();
    sgl.texture(state.view, state.smp);
    sgl.beginQuads();
    sgl.v2fT2f(x0, y0, 0, 0);
    sgl.v2fT2f(x0 + draw_w, y0, 1, 0);
    sgl.v2fT2f(x0 + draw_w, y0 + draw_h, 1, 1);
    sgl.v2fT2f(x0, y0 + draw_h, 0, 1);
    sgl.end();

    var action = sg.PassAction{};
    action.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 0, .g = 0, .b = 0, .a = 1 },
    };
    sg.beginPass(.{ .action = action, .swapchain = sglue.swapchain() });
    sgl.draw();
    sg.endPass();
    sg.commit();
}

export fn cleanup() void {
    sgl.shutdown();
    sg.shutdown();
}

fn joyBit(down: bool, joy: *u8, mask: u8) void {
    if (down) joy.* &= ~mask else joy.* |= mask;
}

export fn event(ev: [*c]const sapp.Event) void {
    const e = ev.*;
    switch (e.type) {
        .KEY_DOWN, .KEY_UP => {
            const down = e.type == .KEY_DOWN;
            switch (e.key_code) {
                .UP => joyBit(down, &state.joy1, 0x01),
                .DOWN => joyBit(down, &state.joy1, 0x02),
                .LEFT => joyBit(down, &state.joy1, 0x04),
                .RIGHT => joyBit(down, &state.joy1, 0x08),
                .SPACE, .RIGHT_CONTROL => joyBit(down, &state.joy1, 0x10),
                .W => joyBit(down, &state.joy2, 0x01),
                .S => joyBit(down, &state.joy2, 0x02),
                .A => joyBit(down, &state.joy2, 0x04),
                .D => joyBit(down, &state.joy2, 0x08),
                .LEFT_SHIFT => joyBit(down, &state.joy2, 0x10),
                // RUN/STOP: keyboard matrix column 7 bit 7
                .ESCAPE => {
                    if (down) {
                        state.machine.key_matrix[7] &= ~@as(u8, 0x80);
                    } else {
                        state.machine.key_matrix[7] |= 0x80;
                    }
                },
                // RETURN: column 0 bit 1
                .ENTER => {
                    if (down) {
                        state.machine.key_matrix[0] &= ~@as(u8, 0x02);
                    } else {
                        state.machine.key_matrix[0] |= 0x02;
                    }
                },
                else => {},
            }
        },
        else => {},
    }
}

pub fn main(init_proc: std.process.Init) !void {
    const allocator = init_proc.gpa;
    const io = init_proc.io;

    state.machine = try Machine.init(allocator);
    state.fs = kernal.Fs.init(allocator);

    const cwd = std.Io.Dir.cwd();
    {
        var dir = try cwd.openDir(io, "extracted", .{});
        defer dir.close(io);
        const manifest = try dir.readFileAlloc(io, "manifest.txt", allocator, .limited(16 * 1024));
        defer allocator.free(manifest);
        var lines = std.mem.tokenizeScalar(u8, manifest, '\n');
        while (lines.next()) |stem| {
            var path_buf: [128]u8 = undefined;
            const path = try std.fmt.bufPrint(&path_buf, "{s}.prg", .{stem});
            const data = dir.readFileAlloc(io, path, allocator, .limited(64 * 1024)) catch continue;
            const name = try allocator.dupe(u8, stem);
            try state.fs.addFile(name, data);
        }
    }
    try kernal.install(state.machine, &state.fs);

    const chargen_paths = [_][]const u8{
        "roms/chargen.bin",
        "/opt/homebrew/share/vice/C64/chargen-901225-01.bin",
    };
    for (chargen_paths) |path| {
        const rom = cwd.readFileAlloc(io, path, allocator, .limited(8192)) catch continue;
        defer allocator.free(rom);
        if (rom.len >= 0x1000) {
            @memcpy(&state.machine.char_rom, rom[0..0x1000]);
            break;
        }
    }

    const object = state.fs.files.get("object") orelse return error.MissingObjectPrg;
    const entry = state.machine.loadPrg(object);
    state.machine.cpu.reset(entry);

    sapp.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
        .event_cb = event,
        .width = vic.WIDTH * 3,
        .height = vic.HEIGHT * 3,
        .window_title = "The Castles of Dr. Creep (Zig)",
        .logger = .{ .func = slog.func },
    });
}
