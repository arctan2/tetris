const std = @import("std");
const ray = @cImport({
    @cInclude("raylib.h");
});
const str = @cImport({
    @cInclude("string.h");
});
const tetrimino = @import("./tetrimino.zig");

const CELL_SIZE = 40;
const ROWS = 20;
const COLS = 10;

const GAME_WIDTH = (CELL_SIZE * COLS);
const PANEL_WIDTH = 300;

const WIN_WIDTH = GAME_WIDTH + PANEL_WIDTH;
const WIN_HEIGHT = CELL_SIZE * ROWS;

const PANEL_START = WIN_WIDTH - PANEL_WIDTH;

const HEAD_FONT_SIZE = 40;
const FONT_SIZE = 24;
const COLORS: [10]ray.Color = .{
    ray.GREEN,
    ray.RED,
    ray.YELLOW,
    ray.MAGENTA,
    ray.BLUE,
    ray.LIME,
    ray.SKYBLUE,
    ray.PINK,
    ray.ORANGE,
    ray.PURPLE
};

const TETRIMINOS_REFS: [7]*tetrimino.Tetrimino = .{
    &tetrimino.O,
    &tetrimino.S,
    &tetrimino.Z,
    &tetrimino.I,
    &tetrimino.L,
    &tetrimino.J, 
    &tetrimino.T
};

const kick_table: [6][2]i8 = .{
    .{0, 0},
    .{-1, 0},
    .{1, 0},
    .{-1, 1},
    .{0, -2},
    .{-1, -2},
};

const I_kick_table: [6][2]i8 = .{
    .{0,  0},
    .{1,  0},
    .{-1, 0},
    .{-2, 0},
    .{-2, -1},
    .{1, 2},
};

fn randomColor() ray.Color {
    return COLORS[@intCast(ray.GetRandomValue(0, COLORS.len - 1))];
}

fn randomTetrimino() *tetrimino.Tetrimino {
    var t = TETRIMINOS_REFS[@intCast(ray.GetRandomValue(0, TETRIMINOS_REFS.len - 1))];
    t.color = randomColor();
    return t;
}

const DEBUG = false;

