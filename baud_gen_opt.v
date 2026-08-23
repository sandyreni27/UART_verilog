

module baud_gen_opt #(
parameter integer CLK_FREQ  = 50_000_000,
parameter integer BAUD_RATE = 9600
)(
input  wire clk,
input  wire rst,

output reg  tick_full
);

localparam integer DIVISOR   = CLK_FREQ / BAUD_RATE;
localparam integer CNT_WIDTH = (DIVISOR <= 1) ? 1 : $clog2(DIVISOR);

reg [CNT_WIDTH-1:0] count;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        count     <= {CNT_WIDTH{1'b0}};
        tick_full <= 1'b0;
    end else begin
        tick_full <= 1'b0;
        if (count == DIVISOR - 1) begin
            count     <= {CNT_WIDTH{1'b0}};
            tick_full <= 1'b1;
        end else begin
            count <= count + 1'b1;
        end
    end
end
endmodule

