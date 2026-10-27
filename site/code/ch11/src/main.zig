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
const game = @import("game.zig");
const chart = @import("chart.zig");
const escape = @import("escape.zig");
const clock = @import("clock.zig");
const sound = @import("sound.zig");
const tunes = @import("tunes.zig");
const files = @import("files.zig");
const master = @import("master.zig");
const menu = @import("menu.zig");
const scores = @import("scores.zig");
const position = @import("position.zig");

/// The disk that comes with the game. The machine puts it in the drive
/// when it powers on; the game reads its castles from there, like any
/// other disk.
pub const disk = master.image;

/// What the game is doing. Power-on memory is 0, so it starts by drawing
/// the title screen. Every screen has a `draw_` mode, a frame with the
/// display blanked, before the frames it's on.
const Mode = enum(u8) {
    draw_title,
    title,
    draw_map,
    map,
    draw_room,
    room,
    draw_escape,
    escape,
    draw_over,
    over,
    draw_menu,
    menu,
    draw_times,
    times,
    draw_name,
    name,
};

/// Meter buckets, so the meter can say where each frame went.
const bucket_drawing = 1;
const bucket_sprites = 2;
const bucket_actors = 3;
const bucket_objects = 4;
const bucket_sound = 5;

pub fn boot(m: *Machine) void {
    m.poke(hw.border, @intFromEnum(Color.blue));
    m.poke(hw.background, @intFromEnum(Color.black));
    screen.start(m);
    text.start(m);
    m.load(map.shape_table.first, shapes.table);
    m.load(map.stars.first, &title.star_map);
    m.poke(map.shell_signing, 0xFF); // nobody's signing a best time
    player.start(m);
    dice.start(m);
    sound.start(m);
}

