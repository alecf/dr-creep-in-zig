//! The game's own disk, made while the game compiles: a blank disk, then
//! the castles saved onto it, each as a "Z" file, the way 1984 named its
//! castles. A load puts a file where it's told, whatever load address it
//! carries, so a castle loads into staging. No score files yet: a castle
//! gets one the first time someone escapes from it.

const machine = @import("machine");
const drive = machine.drive;
const map = @import("map.zig");
const training = @import("training.zig");
const hall = @import("hall.zig");

pub const image: drive.Image = blk: {
    @setEvalBranchQuota(4_000_000); // building a disk is a lot of compile-time loops
    var disk: drive.Image = undefined;
    drive.format(&disk, "CASTLES OF CREEP", "84".*);
    var sectors: u32 = 0; // the drive counts them; nothing's charged while compiling
    drive.save(&disk, "ZTRAINING", map.staging.first, training.bytes, &sectors) catch |e| @compileError("the master disk: " ++ @errorName(e));
    drive.save(&disk, "ZENTRANCE HALL", map.staging.first, hall.bytes, &sectors) catch |e| @compileError("the master disk: " ++ @errorName(e));
    break :blk disk;
};
