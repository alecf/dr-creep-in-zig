//! Your game. The Comet 64 calls `boot` once when it powers on, then
//! `frame` fifty times a second, forever.

const std = @import("std");
const machine = @import("machine");
const Machine = machine.Machine;
const Color = machine.Color;
const hw = machine.hw;
const map = @import("map.zig");
const screen = @import("screen.zig");
const shapes = @import("shapes.zig");
const text = @import("text.zig");
const title = @import("title.zig");
const room = @import("room.zig");
const player = @import("player.zig");

/// What the game is doing. Power-on memory is 0, so it starts by drawing
/// the title screen.
const Mode = enum(u8) { draw_title, title, draw_room, room };

/// Meter buckets, so the meter can say where each frame went.
const bucket_drawing = 1;
const bucket_sprites = 2;

pub fn boot(m: *Machine) void {
    m.poke(hw.border, @intFromEnum(Color.blue));
    m.poke(hw.background, @intFromEnum(Color.black));
    screen.start(m);
    text.start(m);
    m.load(map.shape_table.first, shapes.table);
    m.load(map.stars.first, &title.star_map);
    player.start(m);
}

pub fn frame(m: *Machine) void {
    switch (mode(m)) {
        .draw_title => {
            m.poke(hw.control, 0); // blank first, inside the first 3,213 cycles
            m.bucket(bucket_drawing);
            title.draw(m);
            setMode(m, .title); // the display comes back on next frame
        },
        .title => {
            m.poke(hw.control, machine.display_on); // before the beam reaches the display
            m.bucket(bucket_drawing);
            title.twinkle(m);
            m.bucket(0);
            if (player.pressedFire(m)) setMode(m, .draw_room);
        },
        .draw_room => {
            m.poke(hw.control, 0);
            m.bucket(bucket_drawing);
            room.draw(m);
            m.bucket(bucket_sprites);
            player.enter(m);
            setMode(m, .room);
        },
        .room => {
            // Hardware first. The beam reaches the top of the display 3,213
            // cycles into the frame; registers written before then can't tear.
            m.poke(hw.control, machine.display_on);
            m.bucket(bucket_sprites);
            player.show(m);

            // Then the game itself. What it decides shows up next frame.
            player.steer(m);
        },
    }
    m.bucket(0);
    m.poke(map.game_tick, m.peek(map.game_tick) +% 1);
}

fn mode(m: *Machine) Mode {
    return @enumFromInt(m.peek(map.game_mode));
}

fn setMode(m: *Machine, new: Mode) void {
    m.poke(map.game_mode, @intFromEnum(new));
}

test "fire on the title screen opens the room, and the explorer walks" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.boot(@This());

    _ = m.runFrame(@This()); // draws the title
    try std.testing.expectEqual(machine.FrameKind.loading, m.last.kind);
    try std.testing.expectEqual(@intFromEnum(Mode.title), m.ram[map.game_mode]);

    m.input = .{ .joy1 = machine.joy.fire };
    _ = m.runFrame(@This()); // the press
    m.input = .{};
    _ = m.runFrame(@This()); // draws the room
    try std.testing.expectEqual(@intFromEnum(Mode.room), m.ram[map.game_mode]);
    const x = m.ram[map.player_x];
    const block = m.ram[map.player_block];

    // Four pixels right is a new frame of the walk, in the other block.
    m.input = .{ .joy1 = machine.joy.right };
    for (0..4) |_| _ = m.runFrame(@This());
    try std.testing.expectEqual(x + 4, m.ram[map.player_x]);
    try std.testing.expect(m.ram[map.player_block] != block);
    try std.testing.expectEqual(@intFromEnum(shapes.Id.explorer_right_1), m.ram[map.player_frame]);
}
