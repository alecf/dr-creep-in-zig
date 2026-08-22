//! KERNAL disk-API implementation, installed as lift-table hooks.
//!
//! The game banks out the KERNAL ROM for gameplay, but during startup and
//! between castles it banks it back in and uses the standard entry points.
//! We provide no ROM; these hooks serve files from an in-memory filesystem —
//! which is exactly what the wasm build needs anyway.
//!
//! What the game actually uses (from disasm/object.s):
//!  - SETLFS/SETNAM/LOAD    whole-file loads ("object", castle files, "$0:z*")
//!  - SETLFS/SETNAM/SAVE    per-castle progress files ("y<castle>")
//!  - OPEN/CHKIN/CHRIN      byte-wise reads of "$" to scan the directory
//!  - OPEN/CHKOUT/CHROUT    drive command channel (block reads for the
//!                          copy-protection check at $2C31 — neutered in this
//!                          cracked image, but the channel dance still runs)
//!  - READST                EOF/error status after channel ops
//!  - assorted init entries (IOINIT etc.) — safe no-ops

const std = @import("std");
const machine_mod = @import("machine.zig");
const Machine = machine_mod.Machine;

pub const Fs = struct {
    /// filename (lowercase ASCII, as extracted) -> .prg contents (with the
    /// 2-byte load address header)
    files: std.StringHashMap([]const u8),
    /// filenames in original disk-directory order (the game's menu order)
    order: std.ArrayList([]const u8),
    /// SAVEd files captured here (per-castle progress, "y" files)
    saved: std.StringHashMap([]u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Fs {
        return .{
            .files = std.StringHashMap([]const u8).init(allocator),
            .order = .empty,
            .saved = std.StringHashMap([]u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn addFile(self: *Fs, name: []const u8, data: []const u8) !void {
        try self.files.put(name, data);
        try self.order.append(self.allocator, name);
    }

    pub fn deinit(self: *Fs) void {
        var it = self.saved.iterator();
        while (it.next()) |e| {
            self.allocator.free(e.key_ptr.*);
            self.allocator.free(e.value_ptr.*);
        }
        var fit = self.files.iterator();
        while (fit.next()) |e| {
            self.allocator.free(e.key_ptr.*);
            self.allocator.free(e.value_ptr.*);
        }
        self.files.deinit();
        self.order.deinit(self.allocator);
        self.saved.deinit();
    }

    fn lookup(self: *Fs, name: []const u8) ?[]const u8 {
        // strip an optional "0:" drive prefix
        const clean = if (std.mem.startsWith(u8, name, "0:")) name[2..] else name;
        if (self.saved.get(clean)) |d| return d;
        return self.files.get(clean);
    }
};

const Channel = struct {
    sa: u8,
    /// stream data; owned iff owned is true (directory listings)
    data: []const u8,
    pos: usize,
    owned: bool,
    is_command: bool,
};

const State = struct {
    filename_addr: u16 = 0,
    filename_len: u8 = 0,
    lfn: u8 = 0,
    secondary: u8 = 0,
    /// channels keyed by logical file number
    channels: [256]?Channel = @splat(null),
    input_lfn: ?u8 = null,
    /// KERNAL I/O status byte ($90): bit 6 = EOF, bit 7 = device not present
    status: u8 = 0,
};

var state: State = .{};
var fs_instance: ?*Fs = null;

const drive_status = "00, OK,00,00\r";

pub fn install(m: *Machine, fs: *Fs) !void {
    fs_instance = fs;
    state = .{};
    const hooks = [_]struct { u16, []const u8, *const fn (*Machine) bool }{
        .{ 0xFFBA, "SETLFS", hookSetlfs },
        .{ 0xFFBD, "SETNAM", hookSetnam },
        .{ 0xFFD5, "LOAD", hookLoad },
        .{ 0xFFD8, "SAVE", hookSave },
        .{ 0xFFC0, "OPEN", hookOpen },
        .{ 0xFFC3, "CLOSE", hookClose },
        .{ 0xFFC6, "CHKIN", hookChkin },
        .{ 0xFFC9, "CHKOUT", hookSuccess },
        .{ 0xFFCF, "CHRIN", hookChrin },
        .{ 0xFFD2, "CHROUT", hookSuccess },
        .{ 0xFFCC, "CLRCHN", hookClrchn },
        .{ 0xFFE7, "CLALL", hookClall },
        .{ 0xFFE4, "GETIN", hookGetin },
        .{ 0xFFB7, "READST", hookReadst },
        .{ 0xFF81, "CINT", hookSuccess },
        .{ 0xFF84, "IOINIT", hookSuccess },
        .{ 0xFF87, "RAMTAS", hookSuccess },
        .{ 0xFF8A, "RESTOR", hookSuccess },
        .{ 0xFF8D, "VECTOR", hookSuccess },
        .{ 0xFF90, "SETMSG", hookSuccess },
        .{ 0xFF9F, "SCNKEY", hookSuccess },
        .{ 0xFFE1, "STOP", hookStop },
        .{ 0xFFEA, "UDTIM", hookSuccess },
    };
    for (hooks) |h| {
        try m.addHook(h[0], .{ .name = h[1], .func = h[2] });
    }
}

fn petsciiToLower(b: u8) u8 {
    if (b >= 0x41 and b <= 0x5A) return b + 0x20;
    if (b >= 0xC1 and b <= 0xDA) return b - 0x80;
    return b;
}

fn readFilename(m: *Machine, buf: []u8) []const u8 {
    const n = @min(state.filename_len, buf.len);
    for (0..n) |idx| {
        buf[idx] = petsciiToLower(m.ram[state.filename_addr +% @as(u16, @intCast(idx))]);
    }
    return buf[0..n];
}

/// Build a 1541-style directory listing as a fake BASIC program, including
/// the leading $0401 load address. Caller owns the returned buffer.
fn buildDirectory(m: *Machine, fs: *Fs, pattern: []const u8) ![]u8 {
    const prefix = if (std.mem.indexOfScalar(u8, pattern, '*')) |star|
        pattern[0..star]
    else
        pattern;

    var listing: std.ArrayList(u8) = .empty;
    errdefer listing.deinit(m.allocator);
    const a = m.allocator;

    try listing.appendSlice(a, &.{ 0x01, 0x04 }); // load address
    // header line: line number 0, reverse-video disk name
    try listing.appendSlice(a, &.{ 0x01, 0x04, 0x00, 0x00 });
    try listing.appendSlice(a, "\x12\"DUNGEONMASTER  \" DM 2A");
    try listing.append(a, 0x00);

    for (fs.order.items) |fname| {
        if (!std.mem.startsWith(u8, fname, prefix)) continue;
        const fdata = fs.files.get(fname).?;
        const blocks: u16 = @intCast((fdata.len + 253) / 254);
        try listing.appendSlice(a, &.{ 0x01, 0x04, @intCast(blocks & 0xFF), @intCast(blocks >> 8) });
        try listing.appendSlice(a, "   \"");
        for (fname) |c| {
            try listing.append(a, if (c >= 'a' and c <= 'z') c - 0x20 else c);
        }
        try listing.append(a, '"');
        var pad: usize = 16 - @min(fname.len, 16);
        while (pad > 0) : (pad -= 1) try listing.append(a, ' ');
        try listing.appendSlice(a, " PRG ");
        try listing.append(a, 0x00);
    }
    try listing.appendSlice(a, &.{ 0x01, 0x04, 0x00, 0x00 });
    try listing.appendSlice(a, "BLOCKS FREE.");
    try listing.appendSlice(a, &.{ 0x00, 0x00, 0x00 });
    return listing.toOwnedSlice(a);
}

fn hookSetlfs(m: *Machine) bool {
    state.lfn = m.cpu.a;
    state.secondary = m.cpu.y;
    m.rts();
    return true;
}

fn hookSetnam(m: *Machine) bool {
    state.filename_len = m.cpu.a;
    state.filename_addr = @as(u16, m.cpu.x) | (@as(u16, m.cpu.y) << 8);
    m.rts();
    return true;
}

fn hookLoad(m: *Machine) bool {
    const fs = fs_instance orelse return false;
    var name_buf: [64]u8 = undefined;
    const name = readFilename(m, &name_buf);
    state.status = 0;

    var data: []const u8 = undefined;
    var owned: ?[]u8 = null;
    if (std.mem.startsWith(u8, name, "$")) {
        const pattern = if (std.mem.indexOfScalar(u8, name, ':')) |colon|
            name[colon + 1 ..]
        else
            name[1..];
        owned = buildDirectory(m, fs, pattern) catch return false;
        data = owned.?;
    } else {
        data = fs.lookup(name) orelse {
            std.log.warn("KERNAL LOAD: file not found: '{s}'", .{name});
            m.cpu.c = true;
            m.cpu.a = 4; // FILE NOT FOUND
            m.rts();
            return true;
        };
    }
    defer if (owned) |o| m.allocator.free(o);

    const load_addr: u16 = if (state.secondary != 0)
        @as(u16, data[0]) | (@as(u16, data[1]) << 8)
    else
        @as(u16, m.cpu.x) | (@as(u16, m.cpu.y) << 8);

    const payload = data[2..];
    @memcpy(m.ram[load_addr .. load_addr + payload.len], payload);

    const end = load_addr + payload.len;
    m.cpu.x = @intCast(end & 0xFF);
    m.cpu.y = @intCast(end >> 8);
    m.cpu.c = false;
    state.status = 0x40; // EOF: load complete
    std.log.info("KERNAL LOAD '{s}' -> ${x:0>4}-${x:0>4}", .{ name, load_addr, end });
    m.rts();
    return true;
}

fn hookSave(m: *Machine) bool {
    const fs = fs_instance orelse return false;
    var name_buf: [64]u8 = undefined;
    const raw = readFilename(m, &name_buf);
    // strip "@0:" / "0:" replace-file prefixes
    const name = if (std.mem.indexOfScalar(u8, raw, ':')) |colon| raw[colon + 1 ..] else raw;

    const start_ptr = m.cpu.a;
    const start = @as(u16, m.ram[start_ptr]) | (@as(u16, m.ram[start_ptr + 1]) << 8);
    const end = @as(u16, m.cpu.x) | (@as(u16, m.cpu.y) << 8);

    const blob = m.allocator.alloc(u8, 2 + (end - start)) catch {
        m.cpu.c = true;
        m.rts();
        return true;
    };
    blob[0] = @intCast(start & 0xFF);
    blob[1] = @intCast(start >> 8);
    @memcpy(blob[2..], m.ram[start..end]);

    const key = m.allocator.dupe(u8, name) catch {
        m.allocator.free(blob);
        m.cpu.c = true;
        m.rts();
        return true;
    };
    if (fs.saved.fetchRemove(key)) |old| {
        m.allocator.free(old.key);
        m.allocator.free(old.value);
    }
    fs.saved.put(key, blob) catch {};
    std.log.info("KERNAL SAVE '{s}' ${x:0>4}-${x:0>4}", .{ name, start, end });
    m.cpu.c = false;
    state.status = 0;
    m.rts();
    return true;
}

fn closeChannel(m: *Machine, lfn: u8) void {
    if (state.channels[lfn]) |ch| {
        if (ch.owned) m.allocator.free(@constCast(ch.data));
        state.channels[lfn] = null;
    }
}

fn hookOpen(m: *Machine) bool {
    const fs = fs_instance orelse return false;
    var name_buf: [64]u8 = undefined;
    const name = readFilename(m, &name_buf);
    state.status = 0;
    closeChannel(m, state.lfn);

    if (state.secondary == 15) {
        // drive command channel: reading yields the status line
        state.channels[state.lfn] = .{
            .sa = 15,
            .data = drive_status,
            .pos = 0,
            .owned = false,
            .is_command = true,
        };
    } else if (std.mem.startsWith(u8, name, "$")) {
        const pattern = if (std.mem.indexOfScalar(u8, name, ':')) |colon|
            name[colon + 1 ..]
        else
            name[1..];
        const listing = buildDirectory(m, fs, pattern) catch return false;
        state.channels[state.lfn] = .{
            .sa = state.secondary,
            .data = listing,
            .pos = 0,
            .owned = true,
            .is_command = false,
        };
    } else if (fs.lookup(name)) |data| {
        state.channels[state.lfn] = .{
            .sa = state.secondary,
            .data = data,
            .pos = 0,
            .owned = false,
            .is_command = false,
        };
    } else {
        // nonexistent file: open "succeeds", first read reports EOF+error
        state.channels[state.lfn] = .{
            .sa = state.secondary,
            .data = "",
            .pos = 0,
            .owned = false,
            .is_command = false,
        };
        std.log.info("KERNAL OPEN missing file '{s}' (lfn {d})", .{ name, state.lfn });
    }
    m.cpu.c = false;
    m.rts();
    return true;
}

fn hookClose(m: *Machine) bool {
    closeChannel(m, m.cpu.a);
    m.cpu.c = false;
    m.rts();
    return true;
}

fn hookChkin(m: *Machine) bool {
    state.input_lfn = m.cpu.x;
    state.status = 0;
    m.cpu.c = state.channels[m.cpu.x] == null;
    m.rts();
    return true;
}

fn hookChrin(m: *Machine) bool {
    const lfn = state.input_lfn orelse {
        m.cpu.a = 0x0D;
        m.cpu.c = false;
        m.rts();
        return true;
    };
    if (state.channels[lfn]) |*ch| {
        if (ch.is_command) {
            m.cpu.a = ch.data[ch.pos];
            ch.pos = (ch.pos + 1) % ch.data.len;
        } else if (ch.pos < ch.data.len) {
            m.cpu.a = ch.data[ch.pos];
            ch.pos += 1;
            if (ch.pos == ch.data.len) state.status |= 0x40; // EOF on last byte
        } else {
            m.cpu.a = 0x0D;
            state.status |= 0x42;
        }
    } else {
        m.cpu.a = 0x0D;
        state.status |= 0x80; // device not present
    }
    m.cpu.c = false;
    m.rts();
    return true;
}

fn hookClrchn(m: *Machine) bool {
    state.input_lfn = null;
    m.cpu.c = false;
    m.rts();
    return true;
}

fn hookClall(m: *Machine) bool {
    for (0..state.channels.len) |lfn| {
        closeChannel(m, @intCast(lfn));
    }
    state.input_lfn = null;
    m.cpu.c = false;
    m.rts();
    return true;
}

fn hookGetin(m: *Machine) bool {
    m.cpu.a = 0;
    m.cpu.c = false;
    m.rts();
    return true;
}

fn hookReadst(m: *Machine) bool {
    m.cpu.a = state.status;
    m.cpu.z = state.status == 0;
    m.cpu.n = state.status & 0x80 != 0;
    m.rts();
    return true;
}

fn hookSuccess(m: *Machine) bool {
    m.cpu.c = false;
    m.rts();
    return true;
}

/// STOP key not pressed: Z clear
fn hookStop(m: *Machine) bool {
    m.cpu.z = false;
    m.cpu.a = 0xFF;
    m.rts();
    return true;
}
