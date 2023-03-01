//! Zippy is a iterator library for zig

const std = @import("std");
const trait = std.meta.trait;

pub const Iterator = @import("iterator.zig").Iterator;

fn IterType(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .Pointer => |pinfo| switch (pinfo.size) {
            .One => switch (@typeInfo(pinfo.child)) {
                .Array => |info| Slice(info.child),
                else => @compileError("cannot provide iterator for " ++ @typeName(T) ++ " please implement custom iterator"),
            },
            .Slice => Slice(pinfo.child),
            else => @compileError("cannot provide iterator for " ++ @typeName(T) ++ " please implement custom iterator"),
        },
        .Array => |info| Slice(info.child),
        .Int, .Float, .Bool, .Optional, .Enum => Once(T),
        else => @compileError("cannot provide iterator for " ++ @typeName(T) ++ " please implement custom iterator"),
    };
}

pub fn iter(init: anytype) IterType(@TypeOf(init)) {
    return IterType(@TypeOf(init)).init(init);
}

fn Slice(comptime T: type) type {
    return struct {
        slice: []const T,
        index: usize,

        const Self = @This();
        pub const Item = *const T;

        pub fn init(slice: []const T) Self {
            return .{
                .slice = slice,
                .index = 0,
            };
        }

        pub fn next(self: *Self) ?Item {
            if (self.index < self.slice.len) {
                defer self.index += 1;
                return &self.slice[self.index];
            }
            return null;
        }

        pub usingnamespace Iterator(Self);
    };
}

pub fn empty(comptime T: type) Empty(T) {
    return .{};
}

pub fn once(item: anytype) Once(@TypeOf(item)) {
    return Once(@TypeOf(item)).init(item);
}

pub fn repeat(item: anytype) Repeat(@TypeOf(item)) {
    return .{
        .item = item,
    };
}

fn Empty(comptime T: type) type {
    return struct {
        const Self = @This();
        pub const Item = T;

        pub fn next(self: *Self) ?Item {
            _ = self;
            return null;
        }

        pub usingnamespace Iterator(Self);
    };
}

fn Once(comptime T: type) type {
    return struct {
        item: T,
        done: bool,

        const Self = @This();
        pub const Item = T;

        pub fn init(item: T) Self {
            return .{
                .item = item,
                .done = false,
            };
        }

        pub fn next(self: *Self) ?Item {
            if (self.done) {
                return null;
            }
            defer self.done = true;
            return self.item;
        }

        pub usingnamespace Iterator(Self);
    };
}

fn Repeat(comptime T: type) type {
    return struct {
        item: T,

        const Self = @This();
        pub const Item = T;

        pub fn next(self: *Self) ?Item {
            return self.item;
        }

        pub usingnamespace Iterator(Self);
    };
}
