//! Player 1: a hires sprite you steer with joystick 1.

const machine = @import("machine");
const Machine = machine.Machine;
const Color = machine.Color;
const hw = machine.hw;
const joy = machine.joy;
const video = machine.video;
const map = @import("map.zig");
const room = @import("room.zig");

/// The player's picture: 21 rows of 24 pixels, three bytes a row, one bit
/// per pixel. A 1 is a pixel in the sprite's colour; a 0 is see-through.
const picture = [63]u8{
    0b00000000, 0b00000000, 0b00000000,
    0b00000000, 0b00111100, 0b00000000,
    0b00000000, 0b01111110, 0b00000000,
    0b00000001, 0b11111111, 0b10000000,
    0b00000000, 0b01111110, 0b00000000,
    0b00000000, 0b01011010, 0b00000000,
    0b00000000, 0b01111110, 0b00000000,
    0b00000000, 0b00111100, 0b00000000,
    0b00000000, 0b00011000, 0b00000000,
    0b00000001, 0b11111111, 0b10000000,
    0b00000011, 0b01111110, 0b11000000,
    0b00000011, 0b01111110, 0b11000000,
    0b00000011, 0b01111110, 0b11000000,
    0b00000000, 0b01111110, 0b00000000,
    0b00000000, 0b01111110, 0b00000000,
    0b00000000, 0b01100110, 0b00000000,
    0b00000000, 0b01100110, 0b00000000,
    0b00000000, 0b01100110, 0b00000000,
    0b00000000, 0b01100110, 0b00000000,
    0b00000000, 0b01100110, 0b00000000,
    0b00000000, 0b11100111, 0b00000000,
};

/// Which of the VIDEO chip's eight sprite slots (0-7) is the player's.
const player_sprite = 0;

/// Which sprite block (0-31) holds his picture. Block 0 is the 64 bytes
/// at $C000.
const player_block = 0;

/// How far the sprite may go. X stops at 255 because that's the most a
/// byte can hold; the right-hand strip of the screen needs a ninth bit.
const min_x = video.sprite_origin_x;
const max_x = 255;
const min_y = video.sprite_origin_y;
const max_y = video.sprite_origin_y + room.floor_top - 21; // boots on the floor

pub fn start(m: *Machine) void {
    m.load(hw.sprite_data + player_block * 64, &picture);
    m.poke(hw.sprite_pointers + player_sprite, player_block);
    m.poke(hw.sprite_enable, 0b0000_0001); // bit 0 on: sprite 0 is shown

    m.poke(map.player_x, 160);
    m.poke(map.player_y, max_y);
    m.poke(map.player_color, @intFromEnum(Color.white));
    m.poke(map.player_last_stick, 0xFF); // nothing held
}

/// Copy the player's position and colour into the VIDEO chip.
pub fn show(m: *Machine) void {
    m.poke(hw.spriteX(player_sprite), m.peek(map.player_x));
    m.poke(hw.spriteY(player_sprite), m.peek(map.player_y));
    m.poke(hw.spriteColor(player_sprite), m.peek(map.player_color));
}

/// Read joystick 1 and move the player one pixel in each direction held.
/// A fresh press of fire picks the next colour.
pub fn steer(m: *Machine) void {
    const stick = m.peek(hw.joy1);
    const before = m.peek(map.player_last_stick);
    var x = m.peek(map.player_x);
    var y = m.peek(map.player_y);

    if (held(stick, joy.left) and x > min_x) x -= 1;
    if (held(stick, joy.right) and x < max_x) x += 1;
    if (held(stick, joy.up) and y > min_y) y -= 1;
    if (held(stick, joy.down) and y < max_y) y += 1;

    // Held now but not last frame: that's a press. Without this check,
    // holding fire would change colour fifty times a second.
    if (held(stick, joy.fire) and !held(before, joy.fire)) {
        const c = m.peek(map.player_color);
        m.poke(map.player_color, if (c == 15) 1 else c + 1); // 0 is black, like the background
    }

    m.poke(map.player_x, x);
    m.poke(map.player_y, y);
    m.poke(map.player_last_stick, stick);
    m.work(40); // the tests, sums and branches above
}

/// Is this switch held? Joystick switches read 0 while they're pressed.
fn held(stick: u8, switch_bit: u8) bool {
    return stick & switch_bit == 0;
}
