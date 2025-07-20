/******************************FILE HEAD**********************************
 * file_name		: DAC8531.v
 * function			: DAC8531 SPI接口    低功耗16位数模转换芯片
 * author			: 今朝无言
 * date				: 2021/11/16
 *************************************************************************/
module DAC8531(
input				clk_10M,
input		[15:0]	data,
input				tx_en,		//上升沿启动一次DA转换    高电平请保持至少2个10MHz的clk
output	reg			SYNC,		//即CS，低电平有效
output				SCLK,		//最大30MHz(3.6~5.5V供电)/20MHz(2.7~3.6V供电)  下降沿有效
output	reg			DIN			//串行数据，会存入芯片里的24位移位寄存器
);
//发送顺序：DB23,DB22,...DB1,DB0
//数据格式：x,x,x,x,x,x,PD1,PD0,D15,D14,...,D1,D0
//PD1,PD0对应模式说明：00,Normal; 01,1kOhm to GND; 10,100kOhm to GND; 11,High-Z
//Vout范围：0~Vref


//-------------------SPI-----------------------
reg 			start		= 0;
reg 			tx_en_buf	= 1;
reg 			tx_en_up;
reg		[5:0]	state;
reg		[23:0]	DB;

assign	SCLK	= clk_10M;

always@(posedge clk_10M)begin //上升沿改变数据，在SCLK下降沿正好方便芯片读入DIN
	tx_en_buf	<= tx_en;
	tx_en_up	<= tx_en&(~tx_en_buf);
	
	if(tx_en_up)begin
		start	<= 1;
		state	<= 29;					//这里设为29，则30个clk_10M周期完成一次发送，state至少要大于等于24
        DB		<= {6'd0,2'b00,data};	//PD1PD0这里设为00，可根据自身需要修改
		SYNC	<= 1;
		DIN		<= 0;
	end
	else if(start)begin
		state	<= state-1;
		
		if(state>=24+1)begin
			SYNC	<= 1;
			DIN		<= 0;
		end
		else if(state>=1)begin
			SYNC	<= 0;
			DIN		<= DB[state-1];
		end
		else begin //state=0
			SYNC	<= 1;
			DIN		<= 0;
			start	<= 0;
		end
	end
	else begin
		SYNC	<= 1;
		DIN		<= 0;
	end
end

endmodule
//END OF DAC8531.v FILE***************************************************
