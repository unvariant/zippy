const Iterator = @import("iterator.zig").Iterator;

pub fn empty (comptime T: type) Empty(T) {
    return .{};
}

pub fn once (item: anytype) Once(@TypeOf(item)) {
    return .{ .item = item, .done = false, };
}

pub fn repeat (item: anytype) Repeat(@TypeOf(item)) {
    return .{ .item = item, };
}

fn Empty(comptime T: type) type {
    return struct {
        const Self = @This();
        pub const Item = T;

        pub fn next (self: *Self) ?Item {
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

        pub fn next (self: *Self) ?Item {
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

        pub fn next (self: *Self) ?Item {
            return self.item;
        }

        pub usingnamespace Iterator(Self);
    };
}