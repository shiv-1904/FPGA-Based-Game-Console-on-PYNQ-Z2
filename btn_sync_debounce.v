// ============================================================
// btn_sync_debounce.v
// Two-stage synchroniser + debounce filter + rising-edge detector.
// At 74.25 MHz, 2^20 cycles â‰ˆ 14.1 ms debounce window.
// btn_pulse is HIGH for exactly ONE clock cycle on clean press.
// ============================================================
module btn_sync_debounce (
    input  wire clk,
    input  wire rst_n,
    input  wire btn_in,
    output reg  btn_pulse
);
    reg [1:0] sync_ff;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) sync_ff <= 2'b00;
        else        sync_ff <= {sync_ff[0], btn_in};

    reg [19:0] cnt;
    reg        stable, prev;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt       <= 0; stable <= 0;
            prev      <= 0; btn_pulse <= 0;
        end else begin
            btn_pulse <= 0;
            if (sync_ff[1] != stable) begin
                if (cnt == 20'hFFFFF) begin
                    stable <= sync_ff[1];
                    cnt    <= 0;
                end else cnt <= cnt + 1;
            end else cnt <= 0;

            prev <= stable;
            if (stable && !prev) btn_pulse <= 1;
        end
    end
endmodule// ============================================================
