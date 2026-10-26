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
const actors = @import("actors.zig");
const objects = @import("objects.zig");
const debug = @import("debug.zig");
const hall = @import("hall.zig");
const castle = @import("castle.zig");
const grid = @import("grid.zig");
const author = @import("author.zig");
const training = @import("training.zig");
const locks = @import("locks.zig");
const guns = @import("guns.zig");
const dice = @import("dice.zig");

/// What the game is doing. Power-on memory is 0, so it starts by drawing
/// the title screen.
const Mode = enum(u8) { draw_title, title, draw_room, room };

/// Meter buckets, so the meter can say where each frame went.
const bucket_drawing = 1;
const bucket_sprites = 2;
const bucket_actors = 3;
const bucket_objects = 4;

pub fn boot(m: *Machine) void {
    m.poke(hw.border, @intFromEnum(Color.blue));
    m.poke(hw.background, @intFromEnum(Color.black));
    screen.start(m);
    text.start(m);
    m.load(map.shape_table.first, shapes.table);
    m.load(map.stars.first, &title.star_map);
    m.load(map.castle.first, training.bytes);
    player.start(m);
    dice.start(m);
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
                player.newGame(m);
                setMode(m, .draw_room);
            }
        },
        .draw_room => {
            m.poke(hw.control, 0);
            m.bucket(bucket_sprites);
            actors.clear(m); // first: preparing the room can add actors
            m.bucket(bucket_drawing);
            room.draw(m); // and its objects
            debug.overlay(m);
            m.bucket(bucket_sprites);
            player.add(m);
            setMode(m, .room);
        },
        .room => {
            // Hardware first. The beam reaches the top of the display 3,213
            // cycles into the frame; registers written before then can't tear.
            m.poke(hw.control, machine.display_on);
            m.bucket(bucket_sprites);
            actors.show(m);

            // Then the castle itself, one engine step every other frame:
            // 25 a second. What it decides shows up next frame.
            if (m.peek(map.game_tick) & 1 == 0) {
                m.bucket(bucket_actors);
                actors.step(m);
                m.bucket(bucket_objects);
                objects.step(m);
                m.bucket(0);
                if (player.roomOver(m)) setMode(m, if (player.nextRoom(m)) .draw_room else .draw_title);
            }
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
    try std.testing.expectEqual(156 + 6, explorer(m).box.x);
    try std.testing.expectEqual(160 + 11, explorer(m).box.y);
    _ = m.runFrame(@This());
    try std.testing.expect(m.ram[hw.sprite_x_msb] & 1 != 0);
    const block = explorer(m).block;

    // A step every other frame: eight frames is four fat pixels to the
    // left, and a new frame of the walk, in the other block.
    hold(m, machine.joy.left, 8);
    try std.testing.expectEqual(158, explorer(m).box.x);
    try std.testing.expect(explorer(m).block != block);
    try std.testing.expectEqual(@intFromEnum(shapes.Id.explorer_left_3), explorer(m).frame);
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

test "searching the castle gives the grid's answer, except at a machine's walls" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 0);
    inline for (comptime std.enums.values(training.Room), 0..) |name, n| {
        m.ram[map.room_number] = n;
        actors.clear(m);
        room.draw(m);
        const stream = room.stream(m, n);
        var differ: usize = 0;
        for (0..grid.rows) |row| {
            for (0..grid.columns) |col| {
                const x: u8 = @intCast(16 + 4 * col);
                const y: u8 = @intCast(8 * row);
                if (grid.at(m, x, y) != grid.search(m, stream, x, y)) differ += 1;
            }
        }
        // The search reads only the castle, so it walks through every
        // raised forcefield and open trapdoor (two cells each) and into
        // every Frankenstein's alcove (three).
        const plan = @field(training.plan.rooms, @tagName(name));
        var walls = plan.forcefield.len;
        for (plan.trapdoor) |t| walls += t.state & castle.trapdoor_open;
        try std.testing.expectEqual(2 * walls + 3 * plan.frankenstein.len, differ);
    }
}

test "a walkway's end is as far as you go" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 1); // the Long Gallery: 35 pieces, columns 0 to 34
    hold(m, machine.joy.right, 400);
    try std.testing.expectEqual(149, explorer(m).box.x); // feet at 152, column 34's first fat pixel
    try std.testing.expectEqual(@intFromEnum(shapes.Id.explorer_right_0), explorer(m).frame); // standing
    hold(m, machine.joy.left, 400);
    try std.testing.expectEqual(16, explorer(m).box.x); // feet at 19, column 0's last
    try std.testing.expectEqual(160 + 11, explorer(m).box.y); // and never off the floor
}

test "he lines up with a ladder, climbs it, and steps off at the top" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 2); // Ladders: the ladder is at x 112, from row 128 to the floor
    explorer(m).box.x = 111; // feet at 114: two fat pixels into the ladder's cell
    hold(m, machine.joy.up, 2);
    try std.testing.expectEqual(110, explorer(m).box.x); // feet at 113, between the rails
    try std.testing.expectEqual(171 - 2, explorer(m).box.y);
    try std.testing.expect(explorer(m).frame >= @intFromEnum(shapes.Id.explorer_climb_0));
    hold(m, machine.joy.up | machine.joy.right, 200); // a diagonal keeps him climbing
    try std.testing.expectEqual(128 - 21 + 6, explorer(m).box.y); // the top rung's cell
    try std.testing.expectEqual(110, explorer(m).box.x);
    hold(m, machine.joy.right, 2); // step off: up onto the walkway, and along
    try std.testing.expectEqual(128 - 21, explorer(m).box.y);
    try std.testing.expectEqual(111, explorer(m).box.x);
    hold(m, machine.joy.down, 200);
    try std.testing.expectEqual(192 - 21, explorer(m).box.y); // and back to the floor
}

