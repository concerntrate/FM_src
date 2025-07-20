module FM_Modulator #(parameter DW_OUT = 12, DW_IN = 12, PW = 24)(
    input wire clk, 
    input wire rst, 
    input wire en,
    // 载波频率对应的频率控制字
    input wire signed [PW-1:0] carr_freq, // freq / fs * 2^PW
    // 最大频率偏移量的比例
    input wire signed [PW-1:0] freq_shift,// df / fs * 2^PW Kf QPW-DW_IN.DW_IN 这个值的算法有Δf/min(都是包含正负的，都取峰峰值)
    // 输入被调制信号
    input wire signed [DW_IN-1:0] modin,     // m[n], 这个不管，DAC输入什么就是什么
    // 输出调制完的信号
    output wire signed [DW_OUT-1:0] modout   // s_fm[n], 这个不管，ADC输出什么就是什么

);
    // 计算调制的频率偏移量
    reg signed [PW+DW_IN-1:0] dfreq;
    reg signed [PW-1:0] dds_freq;
    always@(posedge clk) begin
        if(rst) begin
            dfreq <= 'd0;
        end
        else if(en) begin
            dfreq <= $signed(modin)*$signed(freq_shift);
        end
    end

    wire signed [PW-1:0] dfreq_Q;
    assign dfreq_Q = dfreq >>> DW_IN;

    // 加上载波频率
    always@(posedge clk) begin
        if(rst) begin
            dds_freq <= 'd0;
        end
        // 这里不用担心溢出，因为这个值太大了，48.5M也只占了差不多一半
        else if(en) begin
            dds_freq <= dfreq_Q + carr_freq;
        end
    end

    // 主要是控制freq,dds_freq   phase,PW'(0)就完了
    DDS #(PW, DW_OUT, DW_OUT+2) fmDDS(
    .clk(clk), 
    .rst(rst), 
    .en(en), 
    .freq(dds_freq), 
    .phase('d0), 
    .out(modout));

endmodule