pub fn frame(m: *Machine) void {
    // The music keeps time first: whatever the frame goes on to do, the
    // next commands are due now.
    m.bucket(bucket_sound);
    sound.step(m);
    m.bucket(0);
    switch (mode(m)) {
        .draw_title => {
            m.poke(hw.control, 0); // blank first, inside the first 3,213 cycles
            // The first time: the disk's castles, and the first of them.
            if (m.peek(map.shell_disk) == @intFromEnum(files.Disk.unread)) files.powerOn(m);
            m.bucket(bucket_drawing);
            title.draw(m);
            sound.music(m, .title);
            setMode(m, .title); // the display comes back on next frame
        },
        .title => {
            if (menu.asked(m)) {
                setMode(m, .draw_menu);
            } else if (game.chosen(m)) |two| {
                m.poke(hw.control, 0); // the copy of the castle is a loading pause
                sound.stop(m);
                game.start(m, two);
                _ = game.next(m);
                setMode(m, .draw_map);
            } else {
                m.poke(hw.control, machine.display_on); // before the beam reaches the display
                m.bucket(bucket_drawing);
                title.twinkle(m);
            }
        },
        .draw_map => {
            m.poke(hw.control, 0);
            m.bucket(bucket_drawing);
            chart.draw(m);
            setMode(m, .map);
        },
        .map => {
            m.poke(hw.control, machine.display_on);
            if (position.asked(m)) {
                m.poke(map.shell_saving, 1);
                setMode(m, .draw_name);
            } else if (chart.wait(m) or room.flip(m)) setMode(m, .draw_room);
        },
        .draw_room => {
            m.poke(hw.control, 0);
            m.bucket(bucket_sprites);
            actors.clear(m); // first: preparing the room can add actors
            m.bucket(bucket_drawing);
            room.draw(m); // and its objects
            debug.overlay(m);
            m.bucket(bucket_sprites);
            player.arrive(m);
            setMode(m, .room);
        },
        .room => {
            // Hardware first. The beam reaches the top of the display 3,213
            // cycles into the frame; registers written before then can't tear.
            m.poke(hw.control, machine.display_on);
            m.bucket(bucket_sprites);
            actors.show(m);
            m.bucket(0);
            clock.tick(m);

            // Then the castle itself, one engine step every other frame:
            // 25 a second. What it decides shows up next frame.
            if (m.peek(map.game_tick) & 1 == 0) {
                m.bucket(bucket_actors);
                actors.step(m);
                m.bucket(bucket_objects);
                objects.step(m);
                m.bucket(0);
                if (player.roomOver(m)) setMode(m, switch (game.after(m)) {
                    .map => .draw_map,
                    .escape => .draw_escape,
                    .over => .draw_over,
                });
            }
            m.bucket(0);
            if (debug.keys(m) or room.flip(m)) setMode(m, .draw_room);
        },
        .draw_escape => {
            m.poke(hw.control, 0);
            m.bucket(bucket_drawing);
            escape.draw(m);
            setMode(m, .escape);
        },
        .escape => {
            m.poke(hw.control, machine.display_on);
            m.bucket(bucket_sprites);
            actors.show(m);
            m.bucket(bucket_drawing);
            if (escape.run(m)) {
                const who: player.Number = @intCast(game.between(m).escape.who);
                setMode(m, if (scores.earned(m, who)) .draw_times else if (game.escaper(m) != null) .draw_escape else .draw_over);
            }
        },
        .draw_over => {
            m.poke(hw.control, 0);
            m.bucket(bucket_drawing);
            game.drawOver(m);
            setMode(m, .over);
        },
        .over => {
            m.poke(hw.control, machine.display_on);
            if (game.over(m)) setMode(m, if (game.next(m)) .draw_map else .draw_title);
        },
        .draw_menu => {
            m.poke(hw.control, 0);
            m.bucket(bucket_drawing);
            menu.draw(m);
            setMode(m, .menu);
        },
        .menu => {
            m.poke(hw.control, machine.display_on);
            m.bucket(bucket_drawing);
            switch (menu.run(m)) {
                .nothing => {},
                .exit, .castle => setMode(m, .draw_title),
                .best_times => setMode(m, .draw_times),
                .resume_game => {
                    m.poke(map.shell_saving, 0);
                    setMode(m, .draw_name);
                },
            }
        },
        .draw_times => {
            m.poke(hw.control, 0);
            m.bucket(bucket_drawing);
            scores.draw(m);
            setMode(m, .times);
        },
        .times => {
            m.poke(hw.control, machine.display_on);
            const signed = m.peek(map.shell_signing) != 0xFF;
            m.bucket(bucket_drawing);
            if (scores.run(m)) setMode(m, if (!signed) .draw_menu else if (game.escaper(m) != null) .draw_escape else .draw_over);
        },
        .draw_name => {
            m.poke(hw.control, 0);
            m.bucket(bucket_drawing);
            position.draw(m);
            setMode(m, .name);
        },
        .name => {
            m.poke(hw.control, machine.display_on);
            m.bucket(bucket_drawing);
            const saving = m.peek(map.shell_saving) != 0;
            if (position.run(m)) |done| {
                if (saving) {
                    setMode(m, .draw_map); // saved or not, back to the map
                } else if (done) {
                    sound.stop(m);
                    _ = game.next(m);
                    setMode(m, .draw_map);
                } else setMode(m, .draw_menu);
            }
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

test "fire on the title screen starts a game: the map, then the room" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.boot(@This());

    _ = m.runFrame(@This()); // draws the title
    try std.testing.expectEqual(machine.FrameKind.loading, m.last.kind);
    try std.testing.expectEqual(@intFromEnum(Mode.title), m.ram[map.game_mode]);

    m.input = .{ .joy1 = machine.joy.fire };
    _ = m.runFrame(@This()); // the press, and a fresh castle
    try std.testing.expectEqual(machine.FrameKind.loading, m.last.kind);
    m.input = .{};
    _ = m.runFrame(@This()); // draws the map
    try std.testing.expectEqual(@intFromEnum(Mode.map), m.ram[map.game_mode]);
    try std.testing.expectEqual(0, m.ram[castle.two]); // a game for one
    hold(m, 0, 20);
    try std.testing.expectEqual(@intFromEnum(Mode.map), m.ram[map.game_mode]); // it waits for him
    hold(m, machine.joy.fire, 1);
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
    _ = m.runFrame(@This()); // draws the map, for room 0
    try std.testing.expectEqual(0, m.ram[castle.room]);

    m.input = .{ .key = 'N' };
    _ = m.runFrame(@This()); // the key, on the map
    m.input = .{};
    try std.testing.expectEqual(0, m.ram[hw.key]); // acknowledged
    _ = m.runFrame(@This()); // draws room 1
    try std.testing.expectEqual(machine.FrameKind.loading, m.last.kind);
    try std.testing.expectEqual(1, m.ram[castle.room]);

    // P twice: back to room 0, then round to the final room.
    for (0..2) |_| {
        m.input = .{ .key = 'P' };
        _ = m.runFrame(@This());
        m.input = .{};
        _ = m.runFrame(@This());
    }
    try std.testing.expectEqual(std.enums.values(training.Room).len, m.ram[castle.room]);
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
    const names = std.enums.values(training.Room);
    inline for (0..names.len + 1) |n| { // and the final room, after the last
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
        const plan = if (n == names.len) training.plan.final.? else @field(training.plan.rooms, @tagName(names[n]));
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
    try std.testing.expectEqual(@intFromEnum(player.Status.playing), m.ram[castle.status]);
    hold(m, machine.joy.up | machine.joy.right, 4);
    try std.testing.expectEqual(@intFromEnum(player.Status.doorway), m.ram[castle.status]);
    try std.testing.expectEqual(1, m.ram[castle.room]); // the Long Gallery
    try std.testing.expectEqual(0, m.ram[castle.door]); // by its door 0
    onward(m); // the map, and fire
    hold(m, 0, 160);
    try std.testing.expectEqual(@intFromEnum(Mode.room), m.ram[map.game_mode]);
    try std.testing.expectEqual(@intFromEnum(player.Status.playing), m.ram[castle.status]);
    try std.testing.expectEqual(16 + 6, explorer(m).box.x); // walked out, in front of it
    try std.testing.expectEqual(160 + 11, explorer(m).box.y);

    // The way back is open already: the Gatehouse's door stays open.
    hold(m, machine.joy.up | machine.joy.right, 4);
    onward(m);
    hold(m, 0, 160);
    try std.testing.expectEqual(0, m.ram[castle.room]);
    try std.testing.expectEqual(1, objects.slot(m, 0).open);
    try std.testing.expectEqual(156 + 6, explorer(m).box.x);
}

test "X: a flicker, a life lost, back to the start; no lives left, GAME OVER" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 2); // the Ladders room
    try std.testing.expectEqual(3, m.ram[castle.lives]);
    m.input = .{ .key = 'X' };
    _ = m.runFrame(@This());
    m.input = .{};
    hold(m, 0, 8);
    try std.testing.expect(explorer(m).state.dying);
    try std.testing.expectEqual(0, m.ram[hw.sprite_multicolor] & 1); // one colour while he flickers
    onward(m);
    try std.testing.expectEqual(2, m.ram[castle.lives]);
    try std.testing.expectEqual(0, m.ram[castle.room]); // the castle's start
    try std.testing.expectEqual(156 + 6, explorer(m).box.x);
    for (0..2) |i| {
        m.input = .{ .key = 'X' };
        _ = m.runFrame(@This());
        m.input = .{};
        if (i == 0) onward(m) else hold(m, 0, 120);
    }
    try std.testing.expectEqual(0, m.ram[castle.lives]);
    try std.testing.expectEqual(0, m.ram[castle.in_game]);
    try std.testing.expectEqual(@intFromEnum(Mode.over), m.ram[map.game_mode]);
    hold(m, 0, 210);
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
    try std.testing.expectEqual(@intFromEnum(player.Status.dead), m.ram[castle.status]);

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
    try std.testing.expectEqual(@intFromEnum(player.Status.playing), m.ram[castle.status]);
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
    while (m.ram[castle.status] == @intFromEnum(player.Status.playing)) hold(m, machine.joy.left, 2);
    try std.testing.expectEqual(@intFromEnum(player.Status.dead), m.ram[castle.status]);
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
    try std.testing.expectEqual(@intFromEnum(player.Status.playing), m.ram[castle.status]);
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
    try std.testing.expectEqual(@intFromEnum(player.Status.doorway), m.ram[castle.status]);
    try std.testing.expectEqual(10, m.ram[castle.room]); // on to the Ray Guns
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
    try std.testing.expect(locks.carrying(m, 0, @intFromEnum(Color.light_blue)));
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
    while (m.ram[castle.status] == @intFromEnum(player.Status.playing)) {
        hold(m, machine.joy.right, 2);
        lasers = @max(lasers, count(m, .laser));
    }
    try std.testing.expectEqual(@intFromEnum(player.Status.dead), m.ram[castle.status]);
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
    while (m.ram[castle.status] == @intFromEnum(player.Status.playing)) hold(m, machine.joy.right, 2);
    hold(m, 0, 100); // back at the castle's start, the gun left on the floor's row
    try std.testing.expectEqual(0, m.ram[castle.room]);
    for (0..10) |_| { // N ten times: by door 0, the gun where it was
        m.input = .{ .key = 'N' };
        _ = m.runFrame(@This());
        m.input = .{};
        hold(m, 0, 14);
    }
    try std.testing.expectEqual(10, m.ram[castle.room]);
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
        try std.testing.expectEqual(@intFromEnum(player.Status.playing), m.ram[castle.status]);
    }
    try std.testing.expect(lasers > 0);

    // Back to the button, and down goes his shield.
    while (explorer(m).box.x < 138) hold(m, machine.joy.right, 2);
    hold(m, machine.joy.fire, 4);
    hold(m, 0, 100);
    try std.testing.expectEqual(@intFromEnum(player.Status.dead), m.ram[castle.status]);
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
    try std.testing.expectEqual(@intFromEnum(player.Status.doorway), m.ram[castle.status]);
    try std.testing.expectEqual(16, m.ram[castle.room]);
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
    while (m.ram[castle.status] == @intFromEnum(player.Status.playing)) hold(m, machine.joy.down, 2);
    try std.testing.expectEqual(@intFromEnum(player.Status.dead), m.ram[castle.status]);
    hold(m, 0, 100);
    back(m, 11);
    try std.testing.expectEqual(castle.mummy_out, m.view(castle.Mummy, room.first(m, .mummy).?).state);
    try std.testing.expect(monster(m, .mummy).?.box.x > 110); // where he caught him, by the pole
    try escapeMummy(m);
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
    while (m.ram[castle.status] == @intFromEnum(player.Status.playing)) hold(m, machine.joy.down, 2); // and down onto him
    hold(m, 0, 100);
    back(m, 16);
    try std.testing.expectEqual(castle.mummy_out, m.view(castle.Mummy, room.first(m, .mummy).?).state);
    try stormOut(m);
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
    try std.testing.expectEqual(@intFromEnum(player.Status.doorway), m.ram[castle.status]);
    try std.testing.expectEqual(13, m.ram[castle.room]);
    try std.testing.expect(f.frank_x > 40 and f.frank_x < 120); // on his way
}