test "a pole only goes down" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 3); // Sliding Poles: the pole is at x 72, from row 128
    explorer(m).box.x = 72; // feet at 75, in the pole's cell
    hold(m, machine.joy.up, 20);
    try std.testing.expectEqual(128 - 21, explorer(m).box.y); // no climbing up a pole
    hold(m, machine.joy.down, 200);
    try std.testing.expectEqual(192 - 21, explorer(m).box.y); // down onto the floor
    try std.testing.expectEqual(70, explorer(m).box.x); // lined up with it on the way
    try std.testing.expectEqual(@intFromEnum(shapes.Id.explorer_slide), explorer(m).frame);
    hold(m, machine.joy.up, 20);
    try std.testing.expectEqual(192 - 21, explorer(m).box.y); // and no way back
}

test "a doorbell opens its door, on both sides of the wall" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 0); // the Gatehouse: the door at x 156, its bell at x 140
    const door = objects.slot(m, 0);
    try std.testing.expectEqual(objects.Kind.door, door.kind);
    try std.testing.expectEqual(0, door.open);
    hold(m, machine.joy.left, 34); // 17 steps: feet at 148, under the bell
    try std.testing.expectEqual(145, explorer(m).box.x);
    hold(m, machine.joy.fire, 4);
    try std.testing.expectEqual(1, door.open); // ringing
    try std.testing.expect(door.flags.execute);
    hold(m, 0, 60); // a row of the panel a step
    try std.testing.expect(!door.flags.execute);
    try std.testing.expect(m.view(castle.Door, room.doorAt(m, 0, 0).?).side & castle.door_open != 0);
    try std.testing.expect(m.view(castle.Door, room.doorAt(m, 1, 0).?).side & castle.door_open != 0); // the Gallery's side
}

test "fire held on the way to a bell is not a press" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 0);
    hold(m, machine.joy.left | machine.joy.fire, 34); // pressed far from the bell, then held
    hold(m, machine.joy.fire, 10);
    try std.testing.expectEqual(0, objects.slot(m, 0).open);
    hold(m, 0, 2);
    hold(m, machine.joy.fire, 4); // let go and pressed again, at the bell
    try std.testing.expectEqual(1, objects.slot(m, 0).open);
}

test "through the door and out of the one it leads to, and back again" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 0);
    hold(m, machine.joy.left, 34);
    hold(m, machine.joy.fire, 4);
    hold(m, machine.joy.right, 60); // back to the door, and wait for it
    hold(m, machine.joy.up, 4); // up alone isn't the way in
    try std.testing.expectEqual(@intFromEnum(player.Status.playing), m.ram[map.player_status]);
    hold(m, machine.joy.up | machine.joy.right, 4);
    try std.testing.expectEqual(@intFromEnum(player.Status.doorway), m.ram[map.player_status]);
    try std.testing.expectEqual(1, m.ram[map.room_number]); // the Long Gallery
    try std.testing.expectEqual(0, m.ram[map.player_door]); // by its door 0
    hold(m, 0, 160);
    try std.testing.expectEqual(@intFromEnum(Mode.room), m.ram[map.game_mode]);
    try std.testing.expectEqual(@intFromEnum(player.Status.playing), m.ram[map.player_status]);
    try std.testing.expectEqual(16 + 6, explorer(m).box.x); // walked out, in front of it
    try std.testing.expectEqual(160 + 11, explorer(m).box.y);

    // The way back is open already: the Gatehouse's door stays open.
    hold(m, machine.joy.up | machine.joy.right, 4);
    hold(m, 0, 160);
    try std.testing.expectEqual(0, m.ram[map.room_number]);
    try std.testing.expectEqual(1, objects.slot(m, 0).open);
    try std.testing.expectEqual(156 + 6, explorer(m).box.x);
}

test "X: a flicker, a life lost, back to the start; no lives left, the title" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 2); // the Ladders room
    try std.testing.expectEqual(3, m.ram[map.player_lives]);
    m.input = .{ .key = 'X' };
    _ = m.runFrame(@This());
    m.input = .{};
    hold(m, 0, 8);
    try std.testing.expect(explorer(m).state.dying);
    try std.testing.expectEqual(0, m.ram[hw.sprite_multicolor] & 1); // one colour while he flickers
    hold(m, 0, 100);
    try std.testing.expectEqual(2, m.ram[map.player_lives]);
    try std.testing.expectEqual(0, m.ram[map.room_number]); // the castle's start
    try std.testing.expectEqual(156 + 6, explorer(m).box.x);
    for (0..2) |_| {
        m.input = .{ .key = 'X' };
        _ = m.runFrame(@This());
        m.input = .{};
        hold(m, 0, 100);
    }
    try std.testing.expectEqual(0, m.ram[map.player_lives]);
    try std.testing.expectEqual(@intFromEnum(Mode.title), m.ram[map.game_mode]);
}

