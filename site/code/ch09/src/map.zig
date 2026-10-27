//! The game's memory map: every stretch of memory the game uses, and
//! what it's for. Nothing the game remembers lives anywhere else.

const hw = @import("machine").hw;

pub const Region = struct {
    name: []const u8,
    first: u16,
    last: u16,
};

// ---- the game's own memory ----------------------------------------------

/// The screens between rooms: the castle map, the escape and GAME OVER.
/// Only one of them is ever on, so they take turns with the same seven
/// bytes (game.zig).
pub const between = Region{ .name = "between rooms", .first = 0x0200, .last = 0x0206 };

/// Which screen the game is on, and a clock.
pub const game = Region{ .name = "game", .first = 0x0207, .last = 0x0208 };
pub const game_mode = game.first + 0; // a main.Mode
pub const game_tick = game.first + 1; // goes up by one every frame, and wraps

/// The room on screen.
pub const room = Region{ .name = "room", .first = 0x0209, .last = 0x0209 };
pub const room_number = room.first + 0; // its place in the castle's room directory

/// Three switches for looking inside the game (debug.zig): 0 off, 1 on.
pub const debug = Region{ .name = "debug", .first = 0x020A, .last = 0x020C };
pub const debug_grid = debug.first + 0; // G: draw the navigation grid over the room
pub const debug_search = debug.first + 1; // Q: search the castle instead of reading the grid
pub const debug_scan = debug.first + 2; // C: check every object for every actor, every turn

/// The room at work: how many objects it has, and how it ends.
pub const engine = Region{ .name = "engine", .first = 0x020D, .last = 0x020E };
pub const engine_objects = engine.first + 0; // object slots in use (objects.zig)
pub const engine_ending = engine.first + 1; // steps until the room is over, or 0 while it isn't ending

/// The dice: two bytes, and each roll makes the next pair from the last
/// (dice.zig).
pub const dice = Region{ .name = "dice", .first = 0x020F, .last = 0x0210 };
pub const dice_low = dice.first + 0;
pub const dice_high = dice.first + 1;

/// What the game knows about each explorer from one of his turns to the
/// next: five bytes for player 1, then five for player 2 (player.zig).
pub const players = Region{ .name = "players", .first = 0x0211, .last = 0x021A };

/// Text: a lookup table, the shape each letter is built in, and a string.
pub const text = Region{ .name = "text", .first = 0x0300, .last = 0x037F };
pub const text_widen = text.first + 0x00; // 16 bytes: 4 glyph bits -> 4 fat pixels
pub const text_glyph = text.first + 0x10; // one letter, up to 2x24: 63 bytes
pub const text_buffer = text.first + 0x50; // a string to print
pub const text_buffer_size = text.last - text_buffer + 1; // 48 letters

/// Built-in tables, copied to the top of the program image at boot.
pub const stars = Region{ .name = "star map", .first = 0x5F00, .last = 0x5FFF };
pub const shape_table = Region{ .name = "shape table", .first = 0x6000, .last = hw.program_end - 1 };

/// The castle: its header, its room directory and every room's objects,
/// exactly as the castle file holds them. A game plays on this copy.
pub const castle = Region{ .name = "castle", .first = 0x7800, .last = 0x97FF };

/// The castle as it came, untouched: each new game starts from a copy.
pub const staging = Region{ .name = "staging", .first = 0x9800, .last = 0xB7FF };

/// Where each of the 200 bitmap rows starts: two bytes per row.
pub const row_table = Region{ .name = "row table", .first = 0xBB00, .last = 0xBB00 + 200 * 2 - 1 };

/// The actor table: a 16-byte slot for each of the VIDEO chip's eight
/// sprites (actors.zig).
pub const actors = Region{ .name = "actors", .first = 0xBD00, .last = 0xBD00 + 8 * 16 - 1 };

/// The room's object table: 32 slots of 16 bytes (objects.zig).
pub const objects = Region{ .name = "objects", .first = 0xBE00, .last = 0xBE00 + 32 * 16 - 1 };

/// The navigation grid: one byte for each of the screen's 40 x 25 cells,
/// saying which ways the explorer can go from there (grid.zig).
pub const grid = Region{ .name = "navigation grid", .first = 0xC800, .last = 0xC800 + 40 * 25 - 1 };

// ---- memory the hardware gives us ---------------------------------------

const stack = Region{ .name = "stack (reserved)", .first = hw.stack, .last = hw.stack + 256 - 1 };
const program = Region{ .name = "program image", .first = hw.program, .last = stars.first - 1 };
const sprite_frames = Region{ .name = "sprite frames", .first = hw.sprite_data, .last = hw.sprite_data + 32 * 64 - 1 };
const screen_plane = Region{ .name = "screen plane", .first = hw.screen, .last = hw.screen + 1000 - 1 };
const sprite_pointers = Region{ .name = "sprite pointers", .first = hw.sprite_pointers, .last = hw.sprite_pointers + 8 - 1 };
const video_chip = Region{ .name = "VIDEO chip", .first = hw.video_chip, .last = hw.spriteColor(7) };
const color_ram = Region{ .name = "colour RAM", .first = hw.color_ram, .last = hw.color_ram + 1000 - 1 };
const input_ports = Region{ .name = "input ports", .first = hw.joy2, .last = hw.key };
const bitmap = Region{ .name = "bitmap", .first = hw.bitmap, .last = hw.bitmap + 8000 - 1 };

/// The whole map, in address order.
pub const regions = [_]Region{
    stack,
    between,
    game,
    room,
    debug,
    engine,
    dice,
    players,
    text,
    program,
    stars,
    shape_table,
    castle,
    staging,
    row_table,
    actors,
    objects,
    sprite_frames,
    grid,
    screen_plane,
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