test "Frankenstein: caught once, he paces his floor, and you go down behind him" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 12);
    while (feet(m) < 89) hold(m, machine.joy.right, 2);
    hold(m, machine.joy.down, 70);
    while (m.ram[castle.status] == @intFromEnum(player.Status.playing)) hold(m, 0, 2); // he comes for you
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
    try std.testing.expectEqual(13, m.ram[castle.room]);
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
    while (m.ram[castle.status] == @intFromEnum(player.Status.playing)) hold(m, 0, 2);
    hold(m, 0, 100);
    back(m, 13);
    try std.testing.expectEqual(192 - 21, monster(m, .frankenstein).?.box.y); // he's on the floor now
    while (feet(m) < 84) hold(m, machine.joy.right, 2); // the end of your walkway, near his ladder
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
    while (m.ram[castle.status] == @intFromEnum(player.Status.playing)) hold(m, 0, 2); // he rides over to you
    hold(m, 0, 100);
    back(m, 14);
    while (feet(m) < 105) hold(m, machine.joy.right, 2);
    const frank = monster(m, .frankenstein).?;
    try std.testing.expect(frank.box.x > 88); // past the belt, on your side
    while (!(frank.way == 6 and frank.box.x < 92)) hold(m, 0, 2); // back at the belt, held by it
    hold(m, machine.joy.down, 70);
    try rideOut(m);
}

/// Player 1's actor slot.
fn explorer(m: *Machine) *align(1) actors.Actor {
    return actors.slot(m, @intCast(player.record(m, 0).actor));
}

