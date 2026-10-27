//! The disk drive's filesystem: a disk is 35 tracks of 256-byte sectors,
//! laid out the way the classic single-sided drives of 1984 laid them
//! out, so a disk image from back then reads here unchanged.
//!
//! Track 18 is the disk's own: sector 0 holds the block availability map
//! (the BAM: which sectors are free) and the disk's name, and the
//! directory is a chain of sectors from 18/1, eight 32-byte entries to a
//! sector. A file is a chain of sectors too: each starts with the track
//! and sector of the next, then 254 bytes of the file. The last sector
//! has track 0, and its second byte says where its data ends.
//!
//! Every function here works on a plain `Image` and nothing else, so a
//! game can build a disk while it compiles, and the machine can read and
//! write one while it runs. Each also counts the sectors it touched,
//! which is what the machine charges for.

const std = @import("std");

pub const tracks = 35;
pub const sector_count = 683;
pub const image_size = sector_count * 256; // 174,848 bytes
pub const Image = [image_size]u8;

/// Image files come in four sizes: 35 or 40 tracks, each with or without
/// a byte of error codes per sector at the end. We read the first 35
/// tracks and ignore the rest.
pub const image_sizes = [_]usize{ 174_848, 175_531, 196_608, 197_376 };

/// A sector carries 254 bytes of its file; the first two say where the
/// next one is.
pub const data_per_sector = 254;
/// File names are up to 16 letters, padded on the disk with $A0.
pub const name_max = 16;
pub const pad: u8 = 0xA0;
const dir_track = 18;
/// A closed program file, the only kind we write. Bit 7: closed.
const prg: u8 = 0x82;

pub const Error = error{ NotFound, Exists, DiskFull, TooLong, BadName, BadDisk };

/// What a program writes to `hw.drive_command`.
pub const Command = enum(u8) {
    /// Load the file named at `hw.drive_name` into RAM at
    /// `hw.drive_address`, less its first two bytes (its load address),
    /// and no more than `hw.drive_length` bytes. "$" loads the directory.
    load = 1,
    /// Save `hw.drive_length` bytes from `hw.drive_address` as the file
    /// named; "@0:" in front of the name saves over one already there.
    save = 2,
    _,
};

/// What the drive leaves in `hw.drive_status` after a command.
pub const Status = enum(u8) {
    ok = 0,
    no_disk = 1, // the drive is empty
    not_found = 2, // no file by that name
    exists = 3, // a save, to a name that's taken (put "@0:" in front)
    full = 4, // not enough free blocks
    too_long = 5, // a load bigger than drive_length: that much came
    bad_name = 6, // empty, too long, or a pattern where a name must be
    bad_disk = 7, // the disk's chains lead nowhere
    _,
};

pub fn sectorsOn(track: u8) u8 {
    return if (track <= 17) 21 else if (track <= 24) 19 else if (track <= 30) 18 else 17;
}

/// Where sector `sector` of `track` starts in the image, or null if the
/// disk has no such sector.
pub fn offset(track: u8, sector: u8) ?usize {
    if (track == 0 or track > tracks or sector >= sectorsOn(track)) return null;
    var n: usize = 0;
    var t: u8 = 1;
    while (t < track) : (t += 1) n += sectorsOn(t);
    return (n + sector) * 256;
}

const Ts = struct { track: u8, sector: u8 };

// ---- the BAM ----------------------------------------------------------------

const bam = 0x16500; // offset(18, 0)
const bam_name = bam + 0x90;

comptime {
    if (offset(18, 0).? != bam) @compileError("the BAM is at 18/0");
}

fn bamEntry(track: u8) usize {
    return bam + 4 * @as(usize, track);
}

fn isFree(img: *const Image, t: u8, s: u8) bool {
    return img[bamEntry(t) + 1 + s / 8] & (@as(u8, 1) << @intCast(s % 8)) != 0;
}

fn setFree(img: *Image, t: u8, s: u8, free: bool) void {
    const e = bamEntry(t);
    const bit = @as(u8, 1) << @intCast(s % 8);
    if (isFree(img, t, s) == free) return;
    if (free) {
        img[e + 1 + s / 8] |= bit;
        img[e] += 1;
    } else {
        img[e + 1 + s / 8] &= ~bit;
        img[e] -= 1;
    }
}

