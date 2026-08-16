// ============================================================
// vga_renderer.v  -- FIXED
// ============================================================
// CHANGES vs original:
//  1. PIPE_W corrected from 40 to 80 to match pipe_ctrl / collision
//     (rendered pipe was visually half the logical collision width)
//  2. Score digit positions fixed: DIGIT_X0=610, DIGIT_X1=626
//     (original 575/590 placed both digits overlapping each other)
//  3. DEAD overlay now also renders "PRESS RST TO PLAY AGAIN" in
//     a second text row beneath "GAME ENDED" so the player knows
//     how to exit the dead state.
//  4. Additional BMP constants added: BMP_P BMP_L BMP_Y BMP_I
//     BMP_O BMP_W BMP_C BMP_K  (needed for the new restart line)
// ============================================================
module vga_renderer (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        de,
    input  wire [10:0] pixel_x,
    input  wire [9:0]  pixel_y,
    input  wire [1:0]  game_state,
    input  wire [9:0]  bird_y,
    input  wire [10:0] pipe_x,
    input  wire [9:0]  gap_y,
    input  wire [7:0]  score_bcd,
    input  wire [10:0] bg_scroll_x,
    output reg  [23:0] rgb
);

    localparam IDLE    = 2'd0;
    localparam PLAYING = 2'd1;
    localparam DEAD    = 2'd2;

    localparam BIRD_X   = 11'd200;
    localparam BIRD_R   = 11'd22;
    localparam PIPE_W   = 11'd80;   // FIX 1: was 40, now matches pipe_ctrl/collision
    localparam GAP_HALF = 11'd100;
    localparam GROUND_Y = 10'd660;

    localparam COL_SKY      = 24'h87EBCE;
    localparam COL_GROUND_1 = 24'h22228B;
    localparam COL_GROUND_2 = 24'h1A1A6D;
    localparam COL_DIRT_1   = 24'hC86BA8;
    localparam COL_DIRT_2   = 24'hA8588B;
    localparam COL_BIRD     = 24'hFF00D7;
    localparam COL_PIPE     = 24'h2D2D6A;
    localparam COL_PIPE_RIM = 24'h4444AA;
    localparam COL_WHITE    = 24'hFFFFFF;
    localparam COL_OVERLAY  = 24'h008000;

    // ---- object boundaries ----
    wire [10:0] bird_left    = BIRD_X - BIRD_R - 11'd16;
    wire [10:0] bird_right   = BIRD_X + BIRD_R + 11'd16;
    wire signed [10:0] bird_top_s = $signed({1'b0, bird_y}) - $signed(BIRD_R);
    wire signed [10:0] bird_bot_s = $signed({1'b0, bird_y}) + $signed(BIRD_R);
    wire [10:0] pipe_right   = pipe_x + PIPE_W;
    wire [10:0] top_pipe_bot = {1'b0, gap_y} - GAP_HALF;
    wire [10:0] bot_pipe_top = {1'b0, gap_y} + GAP_HALF;

    wire signed [10:0] px_s = $signed({1'b0, pixel_x});
    wire signed [10:0] py_s = $signed({1'b0, pixel_y});

    // ---- ground / dirt ----
    wire in_ground = (pixel_y >= GROUND_Y);
    wire in_dirt   = (pixel_y >= GROUND_Y) && (pixel_y < GROUND_Y + 10'd12);

    // ---- bird sprite ----
    wire [9:0] x_rel  = pixel_x - bird_left;
    wire [9:0] y_rel  = py_s - bird_top_s;
    wire [4:0] x_grid = x_rel / 3;
    wire [3:0] y_grid = y_rel / 3;

    reg sprite_bit;
    always @(*) begin
        sprite_bit = 1'b0;
        case (y_grid)
            4'd0:  if (x_grid == 9  || x_grid == 10) sprite_bit = 1'b1;
            4'd1:  if (x_grid == 10 || x_grid == 11) sprite_bit = 1'b1;
            4'd2:  if (x_grid == 11 || x_grid == 12) sprite_bit = 1'b1;
            4'd3:  if (x_grid >= 11 && x_grid <= 15) sprite_bit = 1'b1;
            4'd4:  if (x_grid == 12 || x_grid == 13 || x_grid == 15 || x_grid == 16) sprite_bit = 1'b1;
            4'd5:  if ((x_grid >= 12 && x_grid <= 21) || (x_grid >= 0 && x_grid <= 7)) sprite_bit = 1'b1;
            4'd6:  if ((x_grid >= 12 && x_grid <= 22) || (x_grid >= 3 && x_grid <= 8)) sprite_bit = 1'b1;
            4'd7:  if ((x_grid == 22 || x_grid == 23) || (x_grid >= 13 && x_grid <= 14) || (x_grid >= 5 && x_grid <= 9)) sprite_bit = 1'b1;
            4'd8:  if ((x_grid >= 6 && x_grid <= 10) || (x_grid >= 13 && x_grid <= 20)) sprite_bit = 1'b1;
            4'd9:  if (x_grid >= 7 && x_grid <= 14) sprite_bit = 1'b1;
            4'd10: if (x_grid >= 8 && x_grid <= 14) sprite_bit = 1'b1;
            4'd11: if (x_grid >= 8 && x_grid <= 13) sprite_bit = 1'b1;
            4'd12: if (x_grid >= 7 && x_grid <= 12) sprite_bit = 1'b1;
            4'd13: if (x_grid == 7 || x_grid == 10) sprite_bit = 1'b1;
            4'd14: if ((x_grid >= 5 && x_grid <= 7) || (x_grid == 9 || x_grid == 10)) sprite_bit = 1'b1;
            default: sprite_bit = 1'b0;
        endcase
    end

    wire in_bounds = (pixel_x >= bird_left) && (pixel_x <= bird_right) &&
                     (py_s >= bird_top_s)   && (py_s <= bird_bot_s);
    wire in_bird = in_bounds && sprite_bit;

    // ---- pipes ----
    wire in_pipe_col     = (pixel_x >= pipe_x) && (pixel_x <= pipe_right);
    wire in_top_pipe     = in_pipe_col && ({1'b0, pixel_y} < top_pipe_bot);
    wire in_bot_pipe     = in_pipe_col &&
                           ({1'b0, pixel_y} >= bot_pipe_top) &&
                           (pixel_y < GROUND_Y);
    wire in_pipe_rim_top = in_pipe_col &&
                           ({1'b0, pixel_y} >= top_pipe_bot - 11'd8) &&
                           ({1'b0, pixel_y} <  top_pipe_bot);
    wire in_pipe_rim_bot = in_pipe_col &&
                           ({1'b0, pixel_y} >= bot_pipe_top) &&
                           ({1'b0, pixel_y} <  bot_pipe_top + 11'd8);

    // ---- score digits ----
    // FIX 2: corrected digit X positions (was 575/590, overlapping).
    localparam DIGIT_X0 = 11'd610;
    localparam DIGIT_X1 = 11'd626;
    localparam DIGIT_Y  = 10'd20;
    localparam DIGIT_W  = 11'd10;
    localparam DIGIT_H  = 10'd14;

    wire in_tens_area  = (pixel_x >= DIGIT_X0) && (pixel_x < DIGIT_X0 + DIGIT_W) &&
                         (pixel_y >= DIGIT_Y)  && (pixel_y < DIGIT_Y  + DIGIT_H);
    wire in_units_area = (pixel_x >= DIGIT_X1) && (pixel_x < DIGIT_X1 + DIGIT_W) &&
                         (pixel_y >= DIGIT_Y)  && (pixel_y < DIGIT_Y  + DIGIT_H);

    wire [10:0] tens_x_off  = pixel_x - DIGIT_X0;
    wire [9:0]  tens_y_off  = pixel_y - DIGIT_Y;
    wire [10:0] units_x_off = pixel_x - DIGIT_X1;

    wire [2:0] tens_col  = tens_x_off[3:1];
    wire [2:0] tens_row  = tens_y_off[3:1];
    wire [2:0] units_col = units_x_off[3:1];
    wire [2:0] units_row = tens_y_off[3:1];

    reg [27:0] tens_bmp, units_bmp;

    always @(*) begin
        case (score_bcd[7:4])
            4'd0: tens_bmp = 28'b0110_1001_1001_1001_1001_1001_0110;
            4'd1: tens_bmp = 28'b0010_0110_0010_0010_0010_0010_0111;
            4'd2: tens_bmp = 28'b0110_1001_0001_0010_0100_1000_1111;
            4'd3: tens_bmp = 28'b0110_1001_0001_0110_0001_1001_0110;
            4'd4: tens_bmp = 28'b0001_0011_0101_1001_1111_0001_0001;
            4'd5: tens_bmp = 28'b1111_1000_1000_1110_0001_1001_0110;
            4'd6: tens_bmp = 28'b0110_1000_1000_1110_1001_1001_0110;
            4'd7: tens_bmp = 28'b1111_0001_0010_0010_0100_0100_0100;
            4'd8: tens_bmp = 28'b0110_1001_1001_0110_1001_1001_0110;
            4'd9: tens_bmp = 28'b0110_1001_1001_0111_0001_1001_0110;
            default: tens_bmp = 28'd0;
        endcase
    end

    always @(*) begin
        case (score_bcd[3:0])
            4'd0: units_bmp = 28'b0110_1001_1001_1001_1001_1001_0110;
            4'd1: units_bmp = 28'b0010_0110_0010_0010_0010_0010_0111;
            4'd2: units_bmp = 28'b0110_1001_0001_0010_0100_1000_1111;
            4'd3: units_bmp = 28'b0110_1001_0001_0110_0001_1001_0110;
            4'd4: units_bmp = 28'b0001_0011_0101_1001_1111_0001_0001;
            4'd5: units_bmp = 28'b1111_1000_1000_1110_0001_1001_0110;
            4'd6: units_bmp = 28'b0110_1000_1000_1110_1001_1001_0110;
            4'd7: units_bmp = 28'b1111_0001_0010_0010_0100_0100_0100;
            4'd8: units_bmp = 28'b0110_1001_1001_0110_1001_1001_0110;
            4'd9: units_bmp = 28'b0110_1001_1001_0111_0001_1001_0110;
            default: units_bmp = 28'd0;
        endcase
    end

    wire [4:0] tens_bit_idx  = ((6 - tens_row)  << 2) + (3 - tens_col);
    wire [4:0] units_bit_idx = ((6 - units_row) << 2) + (3 - units_col);

    wire tens_px        = in_tens_area  ? tens_bmp[tens_bit_idx]   : 1'b0;
    wire units_px       = in_units_area ? units_bmp[units_bit_idx] : 1'b0;
    wire in_score_pixel = tens_px | units_px;

    // =========================================================
    // ---- Overlay text bitmaps ----

    localparam BMP_SPC = 28'h0000000;
    localparam BMP_A   = 28'b0110_1001_1001_1111_1001_1001_1001;
    localparam BMP_C   = 28'b0110_1001_1000_1000_1000_1001_0110;  // NEW
    localparam BMP_D   = 28'b1110_1001_1001_1001_1001_1001_1110;
    localparam BMP_E   = 28'b1111_1000_1000_1110_1000_1000_1111;
    localparam BMP_G   = 28'b0110_1001_1000_1011_1001_1001_0110;
    localparam BMP_H   = 28'b1001_1001_1001_1111_1001_1001_1001;
    localparam BMP_I   = 28'b0111_0010_0010_0010_0010_0010_0111;  // NEW
    localparam BMP_K   = 28'b1001_1010_1100_1000_1100_1010_1001;  // NEW (approximate)
    localparam BMP_L   = 28'b1000_1000_1000_1000_1000_1000_1111;  // NEW
    localparam BMP_M   = 28'b1001_1111_0110_1001_1001_1001_1001;
    localparam BMP_N   = 28'b1001_1101_1011_1001_1001_1001_1001;
    localparam BMP_O   = 28'b0110_1001_1001_1001_1001_1001_0110;  // NEW (same as 0 digit)
    localparam BMP_P   = 28'b1110_1001_1001_1110_1000_1000_1000;  // NEW
    localparam BMP_R   = 28'b1110_1001_1001_1110_1100_1010_1001;
    localparam BMP_S   = 28'b0110_1001_1000_0110_0001_1001_0110;
    localparam BMP_T   = 28'b1111_0110_0110_0110_0110_0110_0110;
    localparam BMP_W   = 28'b1001_1001_1001_1001_1010_1110_0100;  // NEW (approximate)
    localparam BMP_Y   = 28'b1001_1001_0110_0110_0110_0110_0110;  // NEW

    // ---- "START THE GAME" (idle overlay line 1) ----
    // 14 chars, 8px each = 112px.  x_start = 640-56 = 584
    localparam ITXT_X  = 11'd584;
    localparam ITXT_PX = 11'd112;
    localparam TXT_Y   = 10'd313;
    localparam TXT_H   = 10'd14;

    // ---- "GAME ENDED" (dead overlay line 1) ----
    // 10 chars = 80px.  x_start = 640-40 = 600
    localparam DTXT_X  = 11'd600;
    localparam DTXT_PX = 11'd80;

    // ---- "PRESS RST TO PLAY AGAIN" (dead overlay line 2) ----  FIX 3
    // 22 chars = 176px.  x_start = 640-88 = 552
    localparam RTXT_X  = 11'd552;
    localparam RTXT_PX = 11'd176;
    localparam RTXT_Y  = 10'd333;   // 14px below line 1 (313+14+6 gap)

    // ---- In-region flags ----
    wire in_idle_txt = (pixel_x >= ITXT_X) && (pixel_x < ITXT_X + ITXT_PX) &&
                       (pixel_y >= TXT_Y)  && (pixel_y <  TXT_Y  + TXT_H);
    wire in_dead_txt = (pixel_x >= DTXT_X) && (pixel_x < DTXT_X + DTXT_PX) &&
                       (pixel_y >= TXT_Y)  && (pixel_y <  TXT_Y  + TXT_H);
    wire in_rst_txt  = (pixel_x >= RTXT_X) && (pixel_x < RTXT_X + RTXT_PX) &&
                       (pixel_y >= RTXT_Y) && (pixel_y <  RTXT_Y + TXT_H);

    // ---- Pixel offsets ----
    wire [10:0] itxt_px_off = pixel_x - ITXT_X;
    wire [9:0]  itxt_py_off = pixel_y - TXT_Y;
    wire [10:0] dtxt_px_off = pixel_x - DTXT_X;
    wire [9:0]  dtxt_py_off = pixel_y - TXT_Y;
    wire [10:0] rtxt_px_off = pixel_x - RTXT_X;
    wire [9:0]  rtxt_py_off = pixel_y - RTXT_Y;

    // ---- Character / column / row indices ----
    wire [3:0] itxt_char = itxt_px_off[6:3];
    wire [2:0] itxt_col  = itxt_px_off[2:1];
    wire [2:0] itxt_row  = itxt_py_off[3:1];

    wire [3:0] dtxt_char = dtxt_px_off[6:3];
    wire [2:0] dtxt_col  = dtxt_px_off[2:1];
    wire [2:0] dtxt_row  = dtxt_py_off[3:1];

    wire [4:0] rtxt_char = rtxt_px_off[7:3];   // 5-bit: up to 31 chars
    wire [2:0] rtxt_col  = rtxt_px_off[2:1];
    wire [2:0] rtxt_row  = rtxt_py_off[3:1];

    // ---- Bit indices ----
    wire [4:0] itxt_bit = ((6 - itxt_row) << 2) + (3 - itxt_col);
    wire [4:0] dtxt_bit = ((6 - dtxt_row) << 2) + (3 - dtxt_col);
    wire [4:0] rtxt_bit = ((6 - rtxt_row) << 2) + (3 - rtxt_col);

    // ---- Bitmap selection ----
    // "START THE GAME": S T A R T _ T H E _ G A M E
    reg [27:0] itxt_bmp;
    always @(*) begin
        case (itxt_char)
            4'd0:    itxt_bmp = BMP_S;
            4'd1:    itxt_bmp = BMP_T;
            4'd2:    itxt_bmp = BMP_A;
            4'd3:    itxt_bmp = BMP_R;
            4'd4:    itxt_bmp = BMP_T;
            4'd5:    itxt_bmp = BMP_SPC;
            4'd6:    itxt_bmp = BMP_T;
            4'd7:    itxt_bmp = BMP_H;
            4'd8:    itxt_bmp = BMP_E;
            4'd9:    itxt_bmp = BMP_SPC;
            4'd10:   itxt_bmp = BMP_G;
            4'd11:   itxt_bmp = BMP_A;
            4'd12:   itxt_bmp = BMP_M;
            4'd13:   itxt_bmp = BMP_E;
            default: itxt_bmp = BMP_SPC;
        endcase
    end

    // "GAME ENDED": G A M E _ E N D E D
    reg [27:0] dtxt_bmp;
    always @(*) begin
        case (dtxt_char)
            4'd0:    dtxt_bmp = BMP_G;
            4'd1:    dtxt_bmp = BMP_A;
            4'd2:    dtxt_bmp = BMP_M;
            4'd3:    dtxt_bmp = BMP_E;
            4'd4:    dtxt_bmp = BMP_SPC;
            4'd5:    dtxt_bmp = BMP_E;
            4'd6:    dtxt_bmp = BMP_N;
            4'd7:    dtxt_bmp = BMP_D;
            4'd8:    dtxt_bmp = BMP_E;
            4'd9:    dtxt_bmp = BMP_D;
            default: dtxt_bmp = BMP_SPC;
        endcase
    end

    // FIX 3: "PRESS RST TO PLAY AGAIN"
    //  P R E S S _ R S T _ T O _ P L A Y _ A G A I N
    //  0 1 2 3 4  5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21
    reg [27:0] rtxt_bmp;
    always @(*) begin
        case (rtxt_char)
            5'd0:    rtxt_bmp = BMP_P;
            5'd1:    rtxt_bmp = BMP_R;
            5'd2:    rtxt_bmp = BMP_E;
            5'd3:    rtxt_bmp = BMP_S;
            5'd4:    rtxt_bmp = BMP_S;
            5'd5:    rtxt_bmp = BMP_SPC;
            5'd6:    rtxt_bmp = BMP_R;
            5'd7:    rtxt_bmp = BMP_S;
            5'd8:    rtxt_bmp = BMP_T;
            5'd9:    rtxt_bmp = BMP_SPC;
            5'd10:   rtxt_bmp = BMP_T;
            5'd11:   rtxt_bmp = BMP_O;
            5'd12:   rtxt_bmp = BMP_SPC;
            5'd13:   rtxt_bmp = BMP_P;
            5'd14:   rtxt_bmp = BMP_L;
            5'd15:   rtxt_bmp = BMP_A;
            5'd16:   rtxt_bmp = BMP_Y;
            5'd17:   rtxt_bmp = BMP_SPC;
            5'd18:   rtxt_bmp = BMP_A;
            5'd19:   rtxt_bmp = BMP_G;
            5'd20:   rtxt_bmp = BMP_A;
            5'd21:   rtxt_bmp = BMP_I;
            5'd22:   rtxt_bmp = BMP_N;   // 22 chars total; RTXT_PX covers exactly 22*8=176
            default: rtxt_bmp = BMP_SPC;
        endcase
    end

    // ---- Final pixel wires ----
    wire idle_txt_px = in_idle_txt ? itxt_bmp[itxt_bit] : 1'b0;
    wire dead_txt_px = in_dead_txt ? dtxt_bmp[dtxt_bit] : 1'b0;
    wire rst_txt_px  = in_rst_txt  ? rtxt_bmp[rtxt_bit] : 1'b0;

    // ---- Scrolling background stripes ----
    wire [10:0] scrolled_x  = pixel_x + bg_scroll_x;
    wire [11:0] diag_coord  = {1'b0, scrolled_x} + {2'b00, pixel_y};
    wire        ground_stripe = diag_coord[4];
    wire        dirt_stripe   = scrolled_x[3];

    // ---- Combinational colour mux ----
    reg [23:0] rgb_comb;

    always @(*) begin
        rgb_comb = COL_SKY;

        if (in_ground) rgb_comb = ground_stripe ? COL_GROUND_1 : COL_GROUND_2;
        if (in_dirt)   rgb_comb = dirt_stripe   ? COL_DIRT_1   : COL_DIRT_2;

        if (in_top_pipe)     rgb_comb = COL_PIPE;
        if (in_bot_pipe)     rgb_comb = COL_PIPE;
        if (in_pipe_rim_top) rgb_comb = COL_PIPE_RIM;
        if (in_pipe_rim_bot) rgb_comb = COL_PIPE_RIM;

        if (game_state != IDLE) begin
            if (in_bird) rgb_comb = COL_BIRD;
        end

        if ((game_state != IDLE) && in_score_pixel)
            rgb_comb = COL_WHITE;

        if (game_state == IDLE) begin
            if ((pixel_y >= 10'd300) && (pixel_y < 10'd340) &&
                (pixel_x >= 11'd440) && (pixel_x < 11'd840))
                rgb_comb = COL_OVERLAY;
            if (idle_txt_px) rgb_comb = COL_WHITE;
        end

        if (game_state == DEAD) begin
            // FIX 3: taller overlay to accommodate the second text line
            if ((pixel_y >= 10'd300) && (pixel_y < 10'd360) &&
                (pixel_x >= 11'd440) && (pixel_x < 11'd840))
                rgb_comb = 24'h0000FF;
            if (dead_txt_px) rgb_comb = COL_WHITE;
            if (rst_txt_px)  rgb_comb = COL_WHITE;
        end
    end

    // Register output and gate with DE
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rgb <= 24'h000000;
        else
            rgb <= de ? rgb_comb : 24'h000000;
    end

endmodule