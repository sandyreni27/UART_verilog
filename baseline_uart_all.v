`timescale 1ns / 1ps

// ============================================================================
// BASELINE UART TRANSCEIVER (for comparison against uart_opt)
// ============================================================================
// UART FORMAT : 8N1 - 1 Start, 8 Data (LSB first), No Parity, 1 Stop
//
// MODULES:
// 1. baud_gen
// 2. uart_tx
// 3. uart_rx
// 4. uart
// 5. uart_tb
// ============================================================================

module baud_gen #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 9600
)(
    input  wire clk,
    input  wire rst,
    output reg  baud_tick
);
    localparam integer DIVISOR = CLK_FREQ / BAUD_RATE;
    reg [31:0] count;   // fixed-width, deliberately NOT right-sized - this is baseline

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            count     <= 0;
            baud_tick <= 0;
        end else if (count == DIVISOR - 1) begin
            count     <= 0;
            baud_tick <= 1;
        end else begin
            count     <= count + 1;
            baud_tick <= 0;
        end
    end
endmodule


module uart_tx (
    input  wire clk,
    input  wire rst,
    input  wire baud_tick,
    input  wire tx_start,
    input  wire [7:0] tx_data,
    output reg  tx,
    output reg  tx_busy,
    output reg  tx_done
);
    localparam IDLE = 2'd0, START = 2'd1, DATA = 2'd2, STOP = 2'd3;
    reg [1:0] state;
    reg [7:0] shift_reg;
    reg [2:0] bit_idx;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE; tx <= 1'b1; tx_busy <= 0; tx_done <= 0;
            shift_reg <= 0; bit_idx <= 0;
        end else begin
            tx_done <= 1'b0;
            case (state)
                IDLE: begin
                    tx <= 1'b1;
                    if (tx_start) begin
                        shift_reg <= tx_data;
                        tx_busy   <= 1'b1;
                        state     <= START;
                    end
                end
                START: begin
                    tx <= 1'b0;
                    if (baud_tick) begin
                        bit_idx <= 0;
                        state   <= DATA;
                    end
                end
                DATA: begin
                    tx <= shift_reg[0];
                    if (baud_tick) begin
                        shift_reg <= shift_reg >> 1;
                        if (bit_idx == 3'd7) state <= STOP;
                        else bit_idx <= bit_idx + 1'b1;
                    end
                end
                STOP: begin
                    tx <= 1'b1;
                    if (baud_tick) begin
                        tx_busy <= 0;
                        tx_done <= 1;
                        state   <= IDLE;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule


module uart_rx #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 9600
)(
    input  wire clk,
    input  wire rst,
    input  wire rx,
    output reg  [7:0] rx_data,
    output reg  rx_done,
    output reg  rx_busy
);
    localparam integer DIVISOR = CLK_FREQ / BAUD_RATE;
    localparam IDLE = 2'd0, START = 2'd1, DATA = 2'd2, STOP = 2'd3;

    reg [1:0]  state;
    reg [2:0]  bit_index;
    reg [7:0]  shift_reg;
    reg [31:0] clk_count;   // fixed-width, not right-sized - baseline
    reg        rx_sync0, rx_sync1;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_sync0 <= 1'b1;
            rx_sync1 <= 1'b1;
        end else begin
            rx_sync0 <= rx;
            rx_sync1 <= rx_sync0;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE; bit_index <= 0; shift_reg <= 0;
            rx_data <= 0; rx_done <= 0; rx_busy <= 0; clk_count <= 0;
        end else begin
            rx_done <= 1'b0;
            case (state)
                IDLE: begin
                    rx_busy   <= 0;
                    clk_count <= 0;
                    if (rx_sync1 == 1'b0) state <= START;
                end
                START: begin
                    rx_busy <= 1;
                    if (clk_count == (DIVISOR/2)) begin
                        clk_count <= 0;
                        bit_index <= 0;
                        state <= (rx_sync1 == 1'b0) ? DATA : IDLE;
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end
                DATA: begin
                    if (clk_count == DIVISOR - 1) begin
                        clk_count <= 0;
                        shift_reg[bit_index] <= rx_sync1;
                        if (bit_index == 3'd7) state <= STOP;
                        else bit_index <= bit_index + 1'b1;
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end
                STOP: begin
                    if (clk_count == DIVISOR - 1) begin
                        rx_data <= shift_reg;
                        rx_done <= 1;
                        rx_busy <= 0;
                        state   <= IDLE;
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule


module uart #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 9600
)(
    input  wire clk,
    input  wire rst,
    input  wire tx_start,
    input  wire [7:0] tx_data,
    output wire tx,
    output wire tx_busy,
    output wire tx_done,
    input  wire rx,
    output wire [7:0] rx_data,
    output wire rx_done,
    output wire rx_busy
);
    wire baud_tick;

    baud_gen #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE)) baud_gen_inst (
        .clk(clk), .rst(rst), .baud_tick(baud_tick)
    );
    uart_tx uart_tx_inst (
        .clk(clk), .rst(rst), .baud_tick(baud_tick),
        .tx_start(tx_start), .tx_data(tx_data),
        .tx(tx), .tx_busy(tx_busy), .tx_done(tx_done)
    );
    uart_rx #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE)) uart_rx_inst (
        .clk(clk), .rst(rst), .rx(rx),
        .rx_data(rx_data), .rx_done(rx_done), .rx_busy(rx_busy)
    );
endmodule


// This module is ONLY for simulation.
// Set uart_tb as Simulation Top.
// Set uart as Synthesis Top.
module uart_tb;
    reg clk, rst, tx_start;
    reg [7:0] tx_data;
    wire tx, tx_busy, tx_done;
    wire [7:0] rx_data;
    wire rx_done, rx_busy;

    uart #(.CLK_FREQ(1000), .BAUD_RATE(10)) uut (   // same DIVISOR as uart_opt_tb for a fair comparison
        .clk(clk), .rst(rst), .tx_start(tx_start), .tx_data(tx_data),
        .tx(tx), .tx_busy(tx_busy), .tx_done(tx_done),
        .rx(tx), .rx_data(rx_data), .rx_done(rx_done), .rx_busy(rx_busy)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst = 1; tx_start = 0; tx_data = 8'hA3;
        #100; rst = 0; #100;
        tx_start = 1; #10; tx_start = 0;

        wait (tx_done == 1);
        wait (rx_done == 1);
        #20;

        if (rx_data == tx_data)
            $display("PASS: baseline loopback correct, sent %h received %h", tx_data, rx_data);
        else
            $display("FAIL: sent %h but received %h", tx_data, rx_data);

        #100;
        $finish;
    end
endmodule