module bird_ctrl (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        tick,
    input  wire [1:0]  game_state,
    input  wire        flap,
    output reg  [9:0]  y_pos
);

    localparam IDLE    = 2'd0;
    localparam PLAYING = 2'd1;
    localparam DEAD    = 2'd2;

    localparam SCREEN_H      = 720;
    localparam BIRD_RADIUS   = 20;
    localparam START_Y       = 200;
    localparam GRAVITY       = 1;
    localparam FLAP_STRENGTH = 10;

    localparam GROUND_Y      = 660;   // visual ground line (matches renderer + collision)
    localparam GROUND_STOP   = GROUND_Y - BIRD_RADIUS - 1;  // 639

 
    reg signed [5:0]  vel;
    reg signed [10:0] next_y;
    reg [1:0]         prev_state;
 
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            y_pos      <= START_Y;
            vel        <= 0;
            prev_state <= IDLE;
        end else begin
            prev_state <= game_state;
            case (game_state)
 
                IDLE: begin
                    y_pos <= START_Y;
                    vel   <= 0;
                end
 
                PLAYING: begin
                    if (prev_state == IDLE || flap)
                        vel <= -FLAP_STRENGTH;
                    else if (tick)
                        vel <= (vel < 15) ? vel + GRAVITY : vel;
 
                    if (tick) begin
                        next_y = $signed({1'b0, y_pos}) + vel;
                        if (next_y < BIRD_RADIUS)
                            y_pos <= BIRD_RADIUS;
                        else if (next_y > GROUND_STOP)
                            y_pos <= GROUND_STOP;
                        else
                            y_pos <= next_y[9:0];
                    end
                end
 
                DEAD: begin
                    // Bird falls and stops exactly on the ground surface
                    if (tick && (y_pos < GROUND_STOP))
                        y_pos <= y_pos + 2;
                    else if (y_pos >= GROUND_STOP)
                        y_pos <= GROUND_STOP;
                end
 
            endcase
        end
    end
endmodule