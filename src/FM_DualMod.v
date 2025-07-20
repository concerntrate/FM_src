module FM_DualMod #(parameter DW_OUT = 12, DW_IN = 12, PW = 24)(
    input wire clk, rst, en,
    // 载波频率对应的频率控制字
    input wire signed [PW-1:0] carr_freq, // freq / fs * 2^PW
    // 最大频率偏移量的比例
    input wire signed [PW-1:0] freq_shift,// df / fs * 2^PW Kf
    // 输入被调制信号A
    input wire signed [DW_IN-1:0] modAin,     // m[n], 
    // 输入被调制信号B
    input wire signed [DW_IN-1:0] modBin,     // m[n], 
    // 输入频偏控制信号
    input wire signed [DW_IN-1:0] Vc_t  ,     // Vc_t, 
    input wire signed [PW-1:0] Kvf   ,     // 频率偏移的斜率
    // 输出调制完的信号
    output wire signed [DW_OUT-1:0] modout,        // s_fm[n],  
    // 输出调制完的信号
    output wire signed [DW_OUT-1:0] modAout,  // s_fm[n], 这个不管，ADC输出什么就是什么
    // 输出调制完的信号
    output wire signed [DW_OUT-1:0] modBout   // s_fm[n], 这个不管，ADC输出什么就是什么
);
    // 前提：时钟频率假设100Mhz PM = 24 
    // 那么 carr_freq = 24'd8136950(48.5Mhz)  voiceA_fre = 24'd504 (3Khz)  voiceB_fre = 24'd336 (2Khz)  upB_fre = 24'd18452(110Khz)
    // 要明白一个点就是freq控制字和频率fout完全相同的
    localparam upB_fre = 24'd18452;
    // 适用于任何 N 位有符号数
    localparam signed AM_M = 12'sd1024;

    // 先根据Vc_t计算载波频率
    reg signed [PW-1:0] freq_V_add;
    always@(posedge clk) begin
        if(rst)begin
            freq_V_add <= {(PW){1'b0}};
        end 
        else if(en) begin
            freq_V_add <= ($signed(Vc_t) * $signed(Kvf)) >>> (DW_IN);
        end 
    end
    // 加上载波频率
    reg signed [PW-1:0] carr_fre_refre;
    always@(posedge clk) begin
        if(rst) carr_fre_refre <= {(PW){1'b0}};
        else if(en) carr_fre_refre <= freq_V_add + carr_freq;
    end

    // 例化A的调制
    FM_Modulator #(
        .DW_OUT(DW_OUT),
        .DW_IN(DW_IN),
        .PW(PW)
    ) u_fm_modA (
        .clk        (clk),
        .rst        (rst),
        .en         (en),
        .carr_freq  (carr_fre_refre),
        .freq_shift (freq_shift),
        .modin      (modAin),
        .modout     (modAout)
    );

    // 再计算B上变频的频率偏移
    reg signed [PW-1:0] carr_fre_up;
    always@(posedge clk) begin
        if(rst) carr_fre_up <= {(PW){1'b0}};
        else if(en) carr_fre_up <= upB_fre + carr_fre_refre;
    end

    // 再例化B的调制
    FM_Modulator #(
        .DW_OUT(DW_OUT),
        .DW_IN(DW_IN),
        .PW(PW)
    ) u_fm_modB (
        .clk        (clk),
        .rst        (rst),
        .en         (en),
        .carr_freq  (carr_fre_up),
        .freq_shift (freq_shift),
        .modin      (modBin),
        .modout     (modBout)
    );




    // 下面操作一起调制
    // modAin就是输入的信号
    // modBin_up是要经过变频/AM调制的信号modBin
    // 下面先对modBin进行调制
    wire signed [DW_IN:0] modBin_up;
    // 先生成一个载波
    wire  signed [DW_IN-1:0] carr; 
    DDS #(PW, DW_IN, DW_IN+2) Signal_DDS_Bup(
        .clk(clk), 
        .rst(rst), 
        .en(en), 
        .freq(upB_fre), 
        .phase('d0), 
        .out(carr));

    AM_Modulator #(
    .DW ( DW_IN ))
    u_AM_Modulator (
        .clk                     ( clk      ),
        .rst                     ( rst      ),
        .en                      ( en       ),
        .carr                    ( carr     ),
        .base                    ( modBin   ),
        .shift                   ( 'd0      ),
        .index                   ( AM_M     ),

        .modout                  ( modBin_up )
    );

    reg signed [DW_IN-1:0] modin_add;
    always @(posedge clk) begin
        if (rst) begin
            modin_add  <= {(DW_IN){1'b0}};
        end
        else  begin
            modin_add <= $signed(modBin_up[DW_IN:1])+$signed(modAin >>> 2);
        end
    end
    // 再例化和的调制
    FM_Modulator #(
        .DW_OUT(DW_OUT),
        .DW_IN(DW_IN),
        .PW(PW)
    ) u_fm_modC (
        .clk        (clk),
        .rst        (rst),
        .en         (en),
        .carr_freq  (carr_fre_refre), // 加上了Vc_t的信号来的
        .freq_shift (freq_shift),
        .modin      (modin_add),
        .modout     (modout)
    );
endmodule