/// Free sectors outside the directory track: the "BLOCKS FREE" a listing
/// ends with.
pub fn blocksFree(img: *const Image) u16 {
    var n: u16 = 0;
    var t: u8 = 1;
    while (t <= tracks) : (t += 1) {
        if (t != dir_track) n += img[bamEntry(t)];
    }
    return n;
}

/// A blank disk called `name`, with the two-letter `id`.
pub fn format(img: *Image, name: []const u8, id: [2]u8) void {
    @memset(img, 0);
    img[bam + 0] = dir_track; // the directory starts at 18/1
    img[bam + 1] = 1;
    img[bam + 2] = 0x41; // the format's letter, "A"
    var t: u8 = 1;
    while (t <= tracks) : (t += 1) {
        var s: u8 = 0;
        while (s < sectorsOn(t)) : (s += 1) setFree(img, t, s, true);
    }
    setFree(img, dir_track, 0, false);
    setFree(img, dir_track, 1, false);
    @memset(img[bam_name..][0 .. 0xAB - 0x90], pad);
    for (name[0..@min(name.len, name_max)], 0..) |c, i| img[bam_name + i] = c;
    img[bam + 0xA2] = id[0];
    img[bam + 0xA3] = id[1];
    img[bam + 0xA5] = '2'; // the format, "2A"
    img[bam + 0xA6] = 'A';
    const dir = offset(dir_track, 1).?;
    img[dir + 0] = 0; // the only directory sector so far
    img[dir + 1] = 0xFF;
}

// ---- names ------------------------------------------------------------------

/// A name as a program gives it: "$" or "$0:Z*" asks for the directory
/// listing (of the files that match); "@0:NAME" saves over NAME if it's
/// there; "0:" in front names the drive, and there's only one. `*` matches
/// the rest of a name and `?` any one letter.
pub const Name = struct {
    listing: bool = false,
    replace: bool = false,
    pattern: []const u8,
};

pub fn parse(raw: []const u8) Error!Name {
    var n: Name = .{ .pattern = raw };
    var s = raw;
    if (s.len > 0 and s[0] == '$') {
        n.listing = true;
        s = s[1..];
    } else if (s.len > 0 and s[0] == '@') {
        n.replace = true;
        s = s[1..];
    }
    if (std.mem.indexOfScalar(u8, s, ':')) |colon| s = s[colon + 1 ..];
    if (n.listing and s.len == 0) s = "*";
    if (s.len == 0 or s.len > name_max) return error.BadName;
    for (s) |c| if (c == '"' or c == ',' or c == ':' or c == pad) return error.BadName;
    n.pattern = s;
    return n;
}

fn wild(pattern: []const u8) bool {
    return std.mem.indexOfAny(u8, pattern, "*?") != null;
}

/// Does a directory entry's 16-byte, padded name match `pattern`?
pub fn matches(pattern: []const u8, name: []const u8) bool {
    var i: usize = 0;
    while (i < pattern.len) : (i += 1) {
        const c = pattern[i];
        if (c == '*') return true;
        if (i >= name_max or name[i] == pad) return false;
        if (c != '?' and c != name[i]) return false;
    }
    return i == name_max or name[i] == pad;
}

// ---- the directory ----------------------------------------------------------

/// Walks the directory's entries in disk order, counting sectors read.
const Walk = struct {
    img: *const Image,
    touched: *u32,
    sector: usize, // the directory sector we're in
    i: u8 = 8, // the entry in it; 8 = read the next sector
    next: Ts = .{ .track = dir_track, .sector = 1 },
    steps: u16 = 0,

    /// The next entry's offset in the image, empty or not.
    fn entry(w: *Walk) Error!?usize {
        if (w.i == 8) {
            if (w.next.track == 0) return null;
            w.steps += 1;
            if (w.steps > sector_count) return error.BadDisk; // a chain that loops
            w.sector = offset(w.next.track, w.next.sector) orelse return error.BadDisk;
            w.touched.* += 1;
            w.next = .{ .track = w.img[w.sector], .sector = w.img[w.sector + 1] };
            w.i = 0;
        }
        const at = w.sector + 32 * @as(usize, w.i);
        w.i += 1;
        return at;
    }

    /// The next file in use (not deleted, not left open).
    fn file(w: *Walk) Error!?usize {
        while (try w.entry()) |at| {
            if (w.img[at + 2] & 0x80 != 0 and w.img[at + 2] & 7 != 0) return at;
        }
        return null;
    }
};

