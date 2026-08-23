`timescale 1ns / 1ps

module uart_opt_tb;

reg        clk;
reg        rst;
reg        tx_start;
reg  [7:0] tx_data;

wire       tx;
wire       tx_busy;
wire       tx_done;
wire [7:0] rx_data;
wire       rx_done;
wire       rx_busy;

uart_opt #(
    .CLK_FREQ(1000),
    .BAUD_RATE(100)
) uut (
    .clk(clk),
    .rst(rst),
    .tx_start(tx_start),
    .tx_data(tx_data),
    .tx(tx),
    .tx_busy(tx_busy),
    .tx_done(tx_done),
    .rx(tx),
    .rx_data(rx_data),
    .rx_done(rx_done),
    .rx_busy(rx_busy)
);

initial begin
    clk = 1'b0;
end

always #5 clk = ~clk;

initial begin
    rst      = 1'b1;
    tx_start = 1'b0;
    tx_data  = 8'hA3;

    #20;
    rst = 1'b0;

    #20;
    tx_start = 1'b1;
    #10;
    tx_start = 1'b0;

    wait (rx_done == 1'b1);
    #10;

    if (rx_data == tx_data) begin
        $display("--------------------------------------------");
        $display("PASS");
        $display("TX DATA = %h", tx_data);
        $display("RX DATA = %h", rx_data);
        $display("--------------------------------------------");
    end else begin
        $display("--------------------------------------------");
        $display("FAIL");
        $display("TX DATA = %h", tx_data);
        $display("RX DATA = %h", rx_data);
        $display("--------------------------------------------");
    end

    #20;
    $finish;
end
endmodule