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
        // raised forcefield and open trapdoor: two cells each.
        const plan = @field(training.plan.rooms, @tagName(name));
        var walls = plan.forcefield.len;
        for (plan.trapdoor) |t| walls += t.state & castle.trapdoor_open;
        try std.testing.expectEqual(2 * walls, differ);
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

/// The explorer's actor slot.
fn explorer(m: *Machine) *align(1) actors.Actor {
    return actors.slot(m, @intCast(m.ram[map.player_actor]));
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