fn walk(img: *const Image, touched: *u32) Walk {
    return .{ .img = img, .touched = touched, .sector = 0 };
}

/// The first file whose name matches `pattern`, in directory order.
pub fn find(img: *const Image, pattern: []const u8, touched: *u32) Error!?usize {
    var w = walk(img, touched);
    while (try w.file()) |at| {
        if (matches(pattern, img[at + 5 ..][0..name_max])) return at;
    }
    return null;
}

// ---- reading ----------------------------------------------------------------

/// Bytes going out to a program: the first `skip` are dropped (a file's
/// load address), the rest land in `out` while there's room, and `total`
/// counts them all.
const Sink = struct {
    out: []u8,
    skip: usize = 2,
    total: usize = 0,

    fn put(s: *Sink, b: u8) void {
        if (s.skip > 0) {
            s.skip -= 1;
            return;
        }
        if (s.total < s.out.len) s.out[s.total] = b;
        s.total += 1;
    }
    fn text(s: *Sink, t: []const u8) void {
        for (t) |b| s.put(b);
    }
};

/// Load the file `name` (or a listing of the directory) into `out`, less
/// its first two bytes, the load address. Returns the length of the whole
/// file less those two; if that's more than `out` holds, `out` has the
/// start of it.
pub fn load(img: *const Image, raw: []const u8, out: []u8, touched: *u32) Error!usize {
    const name = try parse(raw);
    var sink = Sink{ .out = out };
    if (name.listing) {
        try listing(img, name.pattern, &sink, touched);
        return sink.total;
    }
    if (name.replace) return error.BadName;
    const at = (try find(img, name.pattern, touched)) orelse return error.NotFound;
    var next = Ts{ .track = img[at + 3], .sector = img[at + 4] };
    var steps: u16 = 0;
    while (next.track != 0) {
        steps += 1;
        if (steps > sector_count) return error.BadDisk;
        const s = offset(next.track, next.sector) orelse return error.BadDisk;
        touched.* += 1;
        const last = img[s] == 0;
        const end: usize = if (last) @as(usize, @max(img[s + 1], 1)) + 1 else 256;
        for (img[s + 2 .. s + end]) |b| sink.put(b);
        next = .{ .track = img[s], .sector = img[s + 1] };
    }
    return sink.total;
}

/// The directory as the drive sends it: a little program listing, a line
/// for the disk's name, a line for each matching file (its line number is
/// its length in blocks), and a last line of blocks free. Each line
/// starts with two link bytes (always 1, 1; 0, 0 ends it all) and its
/// number, and ends with a zero byte.
fn listing(img: *const Image, pattern: []const u8, sink: *Sink, touched: *u32) Error!void {
    touched.* += 1; // the BAM, for the disk's name
    sink.text(&.{ 0x01, 0x04 }); // where a listing loads: skipped
    sink.text(&.{ 1, 1, 0, 0, 0x12, '"' }); // line 0, in reverse
    for (img[bam_name..][0..name_max]) |c| sink.put(if (c == pad) ' ' else c);
    sink.put('"');
    sink.put(' ');
    for (img[bam + 0xA2 ..][0..5]) |c| sink.put(if (c == pad) ' ' else c);
    sink.put(0);
    var w = walk(img, touched);
    while (try w.file()) |at| {
        const name = img[at + 5 ..][0..name_max];
        if (!matches(pattern, name)) continue;
        const blocks = @as(u16, img[at + 30]) | @as(u16, img[at + 31]) << 8;
        sink.text(&.{ 1, 1, @truncate(blocks), @truncate(blocks >> 8) });
        var used: usize = 4;
        const spaces: usize = if (blocks < 10) 3 else if (blocks < 100) 2 else 1;
        for (0..spaces) |_| sink.put(' ');
        sink.put('"');
        var len: usize = 0;
        while (len < name_max and name[len] != pad) : (len += 1) sink.put(name[len]);
        sink.put('"');
        for (len..name_max) |_| sink.put(' ');
        sink.text(" PRG");
        used += spaces + 2 + name_max + 4;
        while (used < 31) : (used += 1) sink.put(' ');
        sink.put(0);
    }
    const free = blocksFree(img);
    sink.text(&.{ 1, 1, @truncate(free), @truncate(free >> 8) });
    sink.text("BLOCKS FREE.             ");
    sink.text(&.{ 0, 0, 0 });
}

