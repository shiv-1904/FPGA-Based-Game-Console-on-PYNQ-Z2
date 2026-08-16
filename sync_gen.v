// ============================================================
// sync_gen.v  -- FIXED
// 1280x720 @ 60 Hz  |  Pixel clock: 74.25 MHz
//
// FIX 1: hsync, vsync, de are now REGISTERED (flip-flop outputs).
//        Previously they were pure combinational wires driven by
//        pixel_x / pixel_y counters.  The combinational glitch path
//        was: counter toggle â†’ long combinational decode â†’ async
//        change on hsync/vsync â†’ HDMI receiver loses lock every
//        frame (~16 ms).  Registering them adds exactly 1-pixel
//        latency (invisible) but makes the sync edges glitch-free.
//
// FIX 2: pixel_y width promoted to 10 bits (was already 10-bit
//        reg but the wrap comparison used 10'd0 â€” kept consistent).
//
// Timing (CEA-861, 720p60):
//   H_ACTIVE=1280  H_FP=110  H_SYNC=40  H_BP=220  H_TOTAL=1650
//   V_ACTIVE=720   V_FP=5    V_SYNC=5   V_BP=20   V_TOTAL=750
//   Pixel clock = 74.25 MHz
//   Sync polarity: both ACTIVE HIGH (720p standard)
// ============================================================
module sync_gen (
    input  wire        clk,      // 74.25 MHz pixel clock
    input  wire        rst_n,    // synchronous-friendly active-low reset
    output reg  [10:0] pixel_x,  // 0 .. H_TOTAL-1 (0..1649)
    output reg  [9:0]  pixel_y,  // 0 .. V_TOTAL-1 (0..749)
    output reg         hsync,    // registered â€” glitch-free
    output reg         vsync,    // registered â€” glitch-free
    output reg         de        // registered â€” glitch-free
);
    // ---- timing parameters ----
    localparam H_ACTIVE = 11'd1280;
    localparam H_FP     = 11'd110;
    localparam H_SYNC   = 11'd40;
    localparam H_BP     = 11'd220;
    localparam H_TOTAL  = 11'd1650;   // 1280+110+40+220

    localparam V_ACTIVE = 10'd720;
    localparam V_FP     = 10'd5;
    localparam V_SYNC   = 10'd5;
    localparam V_BP     = 10'd20;
    localparam V_TOTAL  = 10'd750;    // 720+5+5+20

    // Sync/DE window start/end (pre-computed to avoid wide
    // combinational trees on timing-critical paths)
    localparam H_SYNC_START = H_ACTIVE + H_FP;          // 1390
    localparam H_SYNC_END   = H_ACTIVE + H_FP + H_SYNC; // 1430
    localparam V_SYNC_START = V_ACTIVE + V_FP;           // 725
    localparam V_SYNC_END   = V_ACTIVE + V_FP + V_SYNC;  // 730

    // ---- pixel counters ----
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_x <= 11'd0;
            pixel_y <= 10'd0;
        end else begin
            if (pixel_x == H_TOTAL - 1) begin
                pixel_x <= 11'd0;
                pixel_y <= (pixel_y == V_TOTAL - 1) ? 10'd0 : pixel_y + 1'b1;
            end else begin
                pixel_x <= pixel_x + 1'b1;
            end
        end
    end

    // ---- registered sync / DE outputs (KEY FIX) ----
    // Use next-cycle values so the register sees the decision
    // made from the CURRENT counter state â†’ output transitions
    // are synchronous with the pixel clock edge, no glitches.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hsync <= 1'b0;
            vsync <= 1'b0;
            de    <= 1'b0;
        end else begin
            hsync <= (pixel_x >= H_SYNC_START) && (pixel_x < H_SYNC_END);
            vsync <= (pixel_y >= V_SYNC_START) && (pixel_y < V_SYNC_END);
            de    <= (pixel_x < H_ACTIVE)       && (pixel_y < V_ACTIVE);
        end
    end

endmodule
