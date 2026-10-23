//! The game's memory map: every stretch of memory the game uses, and
//! what it's for. Nothing the game remembers lives anywhere else.

const hw = @import("machine").hw;

pub const Region = struct {
    name: []const u8,
    first: u16,
    last: u16,
};

// ---- the game's own memory ----------------------------------------------

/// Everything the game knows about the player, four bytes in a row.
pub const player = Region{ .name = "player", .first = 0x0200, .last = 0x0203 };
pub const player_x = player.first + 0; // sprite X, 24 (left edge) to 255
pub const player_y = player.first + 1; // sprite Y, 50 (top edge) and down
pub const player_color = player.first + 2; // palette number, 1-15
pub const last_stick = player.first + 3; // joystick 1 as it read last frame

// ---- memory the hardware gives us ---------------------------------------

const stack = Region{ .name = "stack (reserved)", .first = hw.stack, .last = 0x01FF };
const program = Region{ .name = "program image", .first = hw.program, .last = hw.program_end - 1 };
const sprite_frames = Region{ .name = "sprite frames", .first = hw.sprite_data, .last = 0xC7FF };
const sprite_pointers = Region{ .name = "sprite pointers", .first = hw.sprite_pointers, .last = 0xCFFF };
const video_chip = Region{ .name = "VIDEO chip", .first = hw.video_chip, .last = 0xD02E };
const color_ram = Region{ .name = "colour RAM", .first = hw.color_ram, .last = 0xDBE7 };
const input_ports = Region{ .name = "input ports", .first = hw.joy2, .last = hw.key };
const bitmap = Region{ .name = "bitmap", .first = hw.bitmap, .last = 0xFF3F };

/// The whole map, in address order.
pub const regions = [_]Region{
    stack,
    player,
    program,
    sprite_frames,
    sprite_pointers,
    video_chip,
    color_ram,
    input_ports,
    bitmap,
};

// Checked while the game compiles: two regions sharing a byte is a build
// error, not a mystery bug three chapters from now.
comptime {
    for (regions, 0..) |a, i| {
        if (a.last < a.first) @compileError("memory map: " ++ a.name ++ " ends before it starts");
        for (regions[i + 1 ..]) |b| {
            if (a.first <= b.last and b.first <= a.last)
                @compileError("memory map: " ++ a.name ++ " overlaps " ++ b.name);
        }
    }
}
