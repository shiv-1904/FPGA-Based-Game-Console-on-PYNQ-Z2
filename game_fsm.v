// ============================================================
// game_fsm.v
// Three-state FSM: IDLE â†’ PLAYING â†’ DEAD
// IDLE    : waiting for first flap, show title screen
// PLAYING : game active, physics running
// DEAD    : collision occurred, show game-over, wait for reset
// ============================================================
module game_fsm (
    input  wire       clk,
    input  wire       rst_n,       // active-low, from MMCM locked
    input  wire       flap,        // single-cycle pulse from debouncer
    input  wire       die,         // single-cycle pulse from collision
    input  wire       rst_game,    // single-cycle pulse from btn_rst
    output reg  [1:0] state        // 00=IDLE 01=PLAYING 10=DEAD
);
    localparam IDLE    = 2'd0;
    localparam PLAYING = 2'd1;
    localparam DEAD    = 2'd2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            case (state)
                IDLE:    if (flap)     state <= PLAYING;
                PLAYING: if (die)      state <= DEAD;
                DEAD:    if (rst_game) state <= IDLE;
                default:               state <= IDLE;
            endcase
        end
    end
endmodule