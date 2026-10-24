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
const debug = @import("debug.zig");
const hall = @import("hall.zig");
const castle = @import("castle.zig");
const grid = @import("grid.zig");
const author = @import("author.zig");
const training = @import("training.zig");

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
    m.load(map.castle.first, training.bytes);
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
            if (player.pressedFire(m)) {
                room.start(m);
                setMode(m, .draw_room);
            }
        },
        .draw_room => {
            m.poke(hw.control, 0);
            m.bucket(bucket_drawing);
            room.draw(m);
            debug.overlay(m);
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
            m.bucket(0);
            if (debug.keys(m) or room.flip(m)) setMode(m, .draw_room);
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

test "fire on the title screen opens the room, and the explorer walks in" {
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

    // In the Gatehouse's doorway, on the right, past the old wall at 255.
    try std.testing.expectEqual(156 + 6, m.ram[map.player_x]);
    try std.testing.expectEqual(160 + 11, m.ram[map.player_y]);
    _ = m.runFrame(@This());
    try std.testing.expect(m.ram[hw.sprite_x_msb] & 1 != 0);
    const block = m.ram[map.player_block];

    // A step every other frame: eight frames is four fat pixels to the
    // left, and a new frame of the walk, in the other block.
    hold(m, machine.joy.left, 8);
    try std.testing.expectEqual(158, m.ram[map.player_x]);
    try std.testing.expect(m.ram[map.player_block] != block);
    try std.testing.expectEqual(@intFromEnum(shapes.Id.explorer_left_3), m.ram[map.player_frame]);
}

// hall.zig is no longer loaded, so nothing compiles it unless a test asks.
test {
    _ = hall;
}

test "N and P flip through the castle's rooms, with a loading pause" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.boot(@This());
    _ = m.runFrame(@This()); // draws the title
    m.input = .{ .joy1 = machine.joy.fire };
    _ = m.runFrame(@This());
    m.input = .{};
    _ = m.runFrame(@This()); // draws room 0
    try std.testing.expectEqual(0, m.ram[map.room_number]);

    m.input = .{ .key = 'N' };
    _ = m.runFrame(@This()); // the key
    m.input = .{};
    try std.testing.expectEqual(0, m.ram[hw.key]); // acknowledged
    _ = m.runFrame(@This()); // draws room 1
    try std.testing.expectEqual(machine.FrameKind.loading, m.last.kind);
    try std.testing.expectEqual(1, m.ram[map.room_number]);

    // P twice: back to room 0, then round to the final room.
    for (0..2) |_| {
        m.input = .{ .key = 'P' };
        _ = m.runFrame(@This());
        m.input = .{};
        _ = m.runFrame(@This());
    }
    try std.testing.expectEqual(std.enums.values(training.Room).len, m.ram[map.room_number]);
}

test "the Training Castle reads back: every room walks to its end tag" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.* = .{};
    m.load(map.castle.first, training.bytes);
    try std.testing.expectEqual(castle.magic_value, m.ram[castle.magic]);
    try std.testing.expectEqual(training.bytes.len, m.peek16(castle.size));
    try std.testing.expectEqual(std.enums.values(training.Room).len, castle.roomCount(m));

    // The streams sit end to end after the directory, the final room last.
    var at: u16 = castle.directory + std.enums.values(training.Room).len * @sizeOf(castle.Entry) + 1;
    inline for (comptime std.enums.values(training.Room), 0..) |name, n| {
        try std.testing.expectEqual(at, m.peek16(castle.entry(m, n) + @offsetOf(castle.Entry, "objects")));
        at = try walkRoom(m, at, @field(training.plan.rooms, @tagName(name)));
    }
    try std.testing.expectEqual(at, m.peek16(castle.final_room));
    at = try walkRoom(m, at, training.plan.final.?);
    try std.testing.expectEqual(castle.header + training.bytes.len, at);

    // And a door says where it goes: the gatehouse's leads to the gallery.
    const first = m.view(castle.Door, m.peek16(castle.entry(m, 0) + @offsetOf(castle.Entry, "objects")) + 3);
    try std.testing.expectEqual(@intFromEnum(training.Room.gallery), first.to_room);
}

/// Walk one room's stream, check it holds what the plan says, and return
/// the address after its end tag.
fn walkRoom(m: *Machine, at: u16, plan: author.Room(training.Room)) !u16 {
    var found = std.enums.EnumArray(castle.Kind, usize).initFill(0);
    var walk = castle.Walker{ .at = at };
    while (walk.next(m)) |r| found.getPtr(r.kind).* += 1;
    inline for (comptime std.enums.values(castle.Kind)) |kind| {
        const list = @field(plan, @tagName(kind));
        const planned = if (kind == .teleport) @intFromBool(list != null) else list.len;
        try std.testing.expectEqual(planned, found.get(kind));
    }
    return walk.at;
}