test "lightning: the bolts kill, and the switch upstairs stops both machines" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 4); // Lightning: in at door 0, on the left
    hold(m, 0, 4); // the machines' first step makes their bolts
    try std.testing.expectEqual(2, count(m, .lightning));

    // Along the floor, into the first bolt.
    hold(m, machine.joy.right, 200);
    try std.testing.expectEqual(@intFromEnum(player.Status.dead), m.ram[map.player_status]);

    // Again, the other way: up the ladder (x 56) to the switch (x 32).
    inRoom(m, 4);
    while (explorer(m).box.x + player.feet_x < 57) hold(m, machine.joy.right, 2);
    hold(m, machine.joy.up, 200);
    while (explorer(m).box.x + player.feet_x > 34) hold(m, machine.joy.left, 2);
    try std.testing.expectEqual(128 - 21, explorer(m).box.y); // on the upper walkway
    hold(m, machine.joy.down, 4); // throw it down
    hold(m, 0, 4);
    try std.testing.expectEqual(0, count(m, .lightning));
    hold(m, machine.joy.up, 4); // and up again: both run again
    hold(m, 0, 4);
    try std.testing.expectEqual(2, count(m, .lightning));
}

test "a forcefield stops him until its button takes it down, for 240 steps" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 5); // Forcefields: in at door 0, on the right
    hold(m, machine.joy.left, 200);
    try std.testing.expectEqual(87, explorer(m).box.x + player.feet_x); // the cell beside the field
    while (explorer(m).box.x < 122) hold(m, machine.joy.right, 2); // back to the button
    hold(m, machine.joy.fire, 4);
    const field = actors.slot(m, 0); // the field took slot 0 while the room was prepared
    try std.testing.expectEqual(actors.Kind.forcefield, field.kind);
    try std.testing.expectEqual(@intFromEnum(shapes.Id.field_off), field.frame);
    hold(m, machine.joy.left, 120);
    try std.testing.expect(explorer(m).box.x < 70); // through
    hold(m, 0, 2 * 240 - 120);
    try std.testing.expect(field.frame == @intFromEnum(shapes.Id.field_on_0) or field.frame == @intFromEnum(shapes.Id.field_on_1));
    hold(m, machine.joy.right, 100);
    try std.testing.expectEqual(76, explorer(m).box.x + player.feet_x); // walled in again, from this side
}

test "a trapdoor's switch opens it behind him, and the open hole stops him" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 6); // Trapdoors: in on the right, the hole at x 76, its switch at x 32
    const record = m.view(castle.Trapdoor, room.first(m, .trapdoor).?);
    try std.testing.expect(record.state & castle.trapdoor_open == 0);
    while (explorer(m).box.x + player.feet_x > 33) hold(m, machine.joy.left, 2); // over it, onto the switch
    hold(m, 0, 10);
    try std.testing.expect(record.state & castle.trapdoor_open != 0); // open, behind him
    hold(m, machine.joy.right, 200); // back the way he came
    try std.testing.expectEqual(@intFromEnum(player.Status.playing), m.ram[map.player_status]);
    try std.testing.expectEqual(72, explorer(m).box.x + player.feet_x); // stopped in the cell beside the hole
    while (explorer(m).box.x + player.feet_x > 33) hold(m, machine.joy.left, 2); // onto the switch again
    hold(m, 0, 10);
    try std.testing.expect(record.state & castle.trapdoor_open == 0); // shut
}

test "a conveyor carries him into the open trapdoor, and the high road goes round" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 7); // Conveyors: the belt runs left from x 60 to 91, into the hole at x 56
    // Along the floor and onto the belt, which carries him into the hole.
    while (m.ram[map.player_status] == @intFromEnum(player.Status.playing)) hold(m, machine.joy.left, 2);
    try std.testing.expectEqual(@intFromEnum(player.Status.dead), m.ram[map.player_status]);
    try std.testing.expect(explorer(m).box.x + player.feet_x < 60); // past the belt's end, over the hole

    inRoom(m, 7);
    const belt = m.view(castle.Conveyor, room.first(m, .conveyor).?);
    while (explorer(m).box.x + player.feet_x > 101) hold(m, machine.joy.left, 2); // to the control box
    hold(m, machine.joy.fire, 4);
    try std.testing.expectEqual(castle.conveyor_held, belt.state); // stopped, and turned round
    hold(m, 0, 4);
    hold(m, machine.joy.fire, 4);
    try std.testing.expectEqual(castle.conveyor_on | castle.conveyor_held, belt.state); // running right
    hold(m, machine.joy.left, 200);
    try std.testing.expect(explorer(m).box.x + player.feet_x >= 90); // walking against it, he gets no further than its end

    // The high road: up the ladder (x 112), along, down the pole (x 36).
    while (explorer(m).box.x + player.feet_x < 113) hold(m, machine.joy.right, 2);
    hold(m, machine.joy.up, 200);
    while (explorer(m).box.x + player.feet_x > 39) hold(m, machine.joy.left, 2);
    try std.testing.expectEqual(128 - 21, explorer(m).box.y); // on the high walkway
    hold(m, machine.joy.down, 200);
    try std.testing.expectEqual(192 - 21, explorer(m).box.y);
    const trapdoor = m.view(castle.Trapdoor, room.first(m, .trapdoor).?);
    while (explorer(m).box.x + player.feet_x > 31) hold(m, machine.joy.left, 2); // onto the switch (x 28)
    hold(m, 0, 10);
    try std.testing.expect(trapdoor.state & castle.trapdoor_open == 0);
    hold(m, machine.joy.right, 200); // off it the way he came: over the shut trapdoor, and the belt carries him
    try std.testing.expectEqual(@intFromEnum(player.Status.playing), m.ram[map.player_status]);
    try std.testing.expect(explorer(m).box.x + player.feet_x > 100);
}

