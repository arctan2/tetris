const ray = @cImport({
    @cInclude("raylib.h");
});

pub const Mat = struct {
    pub fn lastNonEmptyRowIdx(mat: *[4][4]u1) usize {
        for(0..4) |i| {
            for(0..4) |j| {
                if(mat[i][j] == 1) {
                    return i;
                }
            }
        }
        return 0;
    }

    pub fn firstNonEmptyColIdx(mat: *[4][4]u1) i32 {
        for(0..4) |i| {
            for(0..4) |j| {
                if(mat[j][i] == 1) {
                    return @intCast(i);
                }
            }
        }
        return 0;
    }

    pub fn lastNonEmptyColIdx(mat: *[4][4]u1) i32 {
        var i: i32 = 3;
        while(i >= 0) : (i -= 1) {
            for(0..4) |j| {
                if(mat[j][@intCast(i)] == 1) {
                    return @intCast(i);
                }
            }
        }
        return 0;
    }
};

pub const Tetrimino = struct {
    mat: [4][4]u1,
    color: ray.Color,

    pub fn lastNonEmptyRowIdx(self: *Tetrimino) usize {
        return Mat.lastNonEmptyRowIdx(&self.mat);
    }

    pub fn firstNonEmptyColIdx(self: *Tetrimino) i32 {
        return Mat.firstNonEmptyColIdx(&self.mat);
    }

    pub fn lastNonEmptyColIdx(self: *Tetrimino) i32 {
        return Mat.lastNonEmptyColIdx(&self.mat);
    }

    pub fn rotate(self: *Tetrimino, new: *[4][4]u1) void {
        var new_x: usize = 3;
        for(0..4) |self_y| {
            const self_row = self.mat[self_y];
            for(0..4) |new_y| {
                new[new_y][new_x] = self_row[new_y];
            }
            new_x -|= 1;
        }
    }

    pub fn assignMap(self: *Tetrimino, new: *[4][4]u1) void {
        for(0..4) |i| {
            for(0..4) |j| {
                self.mat[i][j] = new[i][j];
            }
        }
    }

    pub fn assign(self: *Tetrimino, src: *Tetrimino) void {
        self.color = src.color;
        self.assignMap(&src.mat);
    }

    pub fn rotateInplace(self: *Tetrimino) void {
        var rotated: [4][4]u1 = undefined;
        self.rotate(&rotated);
        self.assignMap(&rotated);
    }
};

pub const Empty: Tetrimino = .{
    .mat = undefined,
    .color = ray.Color{}
};

pub var O: Tetrimino = .{
    .mat = .{
        .{0, 0, 0, 0},
        .{0, 1, 1, 0},
        .{0, 1, 1, 0},
        .{0, 0, 0, 0},
    },
    .color = ray.RED
};

pub var S: Tetrimino = .{
    .mat = .{
        .{0, 0, 0, 0},
        .{0, 1, 1, 0},
        .{1, 1, 0, 0},
        .{0, 0, 0, 0},
    },
    .color = ray.RED
};

pub var Z: Tetrimino = .{
    .mat = .{
        .{0, 0, 0, 0},
        .{1, 1, 0, 0},
        .{0, 1, 1, 0},
        .{0, 0, 0, 0},
    },
    .color = ray.RED
};

pub var I: Tetrimino = .{
    .mat = .{
        .{0, 1, 0, 0},
        .{0, 1, 0, 0},
        .{0, 1, 0, 0},
        .{0, 1, 0, 0},
    },
    .color = ray.RED
};

pub var L: Tetrimino = .{
    .mat = .{
        .{0, 1, 0, 0},
        .{0, 1, 0, 0},
        .{0, 1, 1, 0},
        .{0, 0, 0, 0},
    },
    .color = ray.RED
};

pub var J: Tetrimino = .{
    .mat = .{
        .{0, 0, 1, 0},
        .{0, 0, 1, 0},
        .{0, 1, 1, 0},
        .{0, 0, 0, 0},
    },
    .color = ray.RED
};

pub var T: Tetrimino = .{
    .mat = .{
        .{0, 1, 0, 0},
        .{0, 1, 1, 0},
        .{0, 1, 0, 0},
        .{0, 0, 0, 0},
    },
    .color = ray.RED
};
