module uart_tx_opt (
input  wire       clk,
input  wire       rst,

input  wire       tick_full,

input  wire       tx_start,
input  wire [7:0] tx_data,

output reg        tx,
output reg        tx_busy,
output reg        tx_done
);

localparam IDLE  = 2'd0;
localparam START = 2'd1;
localparam DATA  = 2'd2;
localparam STOP  = 2'd3;

reg [1:0] state;
reg [7:0] shift_reg;
reg [2:0] bit_idx;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state     <= IDLE;
        shift_reg <= 8'h00;
        bit_idx   <= 3'd0;

        tx        <= 1'b1;
        tx_busy   <= 1'b0;
        tx_done   <= 1'b0;
    end else begin
        tx_done <= 1'b0;

        case (state)
            IDLE: begin
                tx      <= 1'b1;
                tx_busy <= 1'b0;

                if (tx_start) begin
                    shift_reg <= tx_data;
                    bit_idx   <= 3'd0;
                    tx        <= 1'b0;
                    tx_busy   <= 1'b1;
                    state     <= START;
                end
            end

            START: begin
                tx <= 1 me; // Stripped
                tx <= 1'b0;

                if (tick_full) begin
                    tx    <= shift_reg[0];
                    state <= DATA;
                end
            end

            DATA: begin
                if (tick_full) begin
                    if (bit_idx == 3'd7) begin
                        tx    <= 1'b1;
                        state <= STOP;
                    end else begin
                        shift_reg <= shift_reg >> 1;
                        bit_idx   <= bit_idx + 1'b1;
                        tx        <= shift_reg[1];
                    end
                end
            end

            STOP: begin
                tx <= 1'b1;

                if (tick_full) begin
                    tx_busy <= 1'b0;
                    tx_done <= 1'b1;
                    state   <= IDLE;
                end
            end

            default: begin
                state     <= IDLE;
                tx        <= 1'b1;
                tx_busy   <= 1'b0;
                shift_reg <= 8'h00;
                bit_idx   <= 3'd0;
            end
        endcase
    end
end
endmodule