// ---- writing ----------------------------------------------------------------

const interleave = 10; // sectors on between one block of a file and the next

/// The next free sector for a file: further round the same track (ten
/// sectors on, so the disk has turned past while the last was being
/// handled, and one back each time round, as the drives of the day did),
/// else the nearest track to the directory that has room.
fn nextFree(img: *const Image, prev: ?Ts) ?Ts {
    if (prev) |p| {
        // Ten on, and one back each time it wraps round the track.
        const n = sectorsOn(p.track);
        var s = p.sector + interleave;
        if (s >= n) {
            s -= n;
            if (s > 0) s -= 1;
        }
        if (freeOn(img, p.track, s)) |f| return .{ .track = p.track, .sector = f };
    }
    var d: u8 = 1;
    while (d < tracks) : (d += 1) {
        for ([2]i16{ dir_track - @as(i16, d), dir_track + @as(i16, d) }) |t| {
            if (t < 1 or t > tracks) continue;
            const track: u8 = @intCast(t);
            if (freeOn(img, track, 0)) |s| return .{ .track = track, .sector = s };
        }
    }
    return null;
}

/// The first free sector on `track` from `from` on, round the track.
fn freeOn(img: *const Image, track: u8, from: u8) ?u8 {
    const n = sectorsOn(track);
    var i: u8 = 0;
    while (i < n) : (i += 1) {
        const s = (from + i) % n;
        if (isFree(img, track, s)) return s;
    }
    return null;
}

fn freeChain(img: *Image, first: Ts, touched: *u32) Error!void {
    var next = first;
    var steps: u16 = 0;
    while (next.track != 0) {
        steps += 1;
        if (steps > sector_count) return error.BadDisk;
        const s = offset(next.track, next.sector) orelse return error.BadDisk;
        touched.* += 1;
        setFree(img, next.track, next.sector, true);
        next = .{ .track = img[s], .sector = img[s + 1] };
    }
}

/// An empty directory entry, adding a directory sector if they're full.
fn emptyEntry(img: *Image, touched: *u32) Error!usize {
    var w = walk(img, touched);
    var last: usize = 0;
    while (try w.entry()) |at| {
        if (img[at + 2] == 0) return at;
        last = w.sector;
    }
    // A new sector after the last one, three on so the disk has time to turn.
    const prev_sector: u8 = blk: {
        var s: u8 = 0;
        while (s < sectorsOn(dir_track)) : (s += 1) {
            if (offset(dir_track, s).? == last) break :blk s;
        }
        return error.BadDisk;
    };
    const s = freeOn(img, dir_track, prev_sector + 3) orelse return error.DiskFull;
    setFree(img, dir_track, s, false);
    const fresh = offset(dir_track, s).?;
    @memset(img[fresh..][0..256], 0);
    img[fresh + 1] = 0xFF;
    img[last] = dir_track;
    img[last + 1] = s;
    touched.* += 2;
    return fresh;
}

