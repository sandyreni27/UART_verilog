// ============================================================================
// FILE: uart_tx_opt.v
// Optimized UART Transmitter
// Frame: 1 Start Bit + 8 Data Bits + 1 Stop Bit
// Data format: LSB First
// ============================================================================

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

    // ------------------------------------------------------------------------
    // UART States
    // ------------------------------------------------------------------------
    localparam IDLE  = 2'd0;
    localparam START = 2'd1;
    localparam DATA  = 2'd2;
    localparam STOP  = 2'd3;

    reg [1:0] state;
    reg [7:0] shift_reg;
    reg [2:0] bit_idx;

    // ------------------------------------------------------------------------
    // UART Transmitter
    // ------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin

        if (rst) begin
            state     <= IDLE;
            shift_reg <= 8'h00;
            bit_idx   <= 3'd0;

            tx        <= 1'b1;
            tx_busy   <= 1'b0;
            tx_done   <= 1'b0;
        end

        else begin

            // tx_done is a one-clock pulse
            tx_done <= 1'b0;

            case (state)

                // ------------------------------------------------------------
                // IDLE
                // ------------------------------------------------------------
                IDLE: begin

                    tx      <= 1'b1;
                    tx_busy <= 1'b0;

                    if (tx_start) begin

                        // Load data
                        shift_reg <= tx_data;

                        // Start with bit 0
                        bit_idx <= 3'd0;

                        // Send START bit
                        tx <= 1'b0;

                        tx_busy <= 1'b1;

                        state <= START;
                    end
                end

                // ------------------------------------------------------------
                // START BIT
                // ------------------------------------------------------------
                START: begin

                    tx <= 1'b0;

                    if (tick_full) begin

                        // First data bit
                        tx <= shift_reg[0];

                        state <= DATA;
                    end
                end

                // ------------------------------------------------------------
                // DATA BITS
                // ------------------------------------------------------------
                DATA: begin

                    if (tick_full) begin

                        if (bit_idx == 3'd7) begin

                            // All 8 data bits transmitted
                            // Move to STOP bit
                            tx <= 1'b1;

                            state <= STOP;
                        end

                        else begin

                            bit_idx <= bit_idx + 1'b1;

                            // Shift data right
                            shift_reg <= shift_reg >> 1;

                            // Next data bit
                            tx <= shift_reg[1];
                        end
                    end
                end

                // ------------------------------------------------------------
                // STOP BIT
                // ------------------------------------------------------------
                STOP: begin

                    tx <= 1'b1;

                    if (tick_full) begin

                        tx_busy <= 1'b0;
                        tx_done <= 1'b1;

                        state <= IDLE;
                    end
                end

                // ------------------------------------------------------------
                // DEFAULT
                // ------------------------------------------------------------
                default: begin

                    state     <= IDLE;
                    tx        <= 1'b1;
                    tx_busy   <= 1'b0;
                    tx_done   <= 1'b0;

                    shift_reg <= 8'h00;
                    bit_idx   <= 3'd0;
                end

            endcase
        end
    end

endmodule