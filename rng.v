// ============================================================
// rng.v
// 16-bit Galois LFSR â€” generates pseudo-random pipe gap positions
// Taps at bits 16,15,13,4 (maximal-length polynomial)
// Runs freely whenever game is in PLAYING state
// Output val[7:0] used as gap_seed by pipe_ctrl
// ============================================================
module rng (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [1:0] game_state,          // enable: high when PLAYING
    output wire [7:0] val          // lower 8 bits of LFSR
);
    reg [15:0] lfsr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr <= 16'hACE1;      // non-zero seed
        end else if (game_state == 2'd1) begin
            // Galois LFSR feedback: taps 16,15,13,4
            lfsr <= {1'b0, lfsr[15:1]} ^
                    (lfsr[0] ? 16'hB400 : 16'h0000);
        end
    end

    assign val = lfsr[7:0];
endmodule// ============================================================