/// Save `data` as the file `name`, with `address` as its load address
/// (its first two bytes). "@0:" in front replaces a file of that name.
pub fn save(img: *Image, raw: []const u8, address: u16, data: []const u8, touched: *u32) Error!void {
    const name = try parse(raw);
    if (name.listing or wild(name.pattern)) return error.BadName;
    const needed = (data.len + 2 + data_per_sector - 1) / data_per_sector;
    touched.* += 1; // the BAM
    var free: usize = blocksFree(img);
    const old = try find(img, name.pattern, touched);
    if (old) |at| {
        if (!name.replace) return error.Exists;
        free += @as(u16, img[at + 30]) | @as(u16, img[at + 31]) << 8;
    }
    if (needed > free) return error.DiskFull;
    const at = old orelse try emptyEntry(img, touched);
    if (old != null) try freeChain(img, .{ .track = img[at + 3], .sector = img[at + 4] }, touched);

    var prev: ?Ts = null;
    var first: Ts = undefined;
    var done: usize = 0; // bytes of the file written: the address, then data
    var sector: usize = 0;
    while (done < data.len + 2) {
        const ts = nextFree(img, prev) orelse return error.DiskFull;
        setFree(img, ts.track, ts.sector, false);
        const s = offset(ts.track, ts.sector).?;
        if (prev == null) first = ts else {
            img[sector] = ts.track;
            img[sector + 1] = ts.sector;
        }
        @memset(img[s..][0..256], 0);
        var i: usize = 2;
        while (i < 256 and done < data.len + 2) : (i += 1) {
            img[s + i] = switch (done) {
                0 => @truncate(address),
                1 => @truncate(address >> 8),
                else => data[done - 2],
            };
            done += 1;
        }
        img[s] = 0; // the last, until another follows
        img[s + 1] = @intCast(i - 1);
        touched.* += 1;
        prev = ts;
        sector = s;
    }
    img[at + 2] = prg;
    img[at + 3] = first.track;
    img[at + 4] = first.sector;
    @memset(img[at + 5 ..][0..name_max], pad);
    @memcpy(img[at + 5 ..][0..name.pattern.len], name.pattern);
    @memset(img[at + 21 ..][0..9], 0);
    img[at + 30] = @truncate(needed);
    img[at + 31] = @truncate(needed >> 8);
}

// ---- tests ------------------------------------------------------------------

const testing = std.testing;

fn blank() !*Image {
    const img = try testing.allocator.create(Image);
    format(img, "TEST DISK", .{ 'T', '1' });
    return img;
}

test "a fresh disk has 664 blocks free and an empty directory" {
    const img = try blank();
    defer testing.allocator.destroy(img);
    try testing.expectEqual(664, blocksFree(img));
    var n: u32 = 0;
    try testing.expectEqual(null, try find(img, "*", &n));
    try testing.expectEqual(1, n); // read 18/1 and found nothing
    try testing.expectEqual(@as(usize, 357) * 256, offset(18, 0).?);
    try testing.expectEqual(null, offset(36, 0));
    try testing.expectEqual(null, offset(18, 19));
}

test "a file saves and loads back, less its load address" {
    const img = try blank();
    defer testing.allocator.destroy(img);
    var data: [600]u8 = undefined;
    for (&data, 0..) |*b, i| b.* = @truncate(i * 7);
    var n: u32 = 0;
    try save(img, "ZCASTLE", 0x9800, &data, &n);
    try testing.expectEqual(664 - 3, blocksFree(img)); // 602 bytes: 3 sectors
    var out: [1000]u8 = undefined;
    n = 0;
    try testing.expectEqual(600, try load(img, "ZCASTLE", &out, &n));
    try testing.expectEqualSlices(u8, &data, out[0..600]);
    try testing.expectEqual(1 + 3, n); // a directory sector, then the file
    // Too little room: the start of it, and its whole length.
    try testing.expectEqual(600, try load(img, "Z*", out[0..10], &n));
    try testing.expectEqualSlices(u8, data[0..10], out[0..10]);
    try testing.expectError(error.NotFound, load(img, "ZOTHER", &out, &n));
}

