module uart_opt #(
parameter integer CLK_FREQ  = 50_000_000,
parameter integer BAUD_RATE = 9600
)(
input  wire       clk,
input  wire       rst,

// Transmitter
input  wire       tx_start,
input  wire [7:0] tx_data,
output wire       tx,
output wire       tx_busy,
output wire       tx_done,

// Receiver
input  wire       rx,
output wire [7:0] rx_data,
output wire       rx_done,
output wire       rx_busy
);

wire tick_full;

baud_gen_opt #(
    .CLK_FREQ(CLK_FREQ),
    .BAUD_RATE(BAUD_RATE)
) baud_gen_inst (
    .clk(clk),
    .rst(rst),
    .tick_full(tick_full)
);

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

uart_rx_opt #(
    .CLK_FREQ(CLK_FREQ),
    .BAUD_RATE(BAUD_RATE)
) receiver (
    .clk(clk),
    .rst(rst),
    .rx(rx),
    .rx_data(rx_data),
    .rx_done(rx_done),
    .rx_busy(rx_busy)
);
endmodule