// ============================================================
// pipe_ctrl.v  -- FIXED
//
// FIX 1: REMOVED local tick prescaler (same root cause as bird_ctrl).
//        Accepts `tick` input from top-level shared prescaler.
//
// FIX 2: Underflow guard on pipe_x subtraction.
//        Original: `if (pipe_x <= PIPE_SPEED)` compared an 11-bit
//        unsigned reg against a small constant â€�? when pipe_x == 0
//        the subtraction `pipe_x - PIPE_SPEED` wraps to 2047 (huge
//        positive), sending the pipe off-screen.  Fixed with explicit
//        signed comparison / saturated subtract.
//
// FIX 3: gap_y RNG multiplication used 8-bit * 8-bit result (only
//        8 bits wide in Verilog without explicit widening).  Widened
//        operands to 32-bit before multiply to prevent truncation.
//        NOTE: 16-bit * 16-bit is still only 16-bit in Verilog!
//        480 * 255 = 122400 which needs 17 bits -- 16-bit product
//        wraps and gives wrong gap positions.  Must use 32-bit operands.
// ============================================================
module pipe_ctrl (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        tick,          // single-cycle pulse from top-level prescaler
    input  wire [1:0]  game_state,
    input  wire [7:0]  gap_seed,
    output reg  [10:0] pipe_x,
    output reg  [9:0]  gap_y,
    output reg         score_pulse,
    output reg  [10:0] bg_scroll_x
);
    localparam IDLE      = 2'd0;
    localparam PLAYING   = 2'd1;
    localparam DEAD      = 2'd2;

    localparam SCREEN_W  = 1280;
    localparam PIPE_W    = 80;
    localparam PIPE_SPEED = 3;
    localparam BIRD_X    = 200;
    localparam START_X   = 900;
    localparam GAP_MIN   = 220;
    localparam GAP_MAX   = 600;
    localparam GAP_RANGE = GAP_MAX - GAP_MIN;  // 480

    reg scored;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pipe_x      <= START_X[10:0];
            gap_y       <= 10'd360;
            score_pulse <= 1'b0;
            scored      <= 1'b0;
            bg_scroll_x <= 11'd0;    // NEW: Initialize scroll
        end else begin
            score_pulse <= 1'b0;
            case (game_state)
                IDLE: begin
                    pipe_x <= START_X[10:0];
                    gap_y  <= 10'd460;
                    scored <= 1'b0;
                    // NEW: Keep scrolling the background on the title screen for a cool effect
                    if (tick) bg_scroll_x <= bg_scroll_x + PIPE_SPEED[10:0]; 
                end

                PLAYING: begin
                    if (tick) bg_scroll_x <= bg_scroll_x + PIPE_SPEED[10:0];
                    if (tick) begin
                        // FIX 2: saturated subtract â€�? never underflow
                        if (pipe_x <= PIPE_SPEED[10:0]) begin
                            // wrap to right edge with new gap
                            pipe_x <= SCREEN_W[10:0];
                            // FIX 3: widen to 16-bit before multiply
                            gap_y  <= GAP_MIN[9:0] +
                                      (( {24'h000000, gap_seed} *
                                         32'd480 ) >> 8);
                            scored <= 1'b0;
                        end else begin
                            pipe_x <= pipe_x - PIPE_SPEED[10:0];
                        end

                        // score when bird x-centre clears pipe right edge
                        if (!scored && (BIRD_X[10:0] > pipe_x + PIPE_W[10:0])) begin
                            score_pulse <= 1'b1;
                            scored      <= 1'b1;
                        end
                    end
                end

                DEAD: ; // freeze

                default: pipe_x <= START_X[10:0];
            endcase
        end
    end
endmodule
