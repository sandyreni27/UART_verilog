`timescale 1ns / 1ps

// ============================================================================
// LOW-POWER / LOW-AREA UART TRANSCEIVER
// ============================================================================
// UART FORMAT : 8N1
//              1 Start Bit
//              8 Data Bits
//              No Parity
//              1 Stop Bit
//
// DATA : LSB FIRST
//
// MODULES:
// 1. baud_gen_opt
// 2. uart_tx_opt
// 3. uart_rx_opt
// 4. uart_opt
// 5. uart_opt_tb
// ============================================================================



// ============================================================================
// MODULE 1 : SHARED BAUD RATE GENERATOR
// ============================================================================

module baud_gen_opt #(
    parameter integer CLK_FREQ  = 50_000_000,
    parameter integer BAUD_RATE = 9600
)(
    input  wire clk,
    input  wire rst,

    output reg tick_full
);

    // Number of clock cycles per UART bit
    localparam integer DIVISOR =
        CLK_FREQ / BAUD_RATE;

    // Counter width
    localparam integer CNT_WIDTH =
        (DIVISOR <= 1) ? 1 : $clog2(DIVISOR);

    reg [CNT_WIDTH-1:0] count;


    always @(posedge clk or posedge rst) begin

        if (rst) begin

            count     <= {CNT_WIDTH{1'b0}};
            tick_full <= 1'b0;

        end

        else begin

            // Default: no tick
            tick_full <= 1'b0;

            if (count == DIVISOR - 1) begin

                count     <= {CNT_WIDTH{1'b0}};
                tick_full <= 1'b1;

            end

            else begin

                count <= count + 1'b1;

            end

        end

    end

endmodule



// ============================================================================
// MODULE 2 : UART TRANSMITTER
// ============================================================================
// Frame:
//
//       START   D0 D1 D2 D3 D4 D5 D6 D7   STOP
//         0      LSB ---------------- MSB   1
//
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

        end

        else begin

            // tx_done is a one-clock pulse
            tx_done <= 1'b0;

            case (state)


                // ============================================================
                // IDLE
                // ============================================================

                IDLE: begin

                    // UART idle state is HIGH
                    tx      <= 1'b1;
                    tx_busy <= 1'b0;

                    if (tx_start) begin

                        // Store data
                        shift_reg <= tx_data;

                        // Start with bit 0
                        bit_idx <= 3'd0;

                        // START BIT
                        tx <= 1'b0;

                        tx_busy <= 1'b1;

                        state <= START;

                    end

                end


                // ============================================================
                // START BIT
                // ============================================================

                START: begin

                    tx <= 1'b0;

                    if (tick_full) begin

                        // First data bit
                        tx <= shift_reg[0];

                        state <= DATA;

                    end

                end


                // ============================================================
                // DATA BITS
                // ============================================================

                DATA: begin

                    if (tick_full) begin

                        if (bit_idx == 3'd7) begin

                            // D7 was just transmitted.
                            // Move to STOP.

                            tx <= 1'b1;

                            state <= STOP;

                        end

                        else begin

                            // Shift data
                            shift_reg <= shift_reg >> 1;

                            // Next bit
                            bit_idx <= bit_idx + 1'b1;

                            // Because shift_reg has not changed yet,
                            // bit [1] is the next bit.
                            tx <= shift_reg[1];

                        end

                    end

                end


                // ============================================================
                // STOP BIT
                // ============================================================

                STOP: begin

                    tx <= 1'b1;

                    if (tick_full) begin

                        tx_busy <= 1'b0;

                        tx_done <= 1'b1;

                        state <= IDLE;

                    end

                end


                // ============================================================
                // DEFAULT
                // ============================================================

                default: begin

                    state     <= IDLE;
                    shift_reg <= 8'h00;
                    bit_idx   <= 3'd0;

                    tx        <= 1'b1;
                    tx_busy   <= 1'b0;
                    tx_done   <= 1'b0;

                end

            endcase

        end

    end

endmodule



// ============================================================================
// MODULE 3 : UART RECEIVER
// ============================================================================
// Uses:
//
// 1. Two-stage synchronizer
// 2. Start-bit detection
// 3. Half-bit validation
// 4. Center sampling of each data bit
// 5. Stop-bit validation
//
// ============================================================================

module uart_rx_opt #(
    parameter integer CLK_FREQ  = 50_000_000,
    parameter integer BAUD_RATE = 9600
)(
    input wire clk,
    input wire rst,

    input wire rx,

    output reg [7:0] rx_data,
    output reg       rx_done,
    output reg       rx_busy
);

    // ------------------------------------------------------------------------
    // Baud timing
    // ------------------------------------------------------------------------

    localparam integer DIVISOR =
        CLK_FREQ / BAUD_RATE;

    localparam integer HALF_DIV =
        DIVISOR / 2;

    localparam integer CNT_WIDTH =
        (DIVISOR <= 1) ? 1 : $clog2(DIVISOR);


    // ------------------------------------------------------------------------
    // States
    // ------------------------------------------------------------------------

    localparam IDLE  = 2'd0;
    localparam START = 2'd1;
    localparam DATA  = 2'd2;
    localparam STOP  = 2'd3;


    reg [1:0] state;

    reg [7:0] shift_reg;

    reg [2:0] bit_index;

    reg [CNT_WIDTH-1:0] rx_count;


    // ------------------------------------------------------------------------
    // TWO-STAGE SYNCHRONIZER
    // ------------------------------------------------------------------------

    reg rx_sync_1;
    reg rx_sync_2;


    always @(posedge clk or posedge rst) begin

        if (rst) begin

            rx_sync_1 <= 1'b1;
            rx_sync_2 <= 1'b1;

        end

        else begin

            rx_sync_1 <= rx;
            rx_sync_2 <= rx_sync_1;

        end

    end


    // ------------------------------------------------------------------------
    // RECEIVER FSM
    // ------------------------------------------------------------------------

    always @(posedge clk or posedge rst) begin

        if (rst) begin

            state     <= IDLE;

            shift_reg <= 8'h00;

            bit_index <= 3'd0;

            rx_count  <= {CNT_WIDTH{1'b0}};

            rx_data   <= 8'h00;

            rx_done   <= 1'b0;

            rx_busy   <= 1'b0;

        end

        else begin

            // One-clock pulse
            rx_done <= 1'b0;


            case (state)


                // ============================================================
                // IDLE
                // ============================================================

                IDLE: begin

                    rx_busy  <= 1'b0;

                    rx_count <= {CNT_WIDTH{1'b0}};


                    // START BIT detected
                    if (rx_sync_2 == 1'b0) begin

                        rx_busy  <= 1'b1;

                        rx_count <= {CNT_WIDTH{1'b0}};

                        state <= START;

                    end

                end


                // ============================================================
                // START BIT VALIDATION
                // ============================================================

                START: begin

                    rx_busy <= 1'b1;


                    // Wait half a UART bit
                    if (rx_count == HALF_DIV - 1) begin

                        rx_count <= {CNT_WIDTH{1'b0}};


                        // Check that START is still LOW
                        if (rx_sync_2 == 1'b0) begin

                            bit_index <= 3'd0;

                            state <= DATA;

                        end

                        else begin

                            // False start
                            rx_busy <= 1'b0;

                            state <= IDLE;

                        end

                    end

                    else begin

                        rx_count <= rx_count + 1'b1;

                    end

                end


                // ============================================================
                // DATA BITS
                // ============================================================

                DATA: begin

                    rx_busy <= 1'b1;


                    // Wait one complete bit period
                    if (rx_count == DIVISOR - 1) begin

                        rx_count <= {CNT_WIDTH{1'b0}};


                        // Sample data bit
                        shift_reg[bit_index] <= rx_sync_2;


                        if (bit_index == 3'd7) begin

                            // All 8 bits received
                            state <= STOP;

                        end

                        else begin

                            bit_index <= bit_index + 1'b1;

                        end

                    end

                    else begin

                        rx_count <= rx_count + 1'b1;

                    end

                end


                // ============================================================
                // STOP BIT
                // ============================================================

                STOP: begin

                    rx_busy <= 1'b1;


                    if (rx_count == DIVISOR - 1) begin

                        rx_count <= {CNT_WIDTH{1'b0}};


                        // STOP must be HIGH
                        if (rx_sync_2 == 1'b1) begin

                            rx_data <= shift_reg;

                            rx_done <= 1'b1;

                        end


                        rx_busy <= 1'b0;

                        state <= IDLE;

                    end

                    else begin

                        rx_count <= rx_count + 1'b1;

                    end

                end


                // ============================================================
                // DEFAULT
                // ============================================================

                default: begin

                    state     <= IDLE;

                    shift_reg <= 8'h00;

                    bit_index <= 3'd0;

                    rx_count  <= {CNT_WIDTH{1'b0}};

                    rx_busy   <= 1'b0;

                end

            endcase

        end

    end

endmodule



// ============================================================================
// MODULE 4 : UART TOP LEVEL
// ============================================================================

module uart_opt #(
    parameter integer CLK_FREQ  = 50_000_000,
    parameter integer BAUD_RATE = 9600
)(
    input wire clk,
    input wire rst,


    // ------------------------------------------------------------------------
    // TRANSMITTER
    // ------------------------------------------------------------------------

    input wire       tx_start,
    input wire [7:0] tx_data,

    output wire      tx,
    output wire      tx_busy,
    output wire      tx_done,


    // ------------------------------------------------------------------------
    // RECEIVER
    // ------------------------------------------------------------------------

    input wire rx,

    output wire [7:0] rx_data,
    output wire       rx_done,
    output wire       rx_busy
);


    // ------------------------------------------------------------------------
    // SHARED BAUD TICK
    // ------------------------------------------------------------------------

    wire tick_full;


    // ------------------------------------------------------------------------
    // SINGLE SHARED BAUD GENERATOR
    // ------------------------------------------------------------------------

    baud_gen_opt #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    )
    baud_generator (
        .clk(clk),
        .rst(rst),
        .tick_full(tick_full)
    );


    // ------------------------------------------------------------------------
    // TRANSMITTER
    // ------------------------------------------------------------------------

    uart_tx_opt transmitter (

        .clk(clk),
        .rst(rst),

        .tick_full(tick_full),

        .tx_start(tx_start),
        .tx_data(tx_data),

        .tx(tx),
        .tx_busy(tx_busy),
        .tx_done(tx_done)

    );


    // ------------------------------------------------------------------------
    // RECEIVER
    // ------------------------------------------------------------------------

    uart_rx_opt #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    )
    receiver (

        .clk(clk),
        .rst(rst),

        .rx(rx),

        .rx_data(rx_data),
        .rx_done(rx_done),
        .rx_busy(rx_busy)

    );

endmodule



// ============================================================================
// MODULE 5 : TESTBENCH
// ============================================================================
// This is ONLY for simulation.
// Set uart_opt_tb as Simulation Top.
// Set uart_opt as Synthesis Top.
// ============================================================================

module uart_opt_tb;


    // ------------------------------------------------------------------------
    // TESTBENCH SIGNALS
    // ------------------------------------------------------------------------

    reg clk;
    reg rst;

    reg       tx_start;
    reg [7:0] tx_data;

    wire tx;
    wire tx_busy;
    wire tx_done;

    wire [7:0] rx_data;
    wire       rx_done;
    wire       rx_busy;


    // ------------------------------------------------------------------------
    // DUT
    //
    // Simulation clock:
    // 10 ns period = 100 MHz equivalent
    //
    // Simulation UART:
    //
    // CLK_FREQ  = 1000
    // BAUD_RATE = 10
    //
    // DIVISOR = 100 clocks/bit
    //
    // This gives enough clocks per UART bit for the RX synchronizer
    // and makes the waveform easy to inspect.
    // ------------------------------------------------------------------------

    uart_opt #(
        .CLK_FREQ(1000),
        .BAUD_RATE(10)
    )
    uut (

        .clk(clk),
        .rst(rst),

        .tx_start(tx_start),
        .tx_data(tx_data),

        .tx(tx),
        .tx_busy(tx_busy),
        .tx_done(tx_done),

        // UART LOOPBACK
        .rx(tx),

        .rx_data(rx_data),
        .rx_done(rx_done),
        .rx_busy(rx_busy)

    );


    // ------------------------------------------------------------------------
    // CLOCK
    // ------------------------------------------------------------------------

    initial begin

        clk = 1'b0;

    end

    always #5 clk = ~clk;


    // ------------------------------------------------------------------------
    // TEST
    // ------------------------------------------------------------------------

    initial begin

        // ------------------------------------------------------------
        // INITIAL VALUES
        // ------------------------------------------------------------

        rst      = 1'b1;

        tx_start = 1'b0;

        tx_data  = 8'hA3;


        // ------------------------------------------------------------
        // RESET
        // ------------------------------------------------------------

        #100;

        rst = 1'b0;


        // ------------------------------------------------------------
        // WAIT
        // ------------------------------------------------------------

        #100;


        // ------------------------------------------------------------
        // START TRANSMISSION
        // ------------------------------------------------------------

        tx_start = 1'b1;

        #10;

        tx_start = 1'b0;


        // ------------------------------------------------------------
        // WAIT FOR TRANSMISSION TO FINISH
        // ------------------------------------------------------------

        wait (tx_done == 1'b1);


        // ------------------------------------------------------------
        // WAIT FOR RECEIVER
        // ------------------------------------------------------------

        wait (rx_done == 1'b1);


        // ------------------------------------------------------------
        // CHECK RESULT
        // ------------------------------------------------------------

        #20;

        if (rx_data == tx_data) begin

            $display("==============================================");
            $display("              UART TEST PASSED");
            $display("==============================================");
            $display("TX DATA = %h", tx_data);
            $display("RX DATA = %h", rx_data);
            $display("==============================================");

        end

        else begin

            $display("==============================================");
            $display("              UART TEST FAILED");
            $display("==============================================");
            $display("TX DATA = %h", tx_data);
            $display("RX DATA = %h", rx_data);
            $display("==============================================");

        end


        #100;

        $finish;

    end

endmodule