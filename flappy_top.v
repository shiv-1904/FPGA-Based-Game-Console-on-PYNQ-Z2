module flappy_top (
    input  wire clk_pixel,
    input  wire mmcm_locked,

    input  wire u_btn_flap,
    input  wire u_btn_rst,

    output wire [23:0] rgb,
    output wire hsync,
    output wire vsync,
    output wire de
);

    // ================= RESET =================
    reg [7:0] rst_pipe;
    wire rst_n = rst_pipe[7];
     wire [10:0] bg_scroll_x;
    always @(posedge clk_pixel or negedge mmcm_locked) begin
        if (!mmcm_locked)
            rst_pipe <= 8'h00;
        else
            rst_pipe <= {rst_pipe[6:0], 1'b1};
    end

    // ================= TICK =================
    // Fires once per video frame (~60 Hz) to drive game physics.
    //
    // 74.25 MHz pixel clock / 60 Hz = 1,237,500 cycles per tick.
    // NOTE: 1,237,500 requires 21 bits (2^21=2097152).
    //       The original [19:0] counter only reaches 1,048,575 (2^20-1)
    //       so it overflowed and the tick NEVER fired on real hardware.
    //       Fixed: counter widened to [20:0] (21 bits).
    //
    // TWO VALUES are provided:
    //   TICK_DIV = 1237500  <- USE THIS for real FPGA hardware (74.25 MHz)
    //   TICK_DIV = 1000     <- USE THIS for ModelSim/Vivado sim only
    //
    // To switch: comment/uncomment the two localparam lines below.
    //
    localparam TICK_DIV = 1237500;  // *** HARDWARE *** 74.25 MHz / 60 Hz
    // localparam TICK_DIV = 1000;  // *** SIMULATION ONLY ***

    reg [20:0] tick_cnt;   // 21 bits required: 1237500 < 2^21 (2097152)
    reg tick;

    always @(posedge clk_pixel or negedge rst_n) begin
        if (!rst_n) begin
            tick_cnt <= 0;
            tick <= 0;
        end else begin
            tick <= 0;
            if (tick_cnt == TICK_DIV - 1) begin
                tick_cnt <= 0;
                tick <= 1;
            end else begin
                tick_cnt <= tick_cnt + 1;
            end
        end
    end

    // ================= BUTTONS =================
    wire flap_pulse, rst_game_pulse;

    btn_sync_debounce u_btn_flap_db (
        .clk(clk_pixel),
        .rst_n(rst_n),
        .btn_in(~u_btn_flap),
        .btn_pulse(flap_pulse)
    );

    btn_sync_debounce u_btn_rst_db (
        .clk(clk_pixel),
        .rst_n(rst_n),
        .btn_in(~u_btn_rst),
        .btn_pulse(rst_game_pulse)
    );

    // ================= FSM =================
    wire [1:0] game_state;
    wire hit;

    game_fsm u_game_fsm (
        .clk(clk_pixel),
        .rst_n(rst_n),
        .flap(flap_pulse),
        .die(hit),
        .rst_game(rst_game_pulse),
        .state(game_state)
    );

    // ================= RNG =================
    wire [7:0] rng_val;

    rng u_rng (
        .clk(clk_pixel),
        .rst_n(rst_n),
        .game_state(game_state),
        .val(rng_val)
    );

    // ================= PIPE =================
    wire [10:0] pipe_x;
    wire [9:0] gap_y;
    wire score_pulse;

    pipe_ctrl u_pipe_ctrl (
        .clk(clk_pixel),
        .rst_n(rst_n),
        .tick(tick),
        .game_state(game_state),
        .gap_seed(rng_val),
        .pipe_x(pipe_x),
        .gap_y(gap_y),
        .score_pulse(score_pulse),
        .bg_scroll_x(bg_scroll_x)
    );

    // ================= BIRD =================
    wire [9:0] bird_y;

    bird_ctrl u_bird_ctrl (
        .clk(clk_pixel),
        .rst_n(rst_n),
        .tick(tick),
        .game_state(game_state),
        .flap(flap_pulse),
        .y_pos(bird_y)
    );

    // ================= COLLISION =================
    collision u_collision (
        .clk(clk_pixel),
        .rst_n(rst_n),
        .game_state(game_state),
        .bird_y(bird_y),
        .pipe_x(pipe_x),
        .gap_y(gap_y),
        .hit(hit)
    );

    // ================= SCORE =================
    wire [7:0] score_bcd;

    score_ctrl u_score_ctrl (
        .clk(clk_pixel),
        .rst_n(rst_n),
        .game_state(game_state),
        .inc(score_pulse),
        .bcd(score_bcd)
    );

    // ================= SYNC =================
    wire [10:0] pixel_x;
    wire [9:0] pixel_y;

    sync_gen u_sync_gen (
        .clk(clk_pixel),
        .rst_n(rst_n),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .hsync(hsync),
        .vsync(vsync),
        .de(de)
    );

    // ================= RENDER =================
    vga_renderer u_vga_renderer (
        .clk(clk_pixel),
        .rst_n(rst_n),
        .de(de),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .game_state(game_state),
        .bird_y(bird_y),
        .pipe_x(pipe_x),
        .gap_y(gap_y),
        .score_bcd(score_bcd),
        .bg_scroll_x(bg_scroll_x),
        .rgb(rgb)
    );

endmodule