test "the transmitter's lamp picks a pad, and fire sends him there" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 8); // the Transmitter: the booth at x 112, pad 0 upstairs at (60, 120)
    const booth = m.view(castle.Teleport, room.first(m, .teleport).?);
    while (explorer(m).box.x > 116) hold(m, machine.joy.left, 2); // into the booth
    try std.testing.expectEqual(1, booth.target);
    var steps: usize = 0;
    while (booth.target == 1 and steps < 17) : (steps += 1) hold(m, machine.joy.up, 2);
    try std.testing.expect(steps > 0); // up moves the lamp on once every 16 steps
    try std.testing.expectEqual(0, booth.target);
    hold(m, machine.joy.fire, 4);
    try std.testing.expectEqual(60, explorer(m).box.x);
    try std.testing.expectEqual(128 - 21, explorer(m).box.y);
}

test "keys: the lock does nothing without its key, and opens its door with it" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 9); // Keys and Locks: the lock at x 44, the key upstairs at x 168
    const door = objects.slot(m, objects.find(m, .door, 1).?);
    while (feet(m) > 50) hold(m, machine.joy.left, 2); // to the lock
    hold(m, machine.joy.fire, 4);
    hold(m, 0, 4);
    try std.testing.expect(!door.flags.execute); // no key, no door
    try std.testing.expectEqual(0, door.open);

    // Up the ladder (x 112) and along to the key.
    while (feet(m) < 113) hold(m, machine.joy.right, 2);
    hold(m, machine.joy.up, 200);
    hold(m, machine.joy.right, 200);
    try std.testing.expectEqual(4, m.ram[map.engine_objects]); // two doors, the key, the lock
    try std.testing.expectEqual(objects.Kind.key, objects.slot(m, 2).kind);
    hold(m, machine.joy.fire, 4);
    try std.testing.expectEqual(1, m.ram[castle.keys_count]);
    try std.testing.expectEqual(@intFromEnum(Color.green), m.ram[castle.keys_held]);
    try std.testing.expectEqual(0, m.view(castle.Key, room.first(m, .key).?).shape); // gone for good
    // Gone from the table too: the last object, the lock, moved into its slot.
    try std.testing.expectEqual(3, m.ram[map.engine_objects]);
    try std.testing.expectEqual(objects.Kind.lock, objects.slot(m, 2).kind);

    // Back down, to the lock, and the door opens.
    while (feet(m) > 115) hold(m, machine.joy.left, 2);
    hold(m, machine.joy.down, 200);
    while (feet(m) > 50) hold(m, machine.joy.left, 2);
    hold(m, machine.joy.fire, 4);
    try std.testing.expectEqual(1, door.open);
    hold(m, machine.joy.left, 60);
    hold(m, machine.joy.up | machine.joy.right, 4);
    try std.testing.expectEqual(@intFromEnum(player.Status.doorway), m.ram[map.player_status]);
    try std.testing.expectEqual(10, m.ram[map.room_number]); // on to the Ray Guns
}

test "locked away: the transmitter up to the key, the pole down to the lock" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 17); // the booth at x 128, its one pad upstairs at x 136
    while (explorer(m).box.x > 132) hold(m, machine.joy.left, 2); // into the booth
    hold(m, machine.joy.fire, 4);
    try std.testing.expectEqual(128 - 21, explorer(m).box.y); // upstairs
    hold(m, machine.joy.right, 200);
    hold(m, machine.joy.fire, 4);
    try std.testing.expect(locks.carrying(m, @intFromEnum(Color.light_blue)));
    while (feet(m) > 103) hold(m, machine.joy.left, 2); // onto the pole (x 100)
    hold(m, machine.joy.down, 200);
    try std.testing.expectEqual(192 - 21, explorer(m).box.y);
    while (feet(m) > 50) hold(m, machine.joy.left, 2);
    hold(m, machine.joy.fire, 4);
    try std.testing.expectEqual(1, objects.slot(m, objects.find(m, .door, 1).?).open);
}

test "ray guns: past the muzzle, the gun shoots him" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 10); // he comes in behind the gun, which faces right from x 60
    var lasers: usize = 0;
    while (m.ram[map.player_status] == @intFromEnum(player.Status.playing)) {
        hold(m, machine.joy.right, 2);
        lasers = @max(lasers, count(m, .laser));
    }
    try std.testing.expectEqual(@intFromEnum(player.Status.dead), m.ram[map.player_status]);
    try std.testing.expectEqual(1, lasers); // one at a time
    try std.testing.expect(feet(m) > 68 and feet(m) < 140); // past the muzzle, short of the bell
}

test "ray guns: steer the gun up from its panel, then run past it" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 10);
    try escapeRayGuns(m);
}