/// From the Ray Guns room's door 0: the panel, the gun to the top of its
/// track and a shot from there, then along the floor and out by door 1.
fn escapeRayGuns(m: *Machine) !void {
    const gun = m.view(castle.RayGun, room.first(m, .ray_gun).?);
    while (feet(m) < 41) hold(m, machine.joy.right, 2); // the panel, at x 40
    hold(m, 0, 8); // a turn of the gun's, to see him there
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
    try std.testing.expectEqual(@intFromEnum(player.Status.doorway), m.ram[castle.status]);
    try std.testing.expectEqual(11, m.ram[castle.room]);
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

/// Back at the castle's start after a death: on the map, N `n` times, to
/// room n's door 0, with the castle as he left it.
fn back(m: *Machine, n: usize) void {
    while (m.ram[map.game_mode] != @intFromEnum(Mode.map)) hold(m, 0, 1);
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
    try std.testing.expectEqual(@intFromEnum(player.Status.doorway), m.ram[castle.status]);
    try std.testing.expectEqual(12, m.ram[castle.room]);
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
    try std.testing.expectEqual(@intFromEnum(player.Status.doorway), m.ram[castle.status]);
    try std.testing.expectEqual(17, m.ram[castle.room]);
}

/// On the floor of A Trap for Frank, below the pole: the switch, wait
/// for him to climb down into the hole, the switch again, then up his
/// ladder to the door. In a game for two, player 2 waits at the foot of
/// the pole and treads the switch the second time: two pairs of feet on
/// it at once would flip it twice.
fn trapFrank(m: *Machine) !void {
    const trapdoor = m.view(castle.Trapdoor, room.first(m, .trapdoor).?);
    const f = m.view(castle.Frankenstein, room.first(m, .frankenstein).?);
    while (feet(m) < 97) hold2(m, machine.joy.right, 0, 2); // onto the switch, at x 96
    hold(m, 0, 10);
    try std.testing.expect(trapdoor.state & castle.trapdoor_open != 0);
    while (count(m, .frankenstein) != 0) hold(m, 0, 2); // down he comes
    try std.testing.expect(f.state.dead);
    if (m.ram[castle.two] != 0) {
        const two = actors.slot(m, @intCast(player.record(m, 1).actor));
        while (two.box.x + player.feet_x < 97) hold2(m, 0, machine.joy.right, 2);
    } else {
        hold(m, machine.joy.left, 8); // off the switch, and on again
        while (feet(m) < 97) hold(m, machine.joy.right, 2);
    }
    hold(m, 0, 10);
    try std.testing.expect(trapdoor.state & castle.trapdoor_open == 0);
    while (feet(m) < 125) hold(m, machine.joy.right, 2); // over the trapdoor to his ladder
    hold(m, machine.joy.up, 70);
    while (feet(m) < 141) hold(m, machine.joy.right, 2);
    hold(m, machine.joy.fire, 4);
    hold(m, machine.joy.right, 60);
    hold(m, machine.joy.up | machine.joy.right, 4);
    try std.testing.expectEqual(@intFromEnum(player.Status.doorway), m.ram[castle.status]);
    try std.testing.expectEqual(14, m.ram[castle.room]);
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
    try std.testing.expectEqual(@intFromEnum(player.Status.doorway), m.ram[castle.status]);
    try std.testing.expectEqual(15, m.ram[castle.room]);
}

/// Where his feet are, across the room.
fn feet(m: *Machine) u8 {
    return explorer(m).box.x + player.feet_x;
}

/// Boot, press fire on the title, and stand in room `n`'s first doorway.
/// The map waits for fire; pressing it 8 frames after the title's press
/// keeps the frame count the rooms' clocks run on the same as ever.
fn inRoom(m: *Machine, n: u8) void {
    m.boot(@This());
    _ = m.runFrame(@This()); // draws the title
    m.input = .{ .joy1 = machine.joy.fire };
    _ = m.runFrame(@This());
    m.input = .{};
    m.ram[castle.room] = n; // instead of the castle's start room
    m.ram[map.room_number] = n;
    hold(m, 0, 7); // draws the map, and waits
    hold(m, machine.joy.fire, 1);
    _ = m.runFrame(@This()); // draws the room
}

/// Through a door or after a death: wait for the castle map, then press
/// fire, and the next room is drawn.
fn onward(m: *Machine) void {
    while (m.ram[map.game_mode] != @intFromEnum(Mode.map)) hold(m, 0, 1);
    hold(m, 0, 1);
    hold(m, machine.joy.fire, 1);
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
/// In a game for two, player 2 does just the same on joystick 2.
fn hold(m: *Machine, stick: u8, frames: usize) void {
    hold2(m, stick, if (m.ram[castle.two] != 0) stick else 0, frames);
}

/// Wait for the best times to ask, then type `initials` and Return.
fn sign(m: *Machine, comptime initials: []const u8) void {
    while (m.ram[map.game_mode] != @intFromEnum(Mode.times)) hold(m, 0, 1);
    typeIn(m, initials ++ "\r");
}

/// Type `keys`, a key a frame.
fn typeIn(m: *Machine, comptime keys: []const u8) void {
    for (keys) |c| {
        m.input = .{ .key = c };
        _ = m.runFrame(@This());
    }
    m.input = .{};
}

/// Hold the two sticks' switches for `frames` frames, then let go.
fn hold2(m: *Machine, one: u8, two: u8, frames: usize) void {
    m.input = .{ .joy1 = one, .joy2 = two };
    for (0..frames) |_| _ = m.runFrame(@This());
    m.input = .{};
}

test "the whole Training Castle, from the title to GAME OVER, through the stick" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.boot(@This());
    _ = m.runFrame(@This()); // draws the title
    hold(m, machine.joy.fire, 1);
    try wholeCastle(m);
}

/// From the title's fire to the end of the game: every room in order, in
/// at its door 0 and out by its door 1, then the escape and GAME OVER.
fn wholeCastle(m: *Machine) !void {
    onward(m); // the Gatehouse
    hold(m, machine.joy.left, 34);
    try ringAndGo(m, .right, 1);

    while (feet(m) < 116) hold(m, machine.joy.right, 2); // the Long Gallery's bell
    try ringAndGo(m, .right, 2);

    while (feet(m) < 113) hold(m, machine.joy.right, 2); // Ladders: up, and along
    hold(m, machine.joy.up, 200);
    while (feet(m) < 144) hold(m, machine.joy.right, 2);
    try ringAndGo(m, .right, 3);

    while (feet(m) < 75) hold(m, machine.joy.right, 2); // Sliding Poles: down
    hold(m, machine.joy.down, 200);
    while (feet(m) < 144) hold(m, machine.joy.right, 2);
    try ringAndGo(m, .right, 4);

    while (feet(m) < 57) hold(m, machine.joy.right, 2); // Lightning: up to the switch
    hold(m, machine.joy.up, 200);
    while (feet(m) > 34) hold(m, machine.joy.left, 2);
    hold(m, machine.joy.down, 4); // both machines off
    while (feet(m) < 57) hold(m, machine.joy.right, 2);
    hold(m, machine.joy.down, 200);
    while (feet(m) < 144) hold(m, machine.joy.right, 2);
    try ringAndGo(m, .right, 5);

    while (explorer(m).box.x > 122) hold(m, machine.joy.left, 2); // Forcefields: the button
    hold(m, machine.joy.fire, 4);
    while (feet(m) > 50) hold(m, machine.joy.left, 2);
    try ringAndGo(m, .left, 6);

    while (feet(m) > 50) hold(m, machine.joy.left, 2); // Trapdoors: the bell is first
    try ringAndGo(m, .left, 7);

    while (feet(m) > 115) hold(m, machine.joy.left, 2); // Conveyors: the high road
    hold(m, machine.joy.up, 200);
    while (feet(m) > 39) hold(m, machine.joy.left, 2);
    hold(m, machine.joy.down, 200);
    while (feet(m) < 46) hold(m, machine.joy.right, 2); // the bell, short of the hole
    try ringAndGo(m, .left, 8);

    while (explorer(m).box.x > 116) hold(m, machine.joy.left, 2); // the Transmitter's booth
    const booth = m.view(castle.Teleport, room.first(m, .teleport).?);
    while (booth.target != 0) hold2(m, machine.joy.up, 0, 2); // one at a time: both would move it twice
    teleport(m);
    while (feet(m) > 50) hold(m, machine.joy.left, 2);
    try ringAndGo(m, .left, 9);

    while (feet(m) > 115) hold(m, machine.joy.left, 2); // Keys and Locks
    hold(m, machine.joy.up, 200);
    hold(m, machine.joy.right, 200);
    hold(m, machine.joy.fire, 4); // the key
    while (feet(m) > 115) hold(m, machine.joy.left, 2);
    hold(m, machine.joy.down, 200);
    while (feet(m) > 50) hold(m, machine.joy.left, 2);
    try ringAndGo(m, .left, 10); // the lock, for a bell

    try escapeRayGuns(m);
    onward(m);
    arrived(m);
    while (feet(m) < 56) hold(m, machine.joy.right, 2); // the Mummy: past the ankh
    hold(m, 0, 120);
    try escapeMummy(m);
    onward(m);
    arrived(m);
    while (feet(m) < 89) hold(m, machine.joy.right, 2); // Frankenstein: down, and run
    hold(m, machine.joy.down, 70);
    while (feet(m) < 141) hold(m, machine.joy.right, 2);
    try ringAndGo(m, .right, 13);

    while (feet(m) < 81) hold(m, machine.joy.right, 2); // A Trap for Frank
    hold(m, machine.joy.down, 70);
    try trapFrank(m);
    onward(m);
    arrived(m);
    while (feet(m) < 105) hold(m, machine.joy.right, 2); // Frank's Ride
    hold(m, machine.joy.down, 70);
    try rideOut(m);
    onward(m);
    arrived(m);
    const gun = m.view(castle.RayGun, room.first(m, .ray_gun).?); // Under Fire
    while (feet(m) > 115) hold(m, machine.joy.left, 2);
    hold(m, machine.joy.up, 200);
    while (feet(m) < 121) hold(m, machine.joy.right, 2);
    while (gun.gun_y != gun.y) hold(m, machine.joy.up, 2);
    while (feet(m) > 115) hold(m, machine.joy.left, 2);
    hold(m, machine.joy.down, 200);
    while (explorer(m).box.x < 138) hold(m, machine.joy.right, 2);
    hold(m, machine.joy.fire, 4);
    while (feet(m) > 50) hold(m, machine.joy.left, 2);
    try ringAndGo(m, .left, 16);

    hold(m, 0, 4); // Mummy in a Storm
    try stormOut(m);
    onward(m);
    arrived(m);
    while (explorer(m).box.x > 132) hold(m, machine.joy.left, 2); // Locked Away
    teleport(m);
    hold(m, machine.joy.right, 200);
    hold(m, machine.joy.fire, 4); // the key
    while (feet(m) > 103) hold(m, machine.joy.left, 2);
    hold(m, machine.joy.down, 200);
    while (feet(m) > 50) hold(m, machine.joy.left, 2);
    try ringAndGo(m, .left, 18); // the lock

    try twosCompany(m);
    try ringAndGo(m, .left, 19);

    while (feet(m) > 50) hold(m, machine.joy.left, 2); // The Way Out
    hold(m, machine.joy.fire, 4);
    hold(m, machine.joy.left, 60);
    hold(m, machine.joy.up | machine.joy.right, 4);
    try std.testing.expectEqual(1, m.ram[castle.escaped]);
    sign(m, "ACE");
    if (m.ram[castle.two] != 0) sign(m, "DUO"); // and player 2's escape
    while (m.ram[map.game_mode] != @intFromEnum(Mode.over)) hold(m, 0, 1);
    try std.testing.expectEqual(0, m.ram[castle.in_game]);
}

/// Fire at a bell (or a lock), walk to its door, `way` along the floor,
/// and in, to room `next`: then on from the map, and wait until he's
/// walked out of its door.
fn ringAndGo(m: *Machine, way: enum { left, right }, next: u8) !void {
    hold(m, machine.joy.fire, 4);
    hold(m, if (way == .left) machine.joy.left else machine.joy.right, 60);
    hold(m, machine.joy.up | machine.joy.right, 4);
    try std.testing.expectEqual(@intFromEnum(player.Status.doorway), m.ram[castle.status]);
    try std.testing.expectEqual(next, m.ram[castle.room]);
    onward(m);
    arrived(m);
}

/// Fire in a booth. In a game for two, fire again once the pad has
/// stopped flashing: the booth sends one explorer at a time.
fn teleport(m: *Machine) void {
    hold(m, machine.joy.fire, 4);
    hold(m, 0, 70); // 32 steps of flashing
    hold(m, machine.joy.fire, 4);
}

/// Until he's walked out of the door he came in by.
fn arrived(m: *Machine) void {
    while (m.ram[castle.status] != @intFromEnum(player.Status.playing)) hold(m, 0, 2);
}

/// Two's Company, alone: up to the button, press, and run for the bell.
fn twosCompany(m: *Machine) !void {
    while (feet(m) > 139) hold(m, machine.joy.left, 2); // the ladder, at x 136
    hold(m, machine.joy.up, 200);
    while (feet(m) < 159) hold(m, machine.joy.right, 2); // the button
    hold(m, machine.joy.fire, 4);
    while (feet(m) > 139) hold(m, machine.joy.left, 2);
    hold(m, machine.joy.down, 200);
    while (feet(m) > 50) hold(m, machine.joy.left, 2); // through the field, to the bell
    try std.testing.expect(feet(m) <= 50);
}

test "the whole Training Castle for two, each doing what the other does" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.boot(@This());
    _ = m.runFrame(@This()); // draws the title
    hold2(m, 0, machine.joy.fire, 1); // fire on stick 2: a game for two
    try std.testing.expectEqual(1, m.ram[castle.two]);
    try wholeCastle(m);
    try std.testing.expectEqual(1, m.ram[castle.escaped + 1]); // player 2 got out too
    try std.testing.expectEqual(0, m.ram[castle.in_game + 1]);
    try std.testing.expectEqual(3, m.ram[castle.lives + 1]);
}

