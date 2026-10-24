//! Player 1: a multicolour sprite who walks the castle's floors, climbs its
//! ladders and slides down its poles, steered by joystick 1.

const machine = @import("machine");
const Machine = machine.Machine;
const Color = machine.Color;
const hw = machine.hw;
const joy = machine.joy;
const map = @import("map.zig");
const castle = @import("castle.zig");
const grid = @import("grid.zig");
const room = @import("room.zig");
const shapes = @import("shapes.zig");
const sprites = @import("sprites.zig");

/// Which of the VIDEO chip's eight sprite slots (0-7) is the player's.
/// He shows block 0 or block 8, whichever one isn't being rewritten.
const player_sprite = 0;

/// His feet: the point the grid is read at, 3 fat pixels in from his left
/// edge and 21 rows down from his top, the row his boots stand on.
const feet_x = 3;
const feet_y = 21;

/// Where he appears in a doorway: in the middle, boots on the sill.
const door_x = 6;
const door_y = 11;

/// The first frame of each walk: four frames facing right, then four left.
const right_0 = @intFromEnum(shapes.Id.explorer_right_0);
const left_0 = @intFromEnum(shapes.Id.explorer_left_0);
const climb_0 = @intFromEnum(shapes.Id.explorer_climb_0);
comptime {
    if (left_0 != right_0 + 4 or @intFromEnum(shapes.Id.explorer_left_3) != left_0 + 3)
        @compileError("the explorer's eight frames must be in a row in shapes.Id");
    if (@intFromEnum(shapes.Id.explorer_climb_3) != climb_0 + 3)
        @compileError("the explorer's four climbing frames must be in a row in shapes.Id");
}

/// Directions run clockwise from 0, up, to 7, up and left: the grid's bit
/// numbers. `still` is no direction at all.
const still: u8 = 0x80;

/// The eight directions, laid out the way they are on the stick.
const compass = [3][3]u8{
    .{ 7, 0, 1 }, // up and left, up, up and right
    .{ 6, still, 2 }, // left, nothing, right
    .{ 5, 4, 3 }, // down and left, down, down and right
};

/// The direction for each of the 16 ways the stick's four direction
/// switches (the low four bits of its port) can read. Worked out by the
/// compiler with `held`; up and down together, or left and right, is still.
const stick_way: [16]u8 = blk: {
    var table: [16]u8 = undefined;
    for (&table, 0..) |*way, n| {
        const u = held(n, joy.up);
        const d = held(n, joy.down);
        const l = held(n, joy.left);
        const r = held(n, joy.right);
        const row: usize = if (u) 0 else if (d) 2 else 1;
        const col: usize = if (l) 0 else if (r) 2 else 1;
        way.* = if ((u and d) or (l and r)) still else compass[row][col];
    }
    break :blk table;
};

/// One step in each direction: fat pixels across, rows down. Added with
/// a wrapping +%, so 0xFF goes back 1 and 0xFE goes back 2.
const step_x = [8]u8{ 0, 1, 1, 1, 0, 0xFF, 0xFF, 0xFF };
const step_y = [8]u8{ 0xFE, 0xFE, 0, 2, 2, 2, 0, 0xFE };

/// Once, at power-on.
pub fn start(m: *Machine) void {
    m.poke(hw.sprite_multicolor, 0b0000_0001); // sprite 0 is multicolour
    m.poke(hw.sprite_mc0, @intFromEnum(Color.pink)); // code 01: skin
    m.poke(hw.sprite_mc1, @intFromEnum(Color.orange)); // code 11: hat, belt, boots
    m.poke(map.player_last_stick, 0xFF); // nothing held
    m.poke(map.player_block, 8); // so the first frame goes into block 0
}

/// Into the room, in its first doorway, facing into the room. A room with
/// no doors (the final room) puts him in the middle of the floor.
pub fn enter(m: *Machine) void {
    var x: u8 = castle.left_edge + 80;
    var y: u8 = room.floor_top - feet_y;
    if (room.firstDoor(m)) |at| {
        const door = m.view(castle.Door, at);
        x = door.x + door_x;
        y = door.y + door_y;
    }
    m.poke(map.player_x, x);
    m.poke(map.player_y, y);
    m.poke(map.player_way, still);
    setFrame(m, if (x < castle.left_edge + 80) .explorer_right_0 else .explorer_left_0);
    m.poke(hw.sprite_enable, 0b0000_0001); // bit 0 on: sprite 0 is shown
}