test "ray guns: shot once, the room can still be won from its door" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 10);
    while (m.ram[map.player_status] == @intFromEnum(player.Status.playing)) hold(m, machine.joy.right, 2);
    hold(m, 0, 100); // back at the castle's start, the gun left on the floor's row
    try std.testing.expectEqual(0, m.ram[map.room_number]);
    for (0..10) |_| { // N ten times: by door 0, the gun where it was
        m.input = .{ .key = 'N' };
        _ = m.runFrame(@This());
        m.input = .{};
        hold(m, 0, 14);
    }
    try std.testing.expectEqual(10, m.ram[map.room_number]);
    try std.testing.expect(m.view(castle.RayGun, room.first(m, .ray_gun).?).gun_y > 166); // in range of the floor
    try escapeRayGuns(m);
}

test "under fire: the forcefield stops the lasers, and without it they hit" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 15); // the gun faces right from x 72, at the field at x 88
    var lasers: usize = 0;
    for (0..200) |_| {
        hold(m, machine.joy.left, 2); // up against the field, and leaning on it
        lasers += count(m, .laser);
        try std.testing.expectEqual(@intFromEnum(player.Status.playing), m.ram[map.player_status]);
    }
    try std.testing.expect(lasers > 0);

    // Back to the button, and down goes his shield.
    while (explorer(m).box.x < 138) hold(m, machine.joy.right, 2);
    hold(m, machine.joy.fire, 4);
    hold(m, 0, 100);
    try std.testing.expectEqual(@intFromEnum(player.Status.dead), m.ram[map.player_status]);
}

test "under fire: send the gun up from its panel, then take the field down and run" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 15);
    const gun = m.view(castle.RayGun, room.first(m, .ray_gun).?);
    while (feet(m) > 115) hold(m, machine.joy.left, 2); // the ladder, at x 112
    hold(m, machine.joy.up, 200);
    while (feet(m) < 121) hold(m, machine.joy.right, 2); // the panel, at x 120
    while (gun.gun_y != gun.y) hold(m, machine.joy.up, 2);
    while (feet(m) > 115) hold(m, machine.joy.left, 2);
    hold(m, machine.joy.down, 200);
    while (explorer(m).box.x < 138) hold(m, machine.joy.right, 2);
    hold(m, machine.joy.fire, 4); // the field goes down
    while (feet(m) > 50) hold(m, machine.joy.left, 2); // past the field and the gun, to the bell
    hold(m, machine.joy.fire, 4);
    hold(m, machine.joy.left, 60);
    hold(m, machine.joy.up | machine.joy.right, 4);
    try std.testing.expectEqual(@intFromEnum(player.Status.doorway), m.ram[map.player_status]);
    try std.testing.expectEqual(16, m.ram[map.room_number]);
}

test "with all eight sprites busy, the gun holds its fire until one is free" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 10); // the explorer is actor 0
    const n = objects.find(m, .gun, 0) orelse return error.NoGun;
    const gun = m.view(castle.RayGun, objects.slot(m, n).record);
    while (actors.add(m, .laser)) |_| {} // fill slots 1 to 7
    m.ram[map.game_tick] = 0; // the gun's turn
    gun.state = .{ .left = true, .steered = true, .fire = true }; // as if his panel said "fire"
    guns.run(m, n);
    try std.testing.expect(!gun.state.shot);
    try std.testing.expect(!gun.state.fire); // that press is used up
    actors.slot(m, 5).state = .{ .unused = true };
    gun.state.steered = true;
    gun.state.fire = true;
    guns.run(m, n);
    try std.testing.expect(gun.state.shot);
    try std.testing.expectEqual(5, objects.slot(m, n).actor); // the laser took the free slot
    try std.testing.expectEqual(actors.Kind.laser, actors.slot(m, 5).kind);
}

test "the mummy: past the ankh he climbs out, and keeps under you along his floor" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 11); // in upstairs; the ankh at x 48, the tomb on the floor below
    const u = m.view(castle.Mummy, room.first(m, .mummy).?);
    hold(m, 0, 200); // reading the sign: nothing stirs
    try std.testing.expectEqual(castle.mummy_tomb, u.state);
    try std.testing.expectEqual(0, count(m, .mummy));
    while (feet(m) < 56) hold(m, machine.joy.right, 2); // past the ankh
    try std.testing.expectEqual(castle.mummy_out, u.state);
    try std.testing.expectEqual(1, count(m, .mummy));
    hold(m, 0, 120); // he climbs out, and walks along under you
    const mummy = monster(m, .mummy).?;
    try std.testing.expectEqual(192 - 21, mummy.box.y); // on the floor
    try std.testing.expect(distance(mummy.box.x, explorer(m).box.x) < 2);
    try std.testing.expectEqual(mummy.box.x, u.x); // and the castle knows where
    try escapeMummy(m);
}

test "the mummy: caught once, he's still out, and the room can still be won" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 11);
    while (feet(m) < 56) hold(m, machine.joy.right, 2);
    while (feet(m) < 129) hold(m, machine.joy.right, 2); // to the pole, slowly enough
    hold(m, 0, 200); // for him to be waiting at its foot
    while (m.ram[map.player_status] == @intFromEnum(player.Status.playing)) hold(m, machine.joy.down, 2);
    try std.testing.expectEqual(@intFromEnum(player.Status.dead), m.ram[map.player_status]);
    hold(m, 0, 100);
    back(m, 11);
    try std.testing.expectEqual(castle.mummy_out, m.view(castle.Mummy, room.first(m, .mummy).?).state);
    try std.testing.expect(monster(m, .mummy).?.box.x > 110); // where he caught him, by the pole
    try escapeMummy(m);
}