/// `inRoom`, in a game for two: fire on stick 2 at the title, and both
/// press fire on the map.
fn inRoom2(m: *Machine, n: u8) void {
    m.boot(@This());
    _ = m.runFrame(@This()); // draws the title
    hold2(m, 0, machine.joy.fire, 1);
    m.ram[castle.room] = n;
    m.ram[castle.room + 1] = n;
    m.ram[map.room_number] = n;
    hold(m, 0, 7);
    hold(m, machine.joy.fire, 1);
    _ = m.runFrame(@This()); // draws the room
}

/// Player 2's actor slot.
fn second(m: *Machine) *align(1) actors.Actor {
    return actors.slot(m, @intCast(player.record(m, 1).actor));
}

test "a game for two: both on the map, and it waits for both" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.boot(@This());
    _ = m.runFrame(@This());
    hold2(m, 0, machine.joy.fire, 1);
    try std.testing.expectEqual(1, m.ram[castle.in_game + 1]);
    hold(m, 0, 4);
    try std.testing.expectEqual(0b11, m.ram[hw.sprite_enable]); // two arrows
    hold2(m, machine.joy.fire, 0, 4);
    try std.testing.expectEqual(@intFromEnum(Mode.map), m.ram[map.game_mode]); // player 2 hasn't pressed
    hold2(m, 0, machine.joy.fire, 1);
    _ = m.runFrame(@This());
    try std.testing.expectEqual(@intFromEnum(Mode.room), m.ram[map.game_mode]);
    try std.testing.expectEqual(2, count(m, .player));
    try std.testing.expectEqual(@intFromEnum(Color.yellow), second(m).color); // player 2's coat
}

test "two's company: one holds the button, the other runs through" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom2(m, 18);
    while (feet(m) > 139) hold(m, machine.joy.left, 2); // both to the ladder
    hold2(m, machine.joy.up, 0, 200); // player 1 up it
    while (feet(m) < 159) hold2(m, machine.joy.right, 0, 2); // to the button
    const field = actors.slot(m, 0);
    hold2(m, machine.joy.fire, 0, 600); // and he holds it down, far longer than 240 steps
    try std.testing.expectEqual(@intFromEnum(shapes.Id.field_off), field.frame);
    while (second(m).box.x + player.feet_x > 50) hold2(m, machine.joy.fire, machine.joy.left, 2); // through
    hold2(m, machine.joy.fire, machine.joy.fire, 4); // the bell
    hold2(m, machine.joy.fire, machine.joy.left, 60);
    hold2(m, machine.joy.fire, machine.joy.up | machine.joy.right, 4);
    try std.testing.expectEqual(@intFromEnum(player.Status.doorway), m.ram[castle.status + 1]);
    try std.testing.expectEqual(19, m.ram[castle.room + 1]);
    try std.testing.expectEqual(@intFromEnum(Mode.room), m.ram[map.game_mode]); // the room goes on for player 1
}

test "on a ladder, the other explorer is in the way" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom2(m, 2); // Ladders: the ladder at x 112
    while (feet(m) < 113) hold(m, machine.joy.right, 2);
    hold2(m, machine.joy.up, 0, 8); // player 1 four steps up
    const y = explorer(m).box.y;
    try std.testing.expectEqual(171 - 8, y);
    hold2(m, machine.joy.down, 0, 8); // player 2 stands at its foot
    try std.testing.expectEqual(y, explorer(m).box.y);
    hold2(m, 0, machine.joy.left, 20); // he steps away
    hold2(m, machine.joy.down, 0, 8);
    try std.testing.expectEqual(171, explorer(m).box.y);
}

test "the gun turns to the nearer explorer, and the mummy goes for player 1" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom2(m, 15); // Under Fire: the ladder at x 112
    const gun = m.view(castle.RayGun, room.first(m, .ray_gun).?);
    while (feet(m) > 115) hold(m, machine.joy.left, 2);
    hold2(m, machine.joy.up, 0, 200); // player 1 upstairs, player 2 on the floor
    hold(m, 0, 100);
    try std.testing.expect(gun.gun_y > 160); // down at player 2's level

    inRoom2(m, 11); // the Mummy: in upstairs, the ankh at x 48
    while (second(m).box.x + player.feet_x < 56) hold2(m, 0, machine.joy.right, 2); // player 2 lets him out
    try std.testing.expectEqual(castle.mummy_out, m.view(castle.Mummy, room.first(m, .mummy).?).state);
    hold(m, 0, 200);
    try std.testing.expect(distance(monster(m, .mummy).?.box.x, explorer(m).box.x) < 2); // under player 1
}

test "Frankenstein wakes for player 2 too" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom2(m, 12); // upstairs; the pole at x 88
    const f = m.view(castle.Frankenstein, room.first(m, .frankenstein).?);
    while (second(m).box.x + player.feet_x < 89) hold2(m, 0, machine.joy.right, 2);
    hold2(m, 0, machine.joy.down, 70);
    hold(m, 0, 4);
    try std.testing.expect(f.state.awake);
}