const Game = struct {
    cells: [ROWS][COLS]ray.Color,
    tetrimino: *tetrimino.Tetrimino,
    next: *tetrimino.Tetrimino,
    next_display_tetrimino: tetrimino.Tetrimino,
    points: u64,
    position: struct {
        x: c_int, y: c_int
    },
    window_should_close: bool,

    fn drawTextCenterAligned(string: [*c]const u8, x_start: c_int, x_end: c_int, y: c_int, font_size: c_int, color: ray.Color) void {
        const PADDING = 10;
        const x = x_start + @divFloor((x_end - x_start), @as(c_int, 2));
        const str_width = ray.MeasureText(string, font_size);
        const str_width_half = @divFloor(str_width, 2);
        const draw_x = x - str_width_half;
        const draw_y = y - @divFloor(font_size, @as(c_int, 2));
        ray.DrawRectangle(draw_x - PADDING, draw_y - PADDING, str_width + (PADDING * 2), font_size + (PADDING * 2), ray.BLACK);
        ray.DrawText(string, draw_x, draw_y, font_size, color);
    }

    fn gameBegin(self: *Game) void {
        ray.BeginDrawing();

        ray.ClearBackground(ray.BLACK);
        self.points = 0;
        self.position.x = 5; 
        self.position.y = -1;

        for (&self.cells) |*row| { for (row) |*c| { c.* = tetrimino.Empty.color; } }

        self.draw();
        self.drawSidePanel();
        drawTextCenterAligned("Press enter to start.", 0, GAME_WIDTH, WIN_HEIGHT / 2, 30, ray.WHITE);

        ray.EndDrawing();

        self.waitForEnterKey();
    }

    fn waitForEnterKey(self: *Game) void {
        while(!ray.IsKeyPressed(ray.KEY_ENTER) and !self.window_should_close) {
            ray.PollInputEvents();
            self.window_should_close = ray.WindowShouldClose();
        }
    }

    fn gameOver(self: *Game) void {
        ray.BeginDrawing();

        drawTextCenterAligned("Game Over!", 0, GAME_WIDTH, WIN_HEIGHT / 2, 40, ray.RED);
        drawTextCenterAligned("Press enter to continue.", 0, GAME_WIDTH, (WIN_HEIGHT / 2) + 50, 20, ray.WHITE);

        ray.EndDrawing();
        
        self.waitForEnterKey();
    }

    fn gameRunning(self: *Game) void {
        var eps: f32 = 0;
        var debounce_eps: f32 = 0;

        var idx: usize = 0;

        while (!self.window_should_close) {
            eps += ray.GetFrameTime();

            ray.BeginDrawing();

            self.drawSidePanel();

            if(ray.IsKeyDown(ray.KEY_DOWN)) {
                eps += 0.8;
            }

            if(ray.IsKeyDown(ray.KEY_LEFT)) {
                debounce_eps += ray.GetFrameTime();
                if(debounce_eps > 0.1 and self.canMoveLeft()) {
                    self.position.x -= 1;
                    ray.ClearBackground(ray.BLACK);
                    self.draw();
                    debounce_eps = 0;
                }
            }

            if(ray.IsKeyDown(ray.KEY_RIGHT)) {
                debounce_eps += ray.GetFrameTime();
                if(debounce_eps > 0.1 and self.canMoveRight()) {
                    self.position.x += 1;
                    ray.ClearBackground(ray.BLACK);
                    self.draw();
                    debounce_eps = 0;
                }
            }

            if(ray.IsKeyPressed(ray.KEY_UP)) {
                if(self.canRotate()) {
                    self.tetrimino.rotateInplace();
                }
                ray.ClearBackground(ray.BLACK);
                self.draw();
            }

            if(comptime DEBUG) {
                if(ray.IsKeyPressed(ray.KEY_N)) {
                    idx += 1;
                    if(idx >= TETRIMINOS_REFS.len) {
                        idx = TETRIMINOS_REFS.len - 1;
                    }
                    self.tetrimino = TETRIMINOS_REFS[idx];
                    ray.ClearBackground(ray.BLACK);
                    self.draw();
                }

                if(ray.IsKeyPressed(ray.KEY_P)) {
                    idx -|= 1;
                    self.tetrimino = TETRIMINOS_REFS[idx];
                    ray.ClearBackground(ray.BLACK);
                    self.draw();
                }

                if(ray.IsKeyPressed(ray.KEY_SPACE)) {
                    const stop_game = self.update();
                    if(stop_game) {
                        ray.EndDrawing();
                        break;
                    }
                    ray.ClearBackground(ray.BLACK);
                    self.draw();
                    eps = 0;
                }
            } else {
                if(eps > 0.5) {
                    const stop_game = self.update();
                    if(stop_game) {
                        ray.EndDrawing();
                        break;
                    }
                    ray.ClearBackground(ray.BLACK);
                    self.draw();
                    eps = 0;
                }
            }

            ray.EndDrawing();
            self.window_should_close = ray.WindowShouldClose();
        }
    }

    inline fn pad(x: *c_int, dx: u8) void {
        x.* += dx;
    }

    fn drawSidePanel(self: *Game) void {
        ray.DrawRectangle(PANEL_START, 0, PANEL_WIDTH, WIN_HEIGHT, .{.r = 22, .g = 22, .b = 22, .a = 255});

        var Y: c_int = 20;
        const heading = "Tetris";
        const heading_size = ray.MeasureText(heading, HEAD_FONT_SIZE);

        ray.DrawText("Tetris", (PANEL_WIDTH / 2) + PANEL_START - @divFloor(heading_size, 2), Y, HEAD_FONT_SIZE, ray.PINK);
        pad(&Y, HEAD_FONT_SIZE + 20);

        var buf = [_]u8{0} ** 32;
        const _str = std.fmt.bufPrint(&buf, "points: {}", .{self.points}) catch {
            std.debug.print("buffer overflow.", .{});
            std.process.exit(1);
        };

        ray.DrawText(@ptrCast(_str), PANEL_START + 10, Y, FONT_SIZE, ray.WHITE);
        pad(&Y, FONT_SIZE + 20);
        ray.DrawText("next: ", PANEL_START + 10, Y, FONT_SIZE, ray.WHITE);

        var y: c_int = Y + CELL_SIZE * 4;
        var block_y: c_int = 0;

        while(block_y < 4 and y >= 0) : ({ block_y += 1; y -= CELL_SIZE; }) {
            var x: c_int = PANEL_START + 50;
            var block_x: usize = 0;

            while(block_x < 4) : ({ block_x += 1; x += CELL_SIZE; }) {
                if(self.next_display_tetrimino.mat[@intCast(block_y)][block_x] == 1) {
                    ray.DrawRectangle(x, y, CELL_SIZE - 1, CELL_SIZE - 1, self.next_display_tetrimino.color);
                }
            }
        }
    }

    fn drawTetrimino(self: *Game) void {
        var y: c_int = self.position.y;
        var block_y: c_int = 0;

        while(block_y < 4 and y >= 0) : ({ block_y += 1; y -= 1; }) {
            var x: c_int = self.position.x;
            var block_x: usize = 0;

            while(block_x < 4) : ({ block_x += 1; x += 1; }) {
                if(self.tetrimino.mat[@intCast(block_y)][block_x] == 1) {
                    ray.DrawRectangle(x * CELL_SIZE, y * CELL_SIZE, CELL_SIZE - 1, CELL_SIZE - 1, self.tetrimino.color);
                } else {
                    // ray.DrawRectangle(x * CELL_SIZE, y * CELL_SIZE, CELL_SIZE - 1, CELL_SIZE - 1, ray.WHITE);
                }
            }
        }
    }

    fn draw_cells(self: *Game) void {
        const row_count = self.cells.len;
        const col_count = self.cells[0].len;

        var y: c_int = 0;
        var x: c_int = 1;

        var i: usize = 0;
        var j: usize = 0;

        while (i < row_count) : ({ i += 1; x = 1; j = 0; y += CELL_SIZE; }) {
            while (j < col_count) : ({ j += 1; x += CELL_SIZE; }) {
                ray.DrawRectangle(x, y, CELL_SIZE - 1, CELL_SIZE - 1, self.cells[i][j]);
            }
        }
    }

    fn draw(self: *Game) void {
        self.draw_cells();
        drawTetrimino(self);
    }

    fn clear_game_panel() void {
        ray.DrawRectangle(0, 0, GAME_WIDTH, WIN_HEIGHT, ray.BLACK);
    }

    fn isEmpty(color: ray.Color) bool {
        return color.r == 0 and color.g == 0 and color.b == 0 and color.a == 0;
    }

    fn checkPoints(self: *Game) void {
        var from_y: i32 = -1;

        var i: usize = 0;
        
        while(i < 4) : (i += 1) {
            const row_idx = @as(i32, @intCast(self.position.y)) - @as(i32, @intCast(i));
            if(row_idx >= ROWS) continue;
            if(row_idx < 0) break;

            var is_completely_filled = true;
            for(0..COLS) |j| {
                if(isEmpty(self.cells[@intCast(row_idx)][j])) {
                    is_completely_filled = false;
                    break;
                }
            }
            if(is_completely_filled) {
                from_y = row_idx;
                break;
            }
        }

        if(from_y == -1) {
            return;
        }

        var to_y: i32 = from_y;

        i += 1;
        outter: while(i < 4) : (i += 1){
            const row_idx = @as(i32, @intCast(self.position.y)) - @as(i32, @intCast(i));

            if(row_idx >= ROWS) continue;
            if(row_idx < 0) break;

            for(0..COLS) |j| {
                if(isEmpty(self.cells[@intCast(row_idx)][j])) {
                    break :outter;
                }
            }
            to_y = row_idx;
        }

        if(to_y == -1) {
            return;
        }

        const mid = @divFloor(COLS, 2) - 1;

        i = 0;
        while(i <= mid) : (i += 1) {
            var row_idx = to_y;
            while(row_idx <= from_y) : (row_idx += 1) {
                const sub = @subWithOverflow(mid, i);

                self.cells[@intCast(row_idx)][mid + i] = ray.Color{.r = 0, .g = 0, .b = 0, .a = 0};
                self.cells[@intCast(row_idx)][sub[0]] = ray.Color{.r = 0, .g = 0, .b = 0, .a = 0};

                self.points += 1;

                if(sub[1] != 1) {
                    self.points += 1;
                }

                ray.BeginDrawing();
                    clear_game_panel();
                    self.draw_cells();
                    self.drawSidePanel();
                ray.EndDrawing();

                ray.WaitTime(0.0005);
            }
        }

        self.draw();

        const count = from_y - to_y;

        for(0..(@as(usize, @intCast(count)) + 1)) |_| {
            var row_idx = from_y;
            while(row_idx >= 1) : (row_idx -= 1) {
                const top_idx = row_idx - 1;
                for(0..COLS) |col_idx| {
                    self.cells[@intCast(row_idx)][col_idx] = self.cells[@intCast(top_idx)][col_idx];
                }
            }

            ray.BeginDrawing();
                clear_game_panel();
                self.draw_cells();
            ray.EndDrawing();

            ray.WaitTime(0.05);
        }
    }

    fn update(self: *Game) bool {
        if(self.tetrimino == &tetrimino.Empty) {
            self.tetrimino = &tetrimino.O;
            self.position.x = 5;
            self.position.y = 0;
            return false;
        }

        var stop = false;

        const last_row_idx: c_int = @intCast(self.tetrimino.lastNonEmptyRowIdx());

        if(self.position.y + 1 - last_row_idx < self.cells.len) {
            const y: i32 = @intCast(self.position.y);
            const x: i32 = @intCast(self.position.x);

            outter: for(0..3) |rel_y| {
                const to_cmp_abs_y = y - @as(i32, @intCast(rel_y)) + 1;

                if(to_cmp_abs_y < 0) {
                    continue;
                }

                for(0..4) |rel_x| {
                    const to_cmp_abs_x = @as(i32, @intCast(rel_x)) + x;
                    if(to_cmp_abs_x < 0 or to_cmp_abs_x >= COLS) {
                        continue;
                    }

                    if(self.tetrimino.mat[rel_y][rel_x] == 1 and !isEmpty(self.cells[@intCast(to_cmp_abs_y)][@intCast(to_cmp_abs_x)])) {
                        stop = true;
                        break :outter;
                    }
                }
            }
        } else {
            stop = true;
        }

        if(stop) {
            var y: c_int = self.position.y - last_row_idx;
            var block_y: c_int = last_row_idx;

            if(self.isObstructed(&self.tetrimino.mat, &[2]i8{0, 0})) {
                return true;
            }

            while(block_y < 4 and y >= 0) : ({ block_y += 1; y -= 1; }) {
                var x: c_int = self.position.x;
                var block_x: usize = 0;

                while(block_x < 4) : ({ block_x += 1; x += 1; }) {
                    const c = self.tetrimino.mat[@intCast(block_y)][block_x];
                    if(x < 0 or x >= COLS) continue;
                    if(c == 1) {
                        self.cells[@intCast(y)][@intCast(x)] = self.tetrimino.color;
                    }
                }
            }

            self.checkPoints();

            self.position.y = 0;
            self.position.x = ray.GetRandomValue(0, COLS - 5);
            self.tetrimino = self.next;
            self.next = randomTetrimino();
            self.next_display_tetrimino.assign(self.next);
        } else {
            self.position.y += 1;
        }

        return false;
    }

    fn cmpColumns(self: *Game, rel_x: i32, abs_cmp_x: i32) bool {
        for(0..4) |y| {
            const is_mat_1 = self.tetrimino.mat[y][@intCast(rel_x)] == 1;
            const abs_y = self.position.y - @as(i32, @intCast(y));
            if(abs_y < 0 or abs_y >= ROWS) {
                continue;
            }
            const is_cell_filled = !isEmpty(self.cells[@intCast(abs_y)][@intCast(abs_cmp_x)]);
            if(is_mat_1 and is_cell_filled) {
                return false;
            }
        }
        return true;
    }

    pub fn canMoveLeft(self: *Game) bool {
        const rel_x = self.tetrimino.firstNonEmptyColIdx();
        const abs_x = self.position.x + rel_x;
        const boundary_check = abs_x > 0;
        const abs_cmp_x: i32 = abs_x - 1;

        if(abs_cmp_x >= 0) {
            return self.cmpColumns(rel_x, abs_cmp_x) and boundary_check;
        }
        return boundary_check;
    }

    pub fn isObstructed(self: *Game, mat: *[4][4]u1, offset: *const [2]i8) bool {
        for(0..4) |y| {
            const rel_y: i32 = @intCast(y);
            const abs_y = @as(i32, @intCast(self.position.y)) - rel_y - offset[1];
            if(abs_y < 0 or abs_y >= ROWS) {
                for(0..4) |x| {
                    if(mat[@intCast(rel_y)][x] == 1) {
                        return true;
                    }
                }
                continue;
            }

            for(0..4) |x| {
                const rel_x: i32 = @intCast(x);

                if(mat[@intCast(rel_y)][@intCast(rel_x)] == 0) {
                    continue;
                }

                const abs_x = @as(i32, @intCast(self.position.x)) + rel_x + offset[0];
                if(abs_x < 0 or abs_x >= COLS) {
                    return true;
                }

                if(!isEmpty(self.cells[@intCast(abs_y)][@intCast(abs_x)])) {
                    return true;
                }
            }
        }
        return false;
    }

    pub fn canRotate(self: *Game) bool {
        if(self.tetrimino == &tetrimino.O) {
            return true;
        }

        var rotated: [4][4]u1 = undefined;
        self.tetrimino.rotate(&rotated);

        var k: [6][2]i8 = .{undefined} ** 6;
        if(self.tetrimino == &tetrimino.I) {
            k = I_kick_table;
        } else {
            k = kick_table;
        }

        for(k) |offset| {
            if(!self.isObstructed(&rotated, &offset)) {
                self.position.x += offset[0];
                self.position.y += offset[1];
                return true;
            }
        }
        return false;
    }

    pub fn canMoveRight(self: *Game) bool {
        const rel_x = self.tetrimino.lastNonEmptyColIdx();
        const abs_x = self.position.x + rel_x;
        const boundary_check = abs_x < COLS - 1;
        const abs_cmp_x: i32 = abs_x + 1;

        if(abs_cmp_x < COLS) {
            return self.cmpColumns(rel_x, abs_cmp_x) and boundary_check;
        }
        return boundary_check;
    }
};

pub fn main() u8 {
    ray.SetConfigFlags(ray.FLAG_MSAA_4X_HINT | ray.FLAG_VSYNC_HINT);

    ray.InitWindow(WIN_WIDTH, WIN_HEIGHT - 1, "tetris");
    defer ray.CloseWindow();

    ray.SetTargetFPS(60);

    const cells: [ROWS][COLS]ray.Color = undefined;

    var game = Game{
        .points = 0,
        .tetrimino = randomTetrimino(),
        .next = randomTetrimino(),
        .cells = cells,
        .position = .{ .x = 5, .y = -1 },
        .window_should_close = false,
        .next_display_tetrimino = undefined
    };

    game.next_display_tetrimino.assign(game.tetrimino);
    while(game.tetrimino == game.next) {
        game.next = randomTetrimino();
        game.next_display_tetrimino.assign(game.tetrimino);
    }

    while(!game.window_should_close) {
        game.gameBegin();
        game.gameRunning();
        game.gameOver();
    }

    return 0;
}