test "Frankenstein: he sleeps until you're on his floor, then paces it end to end" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 12); // in upstairs; his alcove on the floor below, facing right
    const f = m.view(castle.Frankenstein, room.first(m, .frankenstein).?);
    hold(m, 0, 200);
    try std.testing.expect(!f.state.awake);
    while (feet(m) < 89) hold(m, machine.joy.right, 2); // onto the pole
    hold(m, machine.joy.down, 70);
    try std.testing.expectEqual(192 - 21, explorer(m).box.y);
    hold(m, 0, 4);
    try std.testing.expect(f.state.awake);
    // Run for the door; he's only half as fast.
    while (feet(m) < 141) hold(m, machine.joy.right, 2);
    hold(m, machine.joy.fire, 4);
    hold(m, machine.joy.right, 60);
    hold(m, machine.joy.up | machine.joy.right, 4);
    try std.testing.expectEqual(@intFromEnum(player.Status.doorway), m.ram[map.player_status]);
    try std.testing.expectEqual(13, m.ram[map.room_number]);
    try std.testing.expect(f.frank_x > 40 and f.frank_x < 120); // on his way
}

test "Frankenstein: caught once, he paces his floor, and you go down behind him" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 12);
    while (feet(m) < 89) hold(m, machine.joy.right, 2);
    hold(m, machine.joy.down, 70);
    while (m.ram[map.player_status] == @intFromEnum(player.Status.playing)) hold(m, 0, 2); // he comes for you
    hold(m, 0, 100);
    back(m, 12);
    try std.testing.expect(m.view(castle.Frankenstein, room.first(m, .frankenstein).?).state.awake);
    // Wait upstairs, by the pole, until he passes under it going left.
    while (feet(m) < 89) hold(m, machine.joy.right, 2);
    var frank = monster(m, .frankenstein).?;
    while (!(frank.way == 6 and frank.box.x < 80)) hold(m, 0, 2);
    hold(m, machine.joy.down, 70);
    while (feet(m) < 141) hold(m, machine.joy.right, 2);
    hold(m, machine.joy.fire, 4);
    hold(m, machine.joy.right, 60);
    hold(m, machine.joy.up | machine.joy.right, 4);
    try std.testing.expectEqual(13, m.ram[map.room_number]);
    frank = monster(m, .frankenstein) orelse return error.NoFrank;
    try std.testing.expect(frank.box.x < 100);
}

test "Frankenstein: asleep, a bolt can't touch him; awake, it's the end of him" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 12);
    hold(m, 0, 4);
    const f = m.view(castle.Frankenstein, room.first(m, .frankenstein).?);
    const frank = monster(m, .frankenstein).?;
    const bolt = actors.add(m, .lightning).?; // a bolt with no machine, standing on him
    actors.slot(m, bolt).box.x = frank.box.x + 2;
    actors.slot(m, bolt).box.y = frank.box.y;
    actors.setFrame(m, bolt, .bolt_0);
    hold(m, 0, 100);
    try std.testing.expect(!f.state.dead);
    while (feet(m) < 89) hold(m, machine.joy.right, 2); // down to his floor, to wake him
    hold(m, machine.joy.down, 70);
    try std.testing.expect(f.state.dead);
    hold(m, 0, 100); // he flickers out
    try std.testing.expectEqual(0, count(m, .frankenstein));
}

test "a trap for Frank: the switch, then wait, and he climbs down into the hole" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 13); // in upstairs on the left; he paces the walkway on the right
    hold(m, 0, 200);
    try std.testing.expectEqual(128 - 21, monster(m, .frankenstein).?.box.y); // he stays up there
    while (feet(m) < 81) hold(m, machine.joy.right, 2); // the pole, at x 80
    hold(m, machine.joy.down, 70);
    try trapFrank(m);
}

test "a trap for Frank: without the switch, he comes down alive" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 13);
    while (feet(m) < 81) hold(m, machine.joy.right, 2);
    hold(m, machine.joy.down, 70);
    while (monster(m, .frankenstein).?.box.y != 192 - 21) hold(m, 0, 2);
    try std.testing.expect(!m.view(castle.Frankenstein, room.first(m, .frankenstein).?).state.dead);
}

test "a trap for Frank: caught once, lead him back up, and the trap still works" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 13);
    while (feet(m) < 81) hold(m, machine.joy.right, 2);
    hold(m, machine.joy.down, 70);
    while (m.ram[map.player_status] == @intFromEnum(player.Status.playing)) hold(m, 0, 2);
    hold(m, 0, 100);
    back(m, 13);
    try std.testing.expectEqual(192 - 21, monster(m, .frankenstein).?.box.y); // he's on the floor now
    while (feet(m) < 92) hold(m, machine.joy.right, 2); // the end of your walkway, near his ladder
    while (monster(m, .frankenstein).?.box.y != 128 - 21) hold(m, 0, 2); // he climbs back up
    while (feet(m) > 81) hold(m, machine.joy.left, 2);
    hold(m, machine.joy.down, 70);
    try trapFrank(m);
}

