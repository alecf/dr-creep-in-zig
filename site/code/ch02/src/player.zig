//! Player 1: a multicolour sprite who walks the floor with joystick 1.

const machine = @import("machine");
const Machine = machine.Machine;
const Color = machine.Color;
const hw = machine.hw;
const joy = machine.joy;
const video = machine.video;
const map = @import("map.zig");
const room = @import("room.zig");
const shapes = @import("shapes.zig");
const sprites = @import("sprites.zig");

/// The player is sprite 0. It shows block 0 or block 8, whichever one
/// isn't being rewritten.
const sprite = 0;

/// How far the sprite may go. X stops at 255 because that's the most a
/// byte can hold; the right-hand strip of the screen needs a ninth bit.
const min_x = video.sprite_origin_x;
const max_x = 255;
const floor_y = video.sprite_origin_y + room.floor_top - 21; // boots on the floor

/// The first frame of each walk: four frames facing right, then four left.
const right_0 = @intFromEnum(shapes.Id.explorer_right_0);
const left_0 = @intFromEnum(shapes.Id.explorer_left_0);

/// Once, at power-on.
pub fn start(m: *Machine) void {
    m.poke(hw.sprite_multicolor, 0b0000_0001); // sprite 0 is multicolour
    m.poke(hw.sprite_mc0, @intFromEnum(Color.pink)); // code 01: skin
    m.poke(hw.sprite_mc1, @intFromEnum(Color.orange)); // code 11: hat, belt, boots
    m.poke(map.player_last_stick, 0xFF); // nothing held
    m.poke(map.player_block, 8); // so the first frame goes into block 0
}

/// Into the room: on the floor, facing right, visible.
pub fn enter(m: *Machine) void {
    m.poke(map.player_x, 160);
    m.poke(map.player_y, floor_y);
    setFrame(m, .explorer_right_0);
    m.poke(hw.sprite_enable, 0b0000_0001); // bit 0 on: sprite 0 is shown
}

/// Copy the player's position, colour and frame into the VIDEO chip.
pub fn show(m: *Machine) void {
    m.poke(hw.spriteX(sprite), m.peek(map.player_x));
    m.poke(hw.spriteY(sprite), m.peek(map.player_y));
    m.poke(hw.spriteColor(sprite), m.peek(map.player_color));
    m.poke(hw.sprite_pointers + sprite, m.peek(map.player_block));
}

/// Walk left or right along the floor, a pixel a frame, stepping through
/// the walk cycle as he goes.
pub fn steer(m: *Machine) void {
    const stick = m.peek(hw.joy1);
    var x = m.peek(map.player_x);
    const now = m.peek(map.player_frame);
    var first: u8 = if (now >= left_0) left_0 else right_0;
    var walking = false;

    if (held(stick, joy.left) and x > min_x) {
        x -= 1;
        first = left_0;
        walking = true;
    } else if (held(stick, joy.right) and x < max_x) {
        x += 1;
        first = right_0;
        walking = true;
    }

    // Bits 2 and 3 of x count 0, 1, 2, 3 as he walks, a new frame every
    // four pixels. Standing still, he stands on frame 0.
    const step = if (walking) (x >> 2) & 0b11 else 0;
    const next = first + step;
    if (next != now) setFrame(m, @enumFromInt(next));

    m.poke(map.player_x, x);
    m.work(40); // the tests, sums and branches above
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

/// Was fire pressed this frame? (Held now, and not last frame.)
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
