//! The rule behind `m.view`: a type may be laid over RAM only if its bytes
//! in Zig are exactly its bytes in memory. No padding, no hidden extra
//! bytes, nothing whose size depends on the computer compiling it.

const std = @import("std");

/// Fails the build, with an explanation, if `T` can't be viewed.
pub fn check(comptime T: type) void {
    if (problem(T, @typeName(T))) |why| @compileError("m.view(" ++ @typeName(T) ++ "): " ++ why);
}

fn problem(comptime T: type, comptime what: []const u8) ?[]const u8 {
    const fmt = std.fmt.comptimePrint;
    switch (@typeInfo(T)) {
        .int => |info| {
            if (T == usize or T == isize)
                return what ++ " is " ++ @typeName(T) ++ ", whose size changes from computer to computer; use u16, u32, ...";
            if (info.bits % 8 != 0 or @sizeOf(T) * 8 != info.bits)
                return fmt("{s} is a u{d}, which takes {d} bytes in memory, not {d}; use [{d}]u8", .{
                    what, info.bits, @sizeOf(T), (info.bits + 7) / 8, (info.bits + 7) / 8,
                });
            return null;
        },
        .@"enum" => |info| {
            if (info.is_exhaustive)
                return what ++ " is an exhaustive enum; a byte with any other value would be illegal. " ++
                    "Store a u8, or add `_` to make the enum non-exhaustive";
            return problem(info.tag_type, what);
        },
        .array => |info| return problem(info.child, what ++ "[...]"),
        .@"struct" => |info| switch (info.layout) {
            .auto => return what ++ " has no fixed layout; make it an `extern struct` or a `packed struct`",
            .@"packed" => {
                if (@bitSizeOf(T) != @sizeOf(T) * 8)
                    return fmt("{s} is a packed struct of {d} bits, which takes {d} bytes in memory; " ++
                        "back it with u8, u16 or u32 (e.g. `packed struct(u8)`)", .{ what, @bitSizeOf(T), @sizeOf(T) });
                inline for (info.fields) |f| {
                    if (packedFieldProblem(f.type, what ++ "." ++ f.name)) |why| return why;
                }
                return null;
            },
            .@"extern" => {
                comptime var offset: usize = 0;
                inline for (info.fields) |f| {
                    const name = what ++ "." ++ f.name;
                    if (problem(f.type, name)) |why| return why;
                    if (@offsetOf(T, f.name) != offset)
                        return fmt("field {s} would start at byte {d}, but the fields before it only fill {d}: " ++
                            "Zig inserts padding to align a {s}. Use [{d}]u8 for it (and m.peek16), or move it", .{
                            name, @offsetOf(T, f.name), offset, @typeName(f.type), @sizeOf(f.type),
                        });
                    offset += @sizeOf(f.type);
                }
                if (offset != @sizeOf(T))
                    return fmt("{s} fills {d} bytes but takes {d} (padding at the end); reorder or use byte arrays", .{
                        what, offset, @sizeOf(T),
                    });
                return null;
            },
        },
        .@"union" => |info| {
            if (info.layout != .@"extern" and info.layout != .@"packed")
                return what ++ " has no fixed layout; make it an `extern union`";
            inline for (info.fields) |f| {
                if (problem(f.type, what ++ "." ++ f.name)) |why| return why;
                if (@sizeOf(f.type) != @sizeOf(T))
                    return what ++ "." ++ f.name ++ " is smaller than the union; every field must be the same size";
            }
            return null;
        },
        .bool => return what ++ " is a bool, which has no defined byte; use u8, or flags in a packed struct(u8)",
        .pointer => return what ++ " is a pointer; RAM holds addresses as u16 values",
        else => return what ++ " (" ++ @typeName(T) ++ ") has no fixed byte layout",
    }
}

/// Inside a packed struct, fields are bit ranges, so bools and odd widths
/// are fine. Only things whose width depends on the host are not.
fn packedFieldProblem(comptime T: type, comptime what: []const u8) ?[]const u8 {
    switch (@typeInfo(T)) {
        .bool => return null,
        .int => return if (T == usize or T == isize)
            what ++ " is " ++ @typeName(T) ++ ", whose size changes from computer to computer"
        else
            null,
        .@"enum" => |info| return packedFieldProblem(info.tag_type, what),
        .@"struct" => |info| {
            if (info.layout != .@"packed") return what ++ " must itself be a packed struct";
            inline for (info.fields) |f| {
                if (packedFieldProblem(f.type, what ++ "." ++ f.name)) |why| return why;
            }
            return null;
        },
        else => return what ++ " (" ++ @typeName(T) ++ ") can't go in a packed struct that is viewed over RAM",
    }
}

test "accepted layouts" {
    const Flags = packed struct(u8) { a: bool, b: bool, kind: u3, rest: u3 };
    const Rec = extern struct { x: u8, y: u8, color: u8, flags: Flags };
    const Wide = extern struct { word: u16, lo: u8, hi: u8 };
    const Kind = enum(u8) { door = 1, ladder = 2, _ };
    const ok = [_]type{ u8, u16, u32, [8]u8, Flags, Rec, [4]Rec, Wide, Kind, extern struct { k: Kind, n: u8 } };
    inline for (ok) |T| try std.testing.expect(comptime problem(T, "T") == null);
}

test "rejected layouts" {
    const bad = [_]type{
        usize,
        u24,
        u12,
        bool,
        *u8,
        struct { a: u8 },
        extern struct { color: u8, ptr: u16 },
        extern struct { ptr: u16, color: u8 },
        packed struct { a: u8, b: u16 },
        [2]u24,
        enum(u8) { a, b },
        packed struct(u64) { p: usize },
    };
    inline for (bad) |T| try std.testing.expect(comptime problem(T, "T") != null);
}