test "Frank's ride: the belt brings him fast; turned round, it holds him on the spot" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 14); // in upstairs; the belt runs right, from his alcove towards the pole
    while (feet(m) < 105) hold(m, machine.joy.right, 2); // the pole, at x 104
    hold(m, machine.joy.down, 70); // onto his floor: he wakes
    while (feet(m) < 119) hold(m, machine.joy.right, 2); // to the control box
    const frank = monster(m, .frankenstein).?;
    while (frank.box.x + player.feet_x < 58) hold(m, 0, 2); // walking to the belt
    const on = frank.box.x;
    hold(m, 0, 8); // two of his turns on the belt
    try std.testing.expectEqual(on + 6, frank.box.x); // a fat pixel walking and two riding, each turn
    try rideOut(m);
}

test "Frank's ride: caught once, he's on your side, and the belt sends him back" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 14);
    while (feet(m) < 105) hold(m, machine.joy.right, 2);
    hold(m, machine.joy.down, 70);
    while (m.ram[map.player_status] == @intFromEnum(player.Status.playing)) hold(m, 0, 2); // he rides over to you
    hold(m, 0, 100);
    back(m, 14);
    while (feet(m) < 105) hold(m, machine.joy.right, 2);
    const frank = monster(m, .frankenstein).?;
    try std.testing.expect(frank.box.x > 88); // past the belt, on your side
    while (!(frank.way == 6 and frank.box.x < 92)) hold(m, 0, 2); // back at the belt, held by it
    hold(m, machine.joy.down, 70);
    try rideOut(m);
}

test "mummy in a storm: one throw, and he's gone and the door is clear" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 16); // in upstairs on the right; the mummy is out, on the floor
    hold(m, 0, 4);
    try std.testing.expectEqual(1, count(m, .lightning)); // the one by the door
    try stormOut(m);
}

test "mummy in a storm: caught once, the same throw still works" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 16);
    hold(m, 0, 200); // he comes along under you
    while (feet(m) > 102) hold(m, machine.joy.left, 2); // to the ladder, at x 100
    while (m.ram[map.player_status] == @intFromEnum(player.Status.playing)) hold(m, machine.joy.down, 2); // and down onto him
    hold(m, 0, 100);
    back(m, 16);
    try std.testing.expectEqual(castle.mummy_out, m.view(castle.Mummy, room.first(m, .mummy).?).state);
    try stormOut(m);
}

/// The explorer's actor slot.
fn explorer(m: *Machine) *align(1) actors.Actor {
    return actors.slot(m, @intCast(m.ram[map.player_actor]));
}

/// From the Ray Guns room's door 0: the panel, the gun to the top of its
/// track and a shot from there, then along the floor and out by door 1.
fn escapeRayGuns(m: *Machine) !void {
    const gun = m.view(castle.RayGun, room.first(m, .ray_gun).?);
    while (feet(m) < 41) hold(m, machine.joy.right, 2); // the panel, at x 40
    const before = gun.gun_y;
    hold(m, 0, 40); // standing at it, the gun holds still
    try std.testing.expectEqual(before, gun.gun_y);
    while (gun.gun_y != gun.y) hold(m, machine.joy.up, 2); // up to the top of its track
    hold(m, machine.joy.fire, 4); // and fire it, high over the room
    hold(m, 0, 8); // the gun hears it on its next turn
    try std.testing.expectEqual(1, count(m, .laser));
    try std.testing.expect(gun.state.shot);
    hold(m, 0, 60);
    try std.testing.expectEqual(0, count(m, .laser));
    try std.testing.expect(!gun.state.shot);

    // Along the floor past the gun, while it comes back down.
    while (feet(m) < 143) hold(m, machine.joy.right, 2); // to the bell
    hold(m, machine.joy.fire, 4);
    hold(m, machine.joy.right, 60);
    hold(m, machine.joy.up | machine.joy.right, 4);
    try std.testing.expectEqual(@intFromEnum(player.Status.doorway), m.ram[map.player_status]);
    try std.testing.expectEqual(11, m.ram[map.room_number]);
}

/// The first actor of `kind` in the room, if there is one.
fn monster(m: *Machine, kind: actors.Kind) ?*align(1) actors.Actor {
    for (actors.table(m)) |*a| {
        if (!a.state.unused and a.kind == kind) return a;
    }
    return null;
}

/// How far apart two X positions are.
fn distance(a: u8, b: u8) u8 {
    return if (a > b) a - b else b - a;
}

/// Back at the castle's start after a death: N `n` times, to room n's
/// door 0, with the castle as he left it.
fn back(m: *Machine, n: usize) void {
    for (0..n) |_| {
        m.input = .{ .key = 'N' };
        _ = m.runFrame(@This());
        m.input = .{};
        hold(m, 0, 14);
    }
}