test "player 2 out of lives: GAME OVER for him, and player 1 plays on" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom2(m, 0);
    for (0..3) |life| {
        // Player 1 rings and goes in; with him in the doorway, X is for
        // player 2 alone.
        while (feet(m) > 148) hold2(m, machine.joy.left, 0, 2);
        hold2(m, machine.joy.fire, 0, 4);
        while (feet(m) < 165) hold2(m, machine.joy.right, 0, 2);
        hold2(m, machine.joy.up | machine.joy.right, 0, 4);
        m.input = .{ .key = 'X' };
        _ = m.runFrame(@This());
        m.input = .{};
        try std.testing.expectEqual(@intFromEnum(player.Status.dead), m.ram[castle.status + 1]);
        if (life == 2) break;
        // Two rooms: player 1's turn (player 2 was the last to leave his),
        // and back to the Gatehouse, where they're together again.
        onward(m);
        try std.testing.expectEqual(1, m.ram[map.room_number]);
        try std.testing.expectEqual(1, count(m, .player));
        while (m.ram[castle.status] != @intFromEnum(player.Status.playing)) hold(m, 0, 2);
        hold2(m, machine.joy.up | machine.joy.right, 0, 4); // back through the open door
        while (m.ram[map.game_mode] != @intFromEnum(Mode.map)) hold(m, 0, 1);
        hold2(m, 0, 0, 1);
        hold2(m, machine.joy.fire, machine.joy.fire, 1);
        _ = m.runFrame(@This());
        try std.testing.expectEqual(2, count(m, .player));
        while (m.ram[castle.status] != @intFromEnum(player.Status.playing)) hold(m, 0, 2);
    }
    while (m.ram[map.game_mode] != @intFromEnum(Mode.over)) hold(m, 0, 1);
    try std.testing.expectEqual(0, m.ram[castle.in_game + 1]);
    try std.testing.expectEqual(1, m.ram[castle.in_game]);
    while (m.ram[map.game_mode] == @intFromEnum(Mode.over)) hold(m, 0, 1);
    try std.testing.expectEqual(@intFromEnum(Mode.draw_map), m.ram[map.game_mode]); // on for player 1
}

test "both through the way out: an escape each, then GAME OVER" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom2(m, 19);
    while (feet(m) > 50) hold(m, machine.joy.left, 2);
    hold(m, machine.joy.fire, 4);
    hold(m, machine.joy.left, 60);
    hold(m, machine.joy.up | machine.joy.right, 4);
    while (m.ram[map.game_mode] != @intFromEnum(Mode.escape)) hold(m, 0, 1);
    try std.testing.expectEqual(0, game.between(m).escape.who);
    sign(m, "ONE");
    while (m.ram[map.game_mode] != @intFromEnum(Mode.draw_escape)) hold(m, 0, 1);
    hold(m, 0, 2);
    try std.testing.expectEqual(1, game.between(m).escape.who);
    try std.testing.expectEqual(0, m.ram[castle.in_game]);
    sign(m, "TWO");
    while (m.ram[map.game_mode] != @intFromEnum(Mode.over)) hold(m, 0, 1);
    try std.testing.expectEqual(0, m.ram[castle.in_game + 1]);
}

/// Hold `stick` for up to `frames` frames, until sound effect `e` starts.
/// True if it did.
fn hear(m: *Machine, e: tunes.Effect, stick: u8, frames: usize) bool {
    for (0..frames) |_| {
        hold(m, stick, 1);
        if (m.ram[map.sound_playing] == @intFromEnum(e)) return true;
    }
    return false;
}

/// The note voice 0 is playing: its frequency register.
fn pitchNow(m: *Machine) u16 {
    return std.mem.readInt(u16, m.ram[hw.voice(0)..][0..2], .little);
}

/// Which tune the driver is in the middle of, if any.
fn song(m: *Machine) ?tunes.Song {
    if (m.ram[map.sound_playing] != sound.tune) return null;
    const at = std.mem.readInt(u16, m.ram[map.sound_at..][0..2], .little);
    var found: ?tunes.Song = null;
    for (tunes.placed, 0..) |p, i| {
        if (at >= p.at) found = @enumFromInt(i);
    }
    return found;
}

test "the title plays its tune on three voices, a game stops it, and the map closes with a chime" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.boot(@This());
    _ = m.runFrame(@This()); // draws the title
    try std.testing.expectEqual(tunes.Song.title, song(m).?);
    var gated: u8 = 0;
    for (0..200) |_| {
        hold(m, 0, 1);
        for (0..3) |v| {
            if (m.ram[hw.voice(@intCast(v)) + machine.sound.control] & machine.sound.gate != 0) gated |= @as(u8, 1) << @intCast(v);
        }
    }
    try std.testing.expectEqual(0b111, gated); // all three voices have played
    var samples: [882]f32 = undefined;
    m.listen(&samples, 44100); // and the speaker has something to say
    var loudest: f32 = 0;
    for (samples) |s| loudest = @max(loudest, @abs(s));
    try std.testing.expect(loudest > 0.05);
    hold(m, machine.joy.fire, 1);
    try std.testing.expectEqual(sound.nothing, m.ram[map.sound_playing]);
    for (0..3) |v| try std.testing.expectEqual(0, m.ram[hw.voice(@intCast(v)) + machine.sound.control]);
    hold(m, 0, 7); // the map
    try std.testing.expect(hear(m, .map_close, machine.joy.fire, 2));
}

test "a door creaks higher as it opens" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 0); // the Gatehouse
    hold(m, machine.joy.left, 34); // to the bell
    try std.testing.expect(hear(m, .door, machine.joy.fire, 8));
    var first = pitchNow(m);
    const lowest = first;
    for (0..60) |_| {
        hold(m, 0, 1);
        if (m.ram[map.sound_playing] != @intFromEnum(tunes.Effect.door)) continue;
        try std.testing.expect(pitchNow(m) >= first);
        first = pitchNow(m);
    }
    try std.testing.expect(first > lowest * 3); // two octaves up: four times the frequency, or near it
}

test "every machine in the castle has a voice, through the stick" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 4); // Lightning: up to the switch, and pull it down
    while (feet(m) < 57) hold(m, machine.joy.right, 2);
    hold(m, machine.joy.up, 200);
    while (feet(m) > 34) hold(m, machine.joy.left, 2);
    try std.testing.expect(hear(m, .lightning, machine.joy.down, 4));

    inRoom(m, 5); // Forcefields: the button, then the countdown's first tick
    while (explorer(m).box.x > 122) hold(m, machine.joy.left, 2);
    try std.testing.expect(hear(m, .forcefield, machine.joy.fire, 4));
    hold(m, 0, 10);
    const press = pitchNow(m);
    try std.testing.expect(hear(m, .forcefield, 0, 70));
    try std.testing.expect(pitchNow(m) > press);

    inRoom(m, 6); // Trapdoors: the switch on the way to the bell
    try std.testing.expect(hear(m, .trapdoor, machine.joy.left, 300));

    inRoom(m, 7); // Conveyors: the control box
    while (feet(m) > 101) hold(m, machine.joy.left, 2);
    try std.testing.expect(hear(m, .conveyor, machine.joy.fire, 4));

    inRoom(m, 8); // the Transmitter: move the lamp, then send him
    while (explorer(m).box.x > 116) hold(m, machine.joy.left, 2);
    try std.testing.expect(hear(m, .teleport_change, machine.joy.up, 40));
    hold(m, 0, 10);
    try std.testing.expect(hear(m, .teleport, machine.joy.fire, 8));

    inRoom(m, 9); // Keys and Locks: up and along to the key
    while (feet(m) > 115) hold(m, machine.joy.left, 2);
    hold(m, machine.joy.up, 200);
    hold(m, machine.joy.right, 200);
    try std.testing.expect(hear(m, .key, machine.joy.fire, 4));

    inRoom(m, 10); // Ray Guns: past the muzzle
    try std.testing.expect(hear(m, .laser, machine.joy.right, 200));

    inRoom(m, 11); // the Mummy: past the ankh, and he climbs out
    while (feet(m) < 56) hold(m, machine.joy.right, 2);
    try std.testing.expect(hear(m, .mummy, 0, 60));

    inRoom(m, 12); // Frankenstein: down the pole to his floor
    while (feet(m) < 89) hold(m, machine.joy.right, 2);
    try std.testing.expect(hear(m, .frankenstein, machine.joy.down, 80));
}