test "the Ladders room's grid: walkways, a ladder, and the ways between" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 2);
    const at = struct {
        fn at(mm: *Machine, col: u8, row: u8) u8 {
            return mm.ram[map.grid.first + @as(u16, row) * grid.columns + col];
        }
    }.at;
    // The floor, row 24: right from its first piece, left from its last.
    try std.testing.expectEqual(grid.right, at(m, 0, 24));
    try std.testing.expectEqual(grid.left | grid.right, at(m, 1, 24));
    try std.testing.expectEqual(grid.left, at(m, 39, 24));
    // The ladder, column 24: up from the floor, both ways on the rungs,
    // down from the upper walkway, whose first piece is column 20.
    try std.testing.expectEqual(grid.left | grid.right | grid.up, at(m, 24, 24));
    try std.testing.expectEqual(grid.up | grid.down, at(m, 24, 20));
    try std.testing.expectEqual(grid.left | grid.right | grid.down, at(m, 24, 16));
    try std.testing.expectEqual(grid.right, at(m, 20, 16));
    // And nothing where there's nothing to stand on.
    try std.testing.expectEqual(0, at(m, 19, 16));
    try std.testing.expectEqual(0, at(m, 10, 10));
}

test "searching the castle gives the grid's answer in every cell of every room" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 0);
    for (0..std.enums.values(training.Room).len + 1) |n| {
        m.ram[map.room_number] = @intCast(n);
        room.draw(m);
        const objects = room.objects(m, @intCast(n));
        for (0..grid.rows) |row| {
            for (0..grid.columns) |col| {
                const x: u8 = @intCast(16 + 4 * col);
                const y: u8 = @intCast(8 * row);
                try std.testing.expectEqual(grid.at(m, x, y), grid.search(m, objects, x, y));
            }
        }
    }
}

test "a walkway's end is as far as you go" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 1); // the Long Gallery: 35 pieces, columns 0 to 34
    hold(m, machine.joy.right, 400);
    try std.testing.expectEqual(149, m.ram[map.player_x]); // feet at 152, column 34's first fat pixel
    try std.testing.expectEqual(@intFromEnum(shapes.Id.explorer_right_0), m.ram[map.player_frame]); // standing
    hold(m, machine.joy.left, 400);
    try std.testing.expectEqual(16, m.ram[map.player_x]); // feet at 19, column 0's last
    try std.testing.expectEqual(160 + 11, m.ram[map.player_y]); // and never off the floor
}

test "he lines up with a ladder, climbs it, and steps off at the top" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 2); // Ladders: the ladder is at x 112, from row 128 to the floor
    m.ram[map.player_x] = 111; // feet at 114: two fat pixels into the ladder's cell
    hold(m, machine.joy.up, 2);
    try std.testing.expectEqual(110, m.ram[map.player_x]); // feet at 113, between the rails
    try std.testing.expectEqual(171 - 2, m.ram[map.player_y]);
    try std.testing.expect(m.ram[map.player_frame] >= @intFromEnum(shapes.Id.explorer_climb_0));
    hold(m, machine.joy.up | machine.joy.right, 200); // a diagonal keeps him climbing
    try std.testing.expectEqual(128 - 21 + 6, m.ram[map.player_y]); // the top rung's cell
    try std.testing.expectEqual(110, m.ram[map.player_x]);
    hold(m, machine.joy.right, 2); // step off: up onto the walkway, and along
    try std.testing.expectEqual(128 - 21, m.ram[map.player_y]);
    try std.testing.expectEqual(111, m.ram[map.player_x]);
    hold(m, machine.joy.down, 200);
    try std.testing.expectEqual(192 - 21, m.ram[map.player_y]); // and back to the floor
}

test "a pole only goes down" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 3); // Sliding Poles: the pole is at x 72, from row 128
    m.ram[map.player_x] = 72; // feet at 75, in the pole's cell
    hold(m, machine.joy.up, 20);
    try std.testing.expectEqual(128 - 21, m.ram[map.player_y]); // no climbing up a pole
    hold(m, machine.joy.down, 200);
    try std.testing.expectEqual(192 - 21, m.ram[map.player_y]); // down onto the floor
    try std.testing.expectEqual(70, m.ram[map.player_x]); // lined up with it on the way
    try std.testing.expectEqual(@intFromEnum(shapes.Id.explorer_slide), m.ram[map.player_frame]);
    hold(m, machine.joy.up, 20);
    try std.testing.expectEqual(192 - 21, m.ram[map.player_y]); // and no way back
}

/// Boot, press fire on the title, and stand in room `n`'s first doorway.
fn inRoom(m: *Machine, n: u8) void {
    m.boot(@This());
    _ = m.runFrame(@This()); // draws the title
    m.input = .{ .joy1 = machine.joy.fire };
    _ = m.runFrame(@This());
    m.input = .{};
    m.ram[map.room_number] = n; // instead of the castle's start room
    _ = m.runFrame(@This()); // draws the room
}

/// Hold joystick 1's `stick` switches for `frames` frames, then let go.
fn hold(m: *Machine, stick: u8, frames: usize) void {
    m.input = .{ .joy1 = stick };
    for (0..frames) |_| _ = m.runFrame(@This());
    m.input = .{};
}