/// From the Mummy room's door 0, with the mummy out on the floor: lead
/// him to the left end, then run for the pole, down, the bell and the door.
fn escapeMummy(m: *Machine) !void {
    while (feet(m) > 19) hold(m, machine.joy.left, 2);
    while (distance(monster(m, .mummy).?.box.x, explorer(m).box.x) >= 2) hold(m, 0, 2);
    while (feet(m) < 129) hold(m, machine.joy.right, 2);
    hold(m, machine.joy.down, 70);
    while (feet(m) < 141) hold(m, machine.joy.right, 2);
    hold(m, machine.joy.fire, 4);
    hold(m, machine.joy.right, 60);
    hold(m, machine.joy.up | machine.joy.right, 4);
    try std.testing.expectEqual(@intFromEnum(player.Status.doorway), m.ram[map.player_status]);
    try std.testing.expectEqual(12, m.ram[map.room_number]);
}

/// On the floor of A Trap for Frank, below the pole: the switch, wait
/// for him to climb down into the hole, the switch again, then up his
/// ladder to the door.
fn trapFrank(m: *Machine) !void {
    const trapdoor = m.view(castle.Trapdoor, room.first(m, .trapdoor).?);
    const f = m.view(castle.Frankenstein, room.first(m, .frankenstein).?);
    while (feet(m) > 66) hold(m, machine.joy.left, 2); // onto the switch, at x 64
    hold(m, 0, 10);
    try std.testing.expect(trapdoor.state & castle.trapdoor_open != 0);
    while (count(m, .frankenstein) != 0) hold(m, 0, 2); // down he comes
    try std.testing.expect(f.state.dead);
    hold(m, machine.joy.left, 8); // off the switch, and on again
    while (feet(m) < 64) hold(m, machine.joy.right, 2);
    hold(m, 0, 10);
    try std.testing.expect(trapdoor.state & castle.trapdoor_open == 0);
    while (feet(m) < 125) hold(m, machine.joy.right, 2); // over the trapdoor to his ladder
    hold(m, machine.joy.up, 70);
    while (feet(m) < 141) hold(m, machine.joy.right, 2);
    hold(m, machine.joy.fire, 4);
    hold(m, machine.joy.right, 60);
    hold(m, machine.joy.up | machine.joy.right, 4);
    try std.testing.expectEqual(@intFromEnum(player.Status.doorway), m.ram[map.player_status]);
    try std.testing.expectEqual(14, m.ram[map.room_number]);
}

/// On the floor of Frank's Ride, below the pole: the control twice (the
/// belt stops, then runs left), and he walks on the spot at its far end
/// while you ring and go.
fn rideOut(m: *Machine) !void {
    const belt = m.view(castle.Conveyor, room.first(m, .conveyor).?);
    while (feet(m) < 119) hold(m, machine.joy.right, 2); // at the control box
    hold(m, machine.joy.fire, 4);
    hold(m, 0, 4);
    hold(m, machine.joy.fire, 4);
    try std.testing.expect(belt.state & castle.conveyor_on != 0 and belt.state & castle.conveyor_left != 0);
    const frank = monster(m, .frankenstein).?;
    hold(m, 0, 300);
    for (0..100) |_| {
        hold(m, 0, 2);
        try std.testing.expect(frank.box.x + player.feet_x >= 54 and frank.box.x + player.feet_x <= 57); // on the spot
    }
    while (feet(m) < 141) hold(m, machine.joy.right, 2);
    hold(m, machine.joy.fire, 4);
    hold(m, machine.joy.right, 60);
    hold(m, machine.joy.up | machine.joy.right, 4);
    try std.testing.expectEqual(@intFromEnum(player.Status.doorway), m.ram[map.player_status]);
    try std.testing.expectEqual(15, m.ram[map.room_number]);
}

/// Mummy in a Storm, from upstairs: to the switch, wait for him to come
/// under you, throw it up, then down the ladder and out by the bell.
fn stormOut(m: *Machine) !void {
    const u = m.view(castle.Mummy, room.first(m, .mummy).?);
    while (feet(m) > 126) hold(m, machine.joy.left, 2); // under the lever, at x 124
    while (distance(monster(m, .mummy).?.box.x, explorer(m).box.x) >= 2) hold(m, 0, 2);
    hold(m, machine.joy.up, 4);
    hold(m, 0, 40);
    try std.testing.expectEqual(castle.mummy_dead, u.state);
    try std.testing.expectEqual(0, count(m, .mummy));
    while (feet(m) > 102) hold(m, machine.joy.left, 2); // the ladder
    hold(m, machine.joy.down, 70);
    while (feet(m) > 55) hold(m, machine.joy.left, 2); // the bell, past the dead machine
    hold(m, machine.joy.fire, 4);
    hold(m, machine.joy.left, 60);
    hold(m, machine.joy.up | machine.joy.right, 4);
    try std.testing.expectEqual(@intFromEnum(player.Status.doorway), m.ram[map.player_status]);
    try std.testing.expectEqual(17, m.ram[map.room_number]);
}

/// Where his feet are, across the room.
fn feet(m: *Machine) u8 {
    return explorer(m).box.x + player.feet_x;
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

/// How many actors of `kind` are in the room.
fn count(m: *Machine, kind: actors.Kind) usize {
    var n: usize = 0;
    for (actors.table(m)) |a| {
        if (!a.state.unused and a.kind == kind) n += 1;
    }
    return n;
}

/// Hold joystick 1's `stick` switches for `frames` frames, then let go.
fn hold(m: *Machine, stick: u8, frames: usize) void {
    m.input = .{ .joy1 = stick };
    for (0..frames) |_| _ = m.runFrame(@This());
    m.input = .{};
}