test "a death flashes with a beep that falls each time" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 4); // Lightning: along the floor, into it
    try std.testing.expect(hear(m, .flash, machine.joy.right, 300));
    var last = pitchNow(m);
    var beeps: usize = 1;
    for (0..40) |_| {
        hold(m, 0, 1);
        if (m.ram[map.sound_playing] != @intFromEnum(tunes.Effect.flash) or pitchNow(m) == last) continue;
        try std.testing.expect(pitchNow(m) < last);
        last = pitchNow(m);
        beeps += 1;
    }
    try std.testing.expect(beeps >= 4);
}

test "a fanfare for the escape, a slow fall for GAME OVER, and the waltz again" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 19); // the Way Out
    while (feet(m) > 50) hold(m, machine.joy.left, 2);
    hold(m, machine.joy.fire, 4);
    hold(m, machine.joy.left, 60);
    hold(m, machine.joy.up | machine.joy.right, 4);
    while (m.ram[map.game_mode] != @intFromEnum(Mode.escape)) hold(m, 0, 1);
    try std.testing.expectEqual(tunes.Song.escape, song(m).?);
    sign(m, "WIN");
    while (m.ram[map.game_mode] != @intFromEnum(Mode.over)) hold(m, 0, 1);
    try std.testing.expectEqual(tunes.Song.over, song(m).?);
    while (m.ram[map.game_mode] != @intFromEnum(Mode.title)) hold(m, 0, 1);
    try std.testing.expectEqual(tunes.Song.title, song(m).?);
}

const drive = machine.drive;

test "power on: the disk's castles in directory order, and the first one ready to play" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.boot(@This());
    _ = m.runFrame(@This()); // reads the disk, draws the title
    try std.testing.expectEqual(machine.FrameKind.loading, m.last.kind);
    try std.testing.expectEqual(2, m.ram[map.shell_castles]);
    try std.testing.expectEqualSlices(u8, "TRAININ", m.ram[files.entry(0)..][0..7]);
    try std.testing.expectEqual('G' | 0x80, m.ram[files.entry(0) + 7]);
    try std.testing.expectEqualSlices(u8, "ENTRANCE HAL", m.ram[files.entry(1)..][0..12]);
    try std.testing.expectEqualSlices(u8, training.bytes, m.ram[map.staging.first..][0..training.bytes.len]);
    try std.testing.expectEqual(scores.file_size, m.ram[map.scores.first]); // no score file: a fresh one
    try std.testing.expectEqual(0xFF, m.ram[map.scores.first + 2]);
}

test "no disk in the drive: the title says so, and fire starts nothing" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.boot(@This());
    m.eject();
    _ = m.runFrame(@This());
    try std.testing.expectEqual(@intFromEnum(files.Disk.none), m.ram[map.shell_disk]);
    hold(m, machine.joy.fire, 1);
    hold(m, 0, 5);
    try std.testing.expectEqual(@intFromEnum(Mode.title), m.ram[map.game_mode]);
}

/// Push stick 1 `way`, and let go.
fn push(m: *Machine, way: u8) void {
    hold(m, way, 1);
    hold(m, 0, 1);
}

test "the menu: down to the second castle, fire, and it's the one the title names and the game plays" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.boot(@This());
    _ = m.runFrame(@This());
    typeIn(m, "\x1b"); // Esc
    _ = m.runFrame(@This()); // draws the menu
    try std.testing.expectEqual(@intFromEnum(Mode.menu), m.ram[map.game_mode]);
    for (0..5) |_| push(m, machine.joy.down); // past the four lines and the first castle
    try std.testing.expectEqual(5, m.ram[map.shell_pointer]);
    hold(m, machine.joy.fire, 1); // loads it
    try std.testing.expectEqual(machine.FrameKind.loading, m.last.kind);
    try std.testing.expectEqual(1, m.ram[map.shell_castle]);
    try std.testing.expectEqualSlices(u8, hall.bytes, m.ram[map.staging.first..][0..hall.bytes.len]);
    hold(m, 0, 2); // the title again
    try std.testing.expectEqual(@intFromEnum(Mode.title), m.ram[map.game_mode]);
    hold(m, machine.joy.fire, 1);
    onward(m);
    try std.testing.expectEqual(@intFromEnum(Mode.room), m.ram[map.game_mode]);
    try std.testing.expectEqual(hall.bytes.len, m.peek16(castle.size)); // the Entrance Hall
}

test "unlimited lives: give up as often as you like, and it's never GAME OVER" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.boot(@This());
    _ = m.runFrame(@This());
    typeIn(m, "\x1b");
    _ = m.runFrame(@This());
    push(m, machine.joy.down);
    push(m, machine.joy.down);
    hold(m, machine.joy.fire, 1);
    try std.testing.expectEqual(1, m.ram[map.shell_unlimited]);
    typeIn(m, "\x1b"); // back to the title
    hold(m, 0, 2);
    hold(m, machine.joy.fire, 1);
    for (0..5) |_| {
        onward(m);
        arrived(m);
        typeIn(m, "X");
        while (m.ram[map.game_mode] == @intFromEnum(Mode.room)) hold(m, 0, 1);
        try std.testing.expectEqual(3, m.ram[castle.lives]);
    }
    try std.testing.expectEqual(@intFromEnum(Mode.draw_map), m.ram[map.game_mode]);
}

