`timescale  1ns / 1ps
module tb_FM_top #(parameter DW_OUT = 12, DW_IN = 12, PW = 24)(
);

// FM_DualMod Parameters
localparam PERIOD  = 10;

// FM_DualMod Inputs
reg   clk                                  = 0 ;
reg   rst                                  = 1 ;
reg   en                                   = 1 ;

// 下面是一些固定的变量
reg   signed [PW-1:0]  freq_shift          = 3355 ;  // Δfmax ->Δfword max -> ΔVmax(Q/noQ)  0.8192 取PW为24，DW为12 Q12.12，取值为
reg   signed [DW_IN-1:0]  Vc_t             = 0 ; 
reg   [PW-1:0]  Kvf                        = 50331 ; // 这个要求Δf在300Khz

// 输出
wire signed [DW_OUT-1:0] modout;
wire signed [DW_OUT-1:0] modAout;
wire signed [DW_OUT-1:0] modBout;

// 初始化时钟和复位
initial
begin
    forever #(PERIOD/2)  clk=~clk;
end

initial
begin
    #(PERIOD*2) rst  =  0;
end


// 载波频率对应的频率控制字
wire signed [PW-1:0] carr_freq; 
assign  carr_freq = 24'd8136950;

wire signed [PW-1:0] A_freq; 
assign  A_freq = 24'd504;

wire signed [PW-1:0] B_freq; 
assign  B_freq = 24'd336;


// 生成信号A
wire  signed [DW_IN-1:0] modAin;    
DDS #(PW, DW_IN, DW_IN+2) Signal_DDS_A(
    .clk(clk), 
    .rst(rst), 
    .en(en), 
    .freq(A_freq), 
    .phase('d0), 
    .out(modAin));

// 生成信号B
wire  signed [DW_IN-1:0] modBin; 
DDS #(PW, DW_IN, DW_IN+2) Signal_DDS_B(
    .clk(clk), 
    .rst(rst), 
    .en(en), 
    .freq(B_freq), 
    .phase('d0), 
    .out(modBin));


FM_DualMod #(
        .DW_OUT(DW_OUT),
        .DW_IN(DW_IN),
        .PW(PW)
    ) u_FM_DualMod(
    .clk                     ( clk          ),
    .rst                     ( rst          ),
    .en                      ( en           ),
    .carr_freq               ( carr_freq    ),
    .freq_shift              ( freq_shift   ),
    .modAin                  ( modAin       ),
    .modBin                  ( modBin       ),
    .Vc_t                    ( Vc_t         ),
    .Kvf                     ( Kvf          ),

    .modout                  ( modout       ),
    .modAout                 ( modAout      ),
    .modBout                 ( modBout      )
    );

    integer save_file;
    initial begin
        save_file = $fopen("D:\\86198\\ee_race\\2019G\\mat_prj\\modout.txt");    //打开所创建的文件；若找不到该文件，则会自动创建该文件。
        if(save_file == 0)begin 
            $display ("can not open the file!");    //如果创建文件失败，则会显示"can not open the file!"信息。
            $stop;
        end
    end

    always @(posedge clk) begin
        if(en && !rst) begin
            $fdisplay(save_file,"%d",modout);    //在使能信号为高时，每当时钟的上升沿到来时将数据写入到所创建的.txt文件中
        end
    end

endmodule