// ============================================================
// collision.v  
// ============================================================
module collision (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [1:0]  game_state,
    input  wire [9:0]  bird_y,
    input  wire [10:0] pipe_x,
    input  wire [9:0]  gap_y,
    output reg         hit
);
    localparam IDLE     = 2'd0;
    localparam PLAYING  = 2'd1;
    localparam BIRD_X   = 200;
    localparam BIRD_R   = 20;
    localparam PIPE_W   = 80;
    localparam GAP_HALF = 100;
    localparam SCREEN_H = 720;

    localparam GROUND_Y = 660;  // must match vga_renderer GROUND_Y

    wire [10:0] bird_left  = BIRD_X - BIRD_R;
    wire [10:0] bird_right = BIRD_X + BIRD_R;

    wire signed [10:0] bird_top_s = $signed({1'b0, bird_y}) - BIRD_R;
    wire signed [10:0] bird_bot_s = $signed({1'b0, bird_y}) + BIRD_R;
    wire [10:0] bird_top = (bird_top_s < 0) ? 0 : bird_top_s[9:0];
    wire [10:0] bird_bot  = bird_bot_s[9:0];

    wire [10:0] pipe_right = pipe_x + PIPE_W;

    // Horizontal overlap with pipe column
    wire h_overlap = (bird_right >= pipe_x) && (bird_left <= pipe_right);

    // Vertical overlap with pipe bodies (outside the gap)
    wire pipe_collision = h_overlap &&
                          ((bird_top <= gap_y - GAP_HALF) || (bird_bot >= gap_y + GAP_HALF));

    // Ground and ceiling hits
    wire ground_hit  = (bird_y >= GROUND_Y - BIRD_R);
    wire ceiling_hit = (bird_top_s <= 0);

    wire collision_now = pipe_collision || ground_hit || ceiling_hit;

    reg prev_collision;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hit            <= 0;
            prev_collision <= 0;
        end else begin
            hit <= 0;
            if (game_state == PLAYING) begin
                if (collision_now && !prev_collision)
                    hit <= 1;
                prev_collision <= collision_now;
            end else begin
                prev_collision <= 0;
            end
        end
    end
endmodule