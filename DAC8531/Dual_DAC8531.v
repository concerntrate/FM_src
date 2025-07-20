module Dual_DAC8531 #(parameter DW_OUT = 16, PW = 24)(
    input clk_10M,
    input rst, 
    // 通道一
    output	reg			SYNC1,		
    output				SCLK1,		
    output	reg			DIN1,
    // 通道二
    output	reg			SYNC2,		
    output				SCLK2,		
    output	reg			DIN2			
);

wire [DW_OUT-1:0] DDS_out ;
// 检测到tx_en的上升沿锁存之后发送
// 30个clk_10M周期完成一次发送
localparam Trans_UP_TIME = 3'd4;// 3个10M的时钟周期,1个周期拉低
localparam Trans_UP_TIME_DONE = 3'd3;// 3个10M的时钟周期,1个周期拉低
// 这里就设置为循环发送
reg [2:0] tx_loop_cnt;
always @(posedge clk_10M) begin
    if (rst) begin
        tx_loop_cnt <= 3'd0;
    end
    else if (tx_loop_cnt == Trans_UP_TIME) begin
        tx_loop_cnt <= 3'd0;
    end
    else begin
        tx_loop_cnt <= tx_loop_cnt + 3'd1;
    end
end

wire tx_en;
assign tx_en = (tx_loop_cnt >= Trans_UP_TIME_DONE)?1'b0:1'b1;

// 要接收DDS的数据，但是这样子可能会形成采样
// 没有什么很大的问题
reg [15:0] data;
always @(posedge clk_10M) begin
    if (rst) begin
        data <= 16'd0;
    end
    else if (!tx_en) begin
        data <= DDS_out;
    end
end


// 例化两个模块
DAC8531  u1_DAC8531 (
    .clk_10M                 ( clk_10M   ),
    .data                    ( data      ),
    .tx_en                   ( tx_en     ),

    .SYNC                    ( SYNC1      ),
    .SCLK                    ( SCLK1      ),
    .DIN                     ( DIN1       )
);

DAC8531  u2_DAC8531 (
    .clk_10M                 ( clk_10M   ),
    .data                    ( data      ),
    .tx_en                   ( tx_en     ),

    .SYNC                    ( SYNC2     ),
    .SCLK                    ( SCLK2     ),
    .DIN                     ( DIN2      )
);

// 例化一个DDS
localparam DDS_fre = 24'd2048;
wire dds_en;
assign DDS_en = 1;

DDS #(PW, DW_OUT, DW_OUT+2) Signal_DDS_Bup(
    .clk(clk), 
    .rst(rst), 
    .en(DDS_en), 
    .freq(DDS_fre), 
    .phase('d0), 
    .out(DDS_out));


endmodule