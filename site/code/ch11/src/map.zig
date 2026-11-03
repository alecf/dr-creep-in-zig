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

/// The sound driver: where it's got to in the music or the sound effect
/// it's playing, and its timing (sound.zig).
pub const sound = Region{ .name = "sound", .first = 0x021B, .last = 0x0225 };
pub const sound_at = sound.first + 0; // two bytes: the next command, or 0 for silence
pub const sound_loop = sound.first + 2; // two bytes: where the tune starts again at its end, or 0
pub const sound_wait = sound.first + 4; // ticks to go before the next command
pub const sound_tempo = sound.first + 5; // added to the beat every frame
pub const sound_beat = sound.first + 6; // a tick each time this goes past 255
pub const sound_playing = sound.first + 7; // what's playing: an effect, a tune, or nothing
pub const sound_transpose = sound.first + 8; // three bytes: added to each voice's notes

/// Text: a lookup table, the shape each letter is built in, and a string.
pub const text = Region{ .name = "text", .first = 0x0300, .last = 0x037F };
pub const text_widen = text.first + 0x00; // 16 bytes: 4 glyph bits -> 4 fat pixels
pub const text_glyph = text.first + 0x10; // one letter, up to 2x24: 63 bytes
pub const text_buffer = text.first + 0x50; // a string to print
pub const text_buffer_size = text.last - text_buffer + 1; // 48 letters

/// The sound effects, copied here at boot so the game can change a note
/// in one before it plays it (tunes.zig).
pub const effects = Region{ .name = "sound effects", .first = 0x0380, .last = 0x04FF };

/// Built-in tables, copied to the top of the program image at boot.
pub const music = Region{ .name = "music", .first = 0x5A00, .last = 0x5EFF }; // notes and tunes (tunes.zig)
pub const stars = Region{ .name = "star map", .first = 0x5F00, .last = 0x5FFF };
pub const shape_table = Region{ .name = "shape table", .first = 0x6000, .last = hw.program_end - 1 };

/// The castle: its header, its room directory and every room's objects,
/// exactly as the castle file holds them. A game plays on this copy.
pub const castle = Region{ .name = "castle", .first = 0x7800, .last = 0x97FF };

/// The castle as it came off the disk, untouched: each new game starts
/// from a copy. At power-on the disk's directory lands here first.
pub const staging = Region{ .name = "staging", .first = 0x9800, .last = 0xB7FF };

/// The castle's best times, exactly as its score file holds them
/// (scores.zig).
pub const scores = Region{ .name = "best times", .first = 0xB800, .last = 0xB879 };

/// The shell: the disk, the menu, and the line being typed.
pub const shell = Region{ .name = "shell", .first = 0xB880, .last = 0xB89F };
pub const shell_disk = shell.first + 0; // a files.Disk: unread, ready, or no castle
pub const shell_castles = shell.first + 1; // how many castles the disk has (up to 16)
pub const shell_castle = shell.first + 2; // which of them is in staging
pub const shell_pointer = shell.first + 3; // the menu line the pointer is on
pub const shell_stick = shell.first + 4; // stick 1 as the menu last saw it
pub const shell_unlimited = shell.first + 5; // 1: lives never run out, and no best times
pub const shell_signing = shell.first + 6; // the player typing his initials, or 0xFF
pub const shell_place = shell.first + 7; // the best time he's signing
pub const shell_saving = shell.first + 8; // 1: typing a name to save under; 0: to resume
pub const shell_x = shell.first + 9; // where the line being typed starts
pub const shell_y = shell.first + 10;
pub const shell_max = shell.first + 11; // the most letters it takes
pub const shell_typed = shell.first + 12; // letters typed so far
pub const shell_line = shell.first + 16; // 16 bytes: the letters, bit 7 on the last

/// The castles on the disk, in directory order: 16 bytes a name, bit 7
/// on its last letter (files.zig).
pub const catalog = Region{ .name = "castle list", .first = 0xB900, .last = 0xB9FF };

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
const program = Region{ .name = "program image", .first = hw.program, .last = music.first - 1 };
const sprite_frames = Region{ .name = "sprite frames", .first = hw.sprite_data, .last = hw.sprite_data + 32 * 64 - 1 };
const screen_plane = Region{ .name = "screen plane", .first = hw.screen, .last = hw.screen + 1000 - 1 };
const sprite_pointers = Region{ .name = "sprite pointers", .first = hw.sprite_pointers, .last = hw.sprite_pointers + 8 - 1 };
const video_chip = Region{ .name = "VIDEO chip", .first = hw.video_chip, .last = hw.spriteColor(7) };
const sound_chip = Region{ .name = "SOUND chip", .first = hw.sound_chip, .last = hw.sound_volume };
const color_ram = Region{ .name = "colour RAM", .first = hw.color_ram, .last = hw.color_ram + 1000 - 1 };
const input_ports = Region{ .name = "input ports", .first = hw.joy2, .last = hw.key };
const disk_drive = Region{ .name = "disk drive", .first = hw.drive_command, .last = hw.drive_name + hw.drive_name_max - 1 };
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
    sound,
    text,
    effects,
    program,
    music,
    stars,
    shape_table,
    castle,
    staging,
    scores,
    shell,
    catalog,
    row_table,
    actors,
    objects,
    sprite_frames,
    grid,
    screen_plane,
    sprite_pointers,
    video_chip,
    sound_chip,
    color_ram,
    input_ports,
    disk_drive,
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
