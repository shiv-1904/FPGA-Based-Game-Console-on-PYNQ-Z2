// ============================================================
// score_ctrl.v
// Up-counter, max 99 (2 BCD digits).
// Resets to 0 when game_state goes to IDLE.
// bcd[7:4] = tens digit, bcd[3:0] = units digit
// ============================================================
module score_ctrl (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [1:0] game_state,
    input  wire       inc,           // score_pulse from pipe_ctrl
    output reg  [7:0] bcd            // packed BCD: tens|units
);
    localparam IDLE = 2'd0;

    reg [3:0] units, tens;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            units <= 0; tens <= 0; bcd <= 0;
        end else begin
            if (game_state == IDLE) begin
                units <= 0; tens <= 0;
            end else if (inc) begin
                if (units == 9) begin
                    units <= 0;
                    if (tens < 9) tens <= tens + 1;
                    // cap at 99
                end else
                    units <= units + 1;
            end
            bcd <= {tens, units};
        end
    end
endmodule