test "a best time: signed, saved to the disk, and still there after the power's been off" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 19); // the Way Out
    while (feet(m) > 50) hold(m, machine.joy.left, 2);
    hold(m, machine.joy.fire, 4);
    hold(m, machine.joy.left, 60);
    hold(m, machine.joy.up | machine.joy.right, 4);
    sign(m, "ACE");
    try std.testing.expectEqualSlices(u8, "ACE", m.ram[map.scores.first + 2 ..][0..3]);
    while (m.ram[map.game_mode] != @intFromEnum(Mode.title)) hold(m, 0, 1);

    // The score file on the disk: "Y" and the castle's name, 122 bytes.
    var file: [scores.file_size]u8 = undefined;
    var sectors: u32 = 0;
    try std.testing.expectEqual(scores.file_size, try drive.load(m.diskImage().?, "YTRAINING", &file, &sectors));
    try std.testing.expectEqualSlices(u8, "ACE", file[2..5]);

    // Power off and on with the same disk in: the time's still the best.
    const kept = m.diskImage().?.*;
    m.boot(@This());
    try m.insert(&kept);
    _ = m.runFrame(@This());
    try std.testing.expectEqualSlices(u8, "ACE", m.ram[map.scores.first + 2 ..][0..3]);
    typeIn(m, "\x1b");
    _ = m.runFrame(@This());
    push(m, machine.joy.down);
    hold(m, machine.joy.fire, 1); // BEST TIMES
    hold(m, 0, 2);
    try std.testing.expectEqual(@intFromEnum(Mode.times), m.ram[map.game_mode]);
    hold(m, machine.joy.fire, 1); // and back to the menu
    hold(m, 0, 2);
    try std.testing.expectEqual(@intFromEnum(Mode.menu), m.ram[map.game_mode]);
}

test "a key pressed before the best times ask isn't an initial" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    inRoom(m, 19); // the Way Out
    while (feet(m) > 50) hold(m, machine.joy.left, 2);
    hold(m, machine.joy.fire, 4);
    hold(m, machine.joy.left, 60);
    hold(m, machine.joy.up | machine.joy.right, 4);
    while (m.ram[map.game_mode] != @intFromEnum(Mode.escape)) hold(m, 0, 1);
    typeIn(m, "\x1b"); // Esc during the fanfare
    sign(m, "ACE");
    try std.testing.expectEqualSlices(u8, "ACE", m.ram[map.scores.first + 2 ..][0..3]);
}

test "a full disk: the best time says it isn't saved, and fire goes on" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    const full = try std.testing.allocator.create(drive.Image);
    defer std.testing.allocator.destroy(full);
    full.* = master.image;
    var n: u32 = 0;
    const junk = try std.testing.allocator.alloc(u8, @as(usize, drive.blocksFree(full)) * 254 - 2);
    defer std.testing.allocator.free(junk);
    @memset(junk, 1);
    try drive.save(full, "JUNK", 0x1000, junk, &n);
    try std.testing.expectEqual(0, drive.blocksFree(full));
    inRoom(m, 19);
    try m.insert(full);
    while (feet(m) > 50) hold(m, machine.joy.left, 2);
    hold(m, machine.joy.fire, 4);
    hold(m, machine.joy.left, 60);
    hold(m, machine.joy.up | machine.joy.right, 4);
    sign(m, "ACE");
    hold(m, 0, 5);
    try std.testing.expectEqual(@intFromEnum(Mode.times), m.ram[map.game_mode]); // still showing it
    try std.testing.expectEqual(@intFromEnum(drive.Status.full), m.ram[hw.drive_status]);
    push(m, machine.joy.fire);
    hold(m, 0, 2);
    try std.testing.expectEqual(@intFromEnum(Mode.over), m.ram[map.game_mode]);
}

test "saved on the map, resumed from the menu: the same room, lives and time, and no best time" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    m.boot(@This());
    _ = m.runFrame(@This());
    hold(m, machine.joy.fire, 1);
    onward(m); // the Gatehouse
    hold(m, machine.joy.left, 34);
    hold(m, machine.joy.fire, 4);
    hold(m, machine.joy.right, 60);
    hold(m, machine.joy.up | machine.joy.right, 4);
    while (m.ram[map.game_mode] != @intFromEnum(Mode.map)) hold(m, 0, 1);
    const time = clock.of(m, 0).*;

    typeIn(m, "\x1b"); // Esc on the map: save
    _ = m.runFrame(@This());
    typeIn(m, "MY GAMX\x08E\r"); // a slip, Backspace, and Return
    try std.testing.expectEqual(machine.FrameKind.loading, m.last.kind);
    try std.testing.expectEqual(@intFromEnum(Mode.draw_map), m.ram[map.game_mode]);
    var file: [map.castle.last - map.castle.first + 1]u8 = undefined;
    var sectors: u32 = 0;
    const len = try drive.load(m.diskImage().?, "MY GAME", &file, &sectors);
    try std.testing.expectEqual(m.peek16(castle.size), len);
    try std.testing.expectEqual(1, file[castle.room - castle.header]); // the Long Gallery next

    // Give up three lives to GAME OVER and the title.
    for (0..3) |_| {
        onward(m);
        arrived(m);
        typeIn(m, "X");
        while (m.ram[map.game_mode] != @intFromEnum(Mode.map) and m.ram[map.game_mode] != @intFromEnum(Mode.title)) hold(m, 0, 1);
    }
    try std.testing.expectEqual(@intFromEnum(Mode.title), m.ram[map.game_mode]);

    typeIn(m, "\x1b"); // the menu, pointer on RESUME GAME
    _ = m.runFrame(@This());
    hold(m, machine.joy.fire, 1);
    hold(m, 0, 2);
    typeIn(m, "NO SUCH GAME\r");
    try std.testing.expectEqual(@intFromEnum(Mode.name), m.ram[map.game_mode]); // not on the disk: try again
    for (0..12) |_| typeIn(m, "\x08");
    typeIn(m, "MY GAME\r");
    try std.testing.expectEqual(@intFromEnum(Mode.draw_map), m.ram[map.game_mode]);
    try std.testing.expectEqual(1, m.ram[castle.room]);
    try std.testing.expectEqual(3, m.ram[castle.lives]);
    try std.testing.expectEqual(time, clock.of(m, 0).*);
    try std.testing.expect(m.ram[castle.magic] & castle.restored != 0);
    try std.testing.expect(!scores.earned(m, 0)); // a resumed game is off the best times
    onward(m);
    try std.testing.expectEqual(1, m.ram[map.room_number]);
}

test "a disk of your own: the castle list in its order, up to 16" {
    const m = try std.testing.allocator.create(Machine);
    defer std.testing.allocator.destroy(m);
    const disk_image = try std.testing.allocator.create(drive.Image);
    defer std.testing.allocator.destroy(disk_image);
    drive.format(disk_image, "MY CASTLES", "MC".*);
    var n: u32 = 0;
    try drive.save(disk_image, "ZSECOND", map.staging.first, hall.bytes, &n);
    try drive.save(disk_image, "NOTES", 0x1000, "NOT A CASTLE", &n);
    try drive.save(disk_image, "ZFIRST", map.staging.first, training.bytes, &n);
    var name = "ZMORE00".*;
    for (0..20) |i| {
        name[5] = '0' + @as(u8, @intCast(i / 10));
        name[6] = '0' + @as(u8, @intCast(i % 10));
        try drive.save(disk_image, &name, map.staging.first, hall.bytes, &n);
    }
    m.boot(@This());
    try m.insert(disk_image);
    _ = m.runFrame(@This());
    try std.testing.expectEqual(16, m.ram[map.shell_castles]);
    try std.testing.expectEqualSlices(u8, "SECON", m.ram[files.entry(0)..][0..5]); // first on the disk
    try std.testing.expectEqualSlices(u8, "FIRS", m.ram[files.entry(1)..][0..4]);
    try std.testing.expectEqualSlices(u8, hall.bytes, m.ram[map.staging.first..][0..hall.bytes.len]);
}
