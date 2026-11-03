//! The game's side of the disk drive: names, loads and saves, the list
//! of castles from the disk's directory, and a castle with its best times.

const machine = @import("machine");
const Machine = machine.Machine;
const hw = machine.hw;
const drive = machine.drive;
const map = @import("map.zig");
const castle = @import("castle.zig");
const scores = @import("scores.zig");

pub const Status = drive.Status;

/// Load at most `room` bytes of the named file to `at`.
pub fn load(m: *Machine, at: u16, room: u16) Status {
    return command(m, .load, at, room);
}

/// Save `len` bytes from `at` as the named file.
pub fn save(m: *Machine, at: u16, len: u16) Status {
    return command(m, .save, at, len);
}

/// Fill in the drive's registers and write the command. The drive has
/// done it by the time `poke` returns, and charged a frame a sector.
fn command(m: *Machine, c: drive.Command, at: u16, len: u16) Status {
    m.poke16(hw.drive_address, at);
    m.poke16(hw.drive_length, len);
    m.poke(hw.drive_command, @intFromEnum(c));
    return @enumFromInt(m.peek(hw.drive_status));
}

/// Name the next file: `words` from the program, as they are.
pub fn name(m: *Machine, comptime words: []const u8) void {
    m.load(hw.drive_name, words);
    m.poke(hw.drive_name_length, words.len);
}

/// Name the next file: `prefix`, then the stored name at `at`, up to
/// the letter with bit 7 set (which loses its bit 7).
pub fn nameFrom(m: *Machine, comptime prefix: []const u8, at: u16) void {
    m.load(hw.drive_name, prefix);
    var n: u8 = prefix.len;
    var from = at;
    while (n < hw.drive_name_max) {
        const letter = m.peek(from);
        m.poke(hw.drive_name + n, letter & 0x7F);
        n += 1;
        from += 1;
        if (letter & 0x80 != 0) break;
    }
    m.poke(hw.drive_name_length, n);
}

// ---- the castle list --------------------------------------------------------

pub const max_castles = 16;
const name_size = 16;

/// Where castle `n`'s name is kept.
pub fn entry(n: u8) u16 {
    return map.catalog.first + @as(u16, n) * name_size;
}

/// Letters in the stored name at `at`, up to the one with bit 7 set.
pub fn length(m: *Machine, at: u16) u8 {
    var n: u8 = 1;
    while (m.peek(at + n - 1) & 0x80 == 0) n += 1;
    return n;
}

/// What's in staging: nothing yet (power-on), a castle, or nothing to be
/// had (no disk, or no castle on it).
pub const Disk = enum(u8) { unread, ready, none };

/// Power-on: the castle list, then the first castle.
pub fn powerOn(m: *Machine) void {
    catalog(m);
    _ = pick(m, 0);
}

/// The castle list. The drive sends the directory as a little program
/// listing, a line for each file that matches "Z*": its length in blocks,
/// then its name in quotes. It lands in staging, which is free until the
/// castle loads over it, and every name between quotes after the first
/// line (that one is the disk's own name) goes in the list, less its Z.
pub fn catalog(m: *Machine) void {
    m.poke(map.shell_castles, 0);
    name(m, "$0:Z*");
    if (load(m, map.staging.first, map.staging.last - map.staging.first + 1) != .ok) return;
    var line = next(m, map.staging.first); // past the disk's name
    while (m.peek16(line) != 0) : (line = next(m, line)) {
        const count = m.peek(map.shell_castles);
        if (count == max_castles) return;
        var at = line + 4; // past the link and the line number
        while (m.peek(at) != '"' and m.peek(at) != 0) at += 1;
        if (m.peek(at) == 0 or m.peek(at + 1) != 'Z') continue; // BLOCKS FREE.
        at += 2;
        var len: u16 = 0;
        while (m.peek(at + len) != '"' and len < name_size - 1) len += 1;
        if (len == 0) continue;
        m.copy(entry(count), at, len);
        m.poke(entry(count) + len - 1, m.peek(entry(count) + len - 1) | 0x80);
        m.poke(map.shell_castles, count + 1);
    }
}

/// The line after the one at `line`: past its zero byte.
fn next(m: *Machine, line: u16) u16 {
    var at = line + 4;
    while (m.peek(at) != 0) at += 1;
    return at + 1;
}

/// Castle `n` from the disk into staging, over whatever was there, and
/// its best times (the file "Y" and its name) next to it. No score file
/// yet: a fresh table. True if a castle came.
pub fn pick(m: *Machine, n: u8) bool {
    m.poke(map.shell_castle, n);
    m.poke(map.shell_disk, @intFromEnum(Disk.none));
    if (n >= m.peek(map.shell_castles)) return false;
    nameFrom(m, "Z", entry(n));
    if (load(m, map.staging.first, map.staging.last - map.staging.first + 1) != .ok) return false;
    if (m.peek(map.staging.first + 2) & ~castle.restored != castle.magic_value) return false;
    nameFrom(m, "Y", entry(n));
    if (load(m, map.scores.first, scores.file_size) != .ok or m.peek16(map.scores.first) != scores.file_size)
        scores.fresh(m);
    m.poke(map.shell_disk, @intFromEnum(Disk.ready));
    return true;
}

/// Is there a castle to play?
pub fn ready(m: *Machine) bool {
    return m.peek(map.shell_disk) == @intFromEnum(Disk.ready);
}

/// Save the best times over the castle's score file, or as a new one.
pub fn saveScores(m: *Machine) Status {
    nameFrom(m, "@0:Y", entry(m.peek(map.shell_castle)));
    return save(m, map.scores.first, scores.file_size);
}