/// Copy the player's position, colour and frame into the VIDEO chip.
pub fn show(m: *Machine) void {
    sprites.place(m, player_sprite, m.peek(map.player_x), m.peek(map.player_y));
    m.poke(hw.spriteColor(player_sprite), m.peek(map.player_color));
    m.poke(hw.sprite_pointers + player_sprite, m.peek(map.player_block));
}

/// One step every other frame: read the grid under his feet, pick a way
/// to go, take the step and pick his picture.
pub fn steer(m: *Machine) void {
    if (m.peek(map.game_tick) & 1 != 0) return; // the castle's pace: 25 steps a second
    var x = m.peek(map.player_x);
    var y = m.peek(map.player_y);
    const fx = x + feet_x;
    const fy = y + feet_y;
    const ways = waysAt(m, fx, fy);

    // The stick's direction if that way is open. If it isn't, but it's
    // next to the way he was already going (a diagonal, say), keep going.
    const want = stick_way[m.peek(hw.joy1) & 0x0F];
    const last = m.peek(map.player_way);
    var way = still;
    if (want != still) {
        if (ways & bit(want) != 0) {
            way = want;
        } else if (last != still and ways & bit(last) != 0 and
            (want == (last +% 1) & 7 or want == (last -% 1) & 7))
        {
            way = last;
        }
    }
    m.poke(map.player_way, way);

    if (way != still) {
        if (way & 3 == 2) y -= fy % 8; // off sideways: up onto the walkway's row
        if (way & 3 == 0) x = x - fx % 4 + 1; // up or down: feet in line with the rungs
        x +%= step_x[way];
        y +%= step_y[way];
        m.poke(map.player_x, x);
        m.poke(map.player_y, y);
    }
    m.work(60); // the sums, tests and table reads above

    // His picture. Walking: Chapter 2's walk, a frame every 2 fat pixels.
    // Up or down: a ladder has rungs that lead up from here or from just
    // below; a pole has none.
    const now = m.peek(map.player_frame);
    var next = now;
    if (way == 2 or way == 6) {
        next = (if (way == 2) right_0 else left_0) + ((x >> 1) & 0b11);
    } else if (way == 0 or way == 4) {
        const rungs = (ways | waysAt(m, fx, fy +| 8)) & grid.up != 0;
        next = if (rungs) climb_0 + ((y >> 2) & 0b11) else @intFromEnum(shapes.Id.explorer_slide);
    } else if (now >= right_0 and now < left_0 + 4) {
        next = if (now >= left_0) left_0 else right_0; // stopped walking: stand
    } // stopped on a ladder or a pole: hold on
    if (next != now) setFrame(m, @enumFromInt(next));
}

/// The grid bit for direction `way` (0-7).
fn bit(way: u8) u8 {
    return @as(u8, 1) << @intCast(way);
}

/// The ways out of the cell under castle point (x, y): one byte from the
/// grid, or, with the Q switch on, the slow way, from the castle itself.
fn waysAt(m: *Machine, x: u8, y: u8) u8 {
    if (m.peek(map.debug_search) != 0)
        return grid.search(m, room.objects(m, m.peek(map.room_number)), x, y);
    return grid.at(m, x, y);
}

/// Show frame `id` from the next frame on. It's unpacked into the block
/// the VIDEO chip *isn't* showing, so the beam never sees it half done;
/// `show` points the chip at it at the top of the next frame.
fn setFrame(m: *Machine, id: shapes.Id) void {
    const hidden = m.peek(map.player_block) ^ 8; // 0 <-> 8
    const flags = sprites.unpack(m, id, hidden);
    m.poke(map.player_color, flags & sprites.flag_color);
    m.poke(map.player_block, hidden);
    m.poke(map.player_frame, @intFromEnum(id));
}

/// Was fire pressed this frame? (Held now, and not last frame.) It also
/// remembers this frame's stick for next time, so call it once a frame.
pub fn pressedFire(m: *Machine) bool {
    const stick = m.peek(hw.joy1);
    const before = m.peek(map.player_last_stick);
    m.poke(map.player_last_stick, stick);
    m.work(10);
    return held(stick, joy.fire) and !held(before, joy.fire);
}

/// Is this switch held? Joystick switches read 0 while they're pressed.
fn held(stick: u8, switch_bit: u8) bool {
    return stick & switch_bit == 0;
}