test "the listing is in directory order, and a pattern picks files" {
    const img = try blank();
    defer testing.allocator.destroy(img);
    var n: u32 = 0;
    for ([_][]const u8{ "ZBETA", "YBETA", "ZALPHA", "NOTES" }) |name| try save(img, name, 0x1000, "x", &n);
    var out: [2000]u8 = undefined;
    const len = try load(img, "$0:Z*", &out, &n);
    const text = out[0..len];
    try testing.expectEqualSlices(u8, &.{ 1, 1, 0, 0, 0x12, '"' }, text[0..6]);
    const beta = std.mem.indexOf(u8, text, "\"ZBETA\"").?;
    const alpha = std.mem.indexOf(u8, text, "\"ZALPHA\"").?;
    try testing.expect(beta < alpha);
    try testing.expect(std.mem.indexOf(u8, text, "YBETA") == null);
    try testing.expect(std.mem.indexOf(u8, text, "660 BLOCKS FREE.") == null); // 660 is the line number, in binary
    try testing.expectEqualSlices(u8, &.{ 0, 0, 0 }, text[len - 3 ..]);
    try testing.expect(std.mem.indexOf(u8, text, "TEST DISK") != null);
}

test "saving over a file needs @, and a full disk refuses" {
    const img = try blank();
    defer testing.allocator.destroy(img);
    var n: u32 = 0;
    try save(img, "YSCORES", 0xB800, "one", &n);
    try testing.expectError(error.Exists, save(img, "YSCORES", 0xB800, "two", &n));
    try save(img, "@0:YSCORES", 0xB800, "two", &n);
    var out: [8]u8 = undefined;
    try testing.expectEqual(3, try load(img, "0:YSCORES", &out, &n));
    try testing.expectEqualSlices(u8, "two", out[0..3]);
    try testing.expectEqual(663, blocksFree(img)); // the old copy's block is free again
    try testing.expectError(error.BadName, save(img, "Y*", 0, "x", &n));
    try testing.expectError(error.BadName, save(img, "THIS NAME IS TOO LONG", 0, "x", &n));
    const big = try testing.allocator.alloc(u8, 664 * 254);
    defer testing.allocator.free(big);
    try testing.expectError(error.DiskFull, save(img, "BIG", 0, big, &n));
    try save(img, "BIG", 0, big[0 .. 662 * 254], &n); // just fits, with its address
    try testing.expectEqual(0, blocksFree(img));
}

test "the directory grows past eight files" {
    const img = try blank();
    defer testing.allocator.destroy(img);
    var n: u32 = 0;
    var name = "FILE00".*;
    for (0..20) |i| {
        name[4] = '0' + @as(u8, @intCast(i / 10));
        name[5] = '0' + @as(u8, @intCast(i % 10));
        try save(img, &name, 0, &name, &n);
    }
    var out: [6]u8 = undefined;
    try testing.expectEqual(6, try load(img, "FILE19", &out, &n));
    try testing.expectEqualSlices(u8, "FILE19", &out);
    try testing.expectEqual(664 - 20, blocksFree(img));
}

test "a disk can be made while the program compiles" {
    const img = comptime blk: {
        @setEvalBranchQuota(2_000_000);
        var d: Image = undefined;
        format(&d, "COMPILED", .{ 'C', '1' });
        var n: u32 = 0;
        save(&d, "ZHELLO", 0x9800, "HELLO", &n) catch unreachable;
        break :blk d;
    };
    var copy = img;
    var out: [5]u8 = undefined;
    var n: u32 = 0;
    try testing.expectEqual(5, try load(&copy, "ZHELLO", &out, &n));
    try testing.expectEqualSlices(u8, "HELLO", &out);
}

test "a file's sectors go ten on round the track, one back each time it wraps" {
    var img: Image = undefined;
    format(&img, "STEPS", "01".*);
    var n: u32 = 0;
    try save(&img, "LONG", 0x1000, &([_]u8{7} ** (254 * 5)), &n);
    const at = (try find(&img, "LONG", &n)).?;
    var ts = Ts{ .track = img[at + 3], .sector = img[at + 4] };
    var seen: [6]u8 = undefined;
    for (&seen) |*s| {
        try std.testing.expectEqual(17, ts.track);
        s.* = ts.sector;
        const o = offset(ts.track, ts.sector).?;
        ts = .{ .track = img[o], .sector = img[o + 1] };
    }
    try std.testing.expectEqualSlices(u8, &.{ 0, 10, 20, 8, 18, 6 }, &seen);
}
