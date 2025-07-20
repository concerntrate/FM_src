module AM_Modulator #( parameter DW = 12 )(
    input clk,
    input rst,
    input en,
    input signed [DW-1:0] carr,     // 载波信号 Q1.FW
    input signed [DW-1:0] base,     // m[n], 基带信号 Q1.FW
    input signed [DW-1:0] shift,    // a0,   直流偏移 Q1.FW
    input signed [DW-1:0] index,    // M,    调制度，调制度是[0,1) Q1.FW吧
    output wire signed [DW:0] modout // 调制输出 Q1.FW
);
    // 在这里我们不做定点化，直接接收的是DAC的浮点数的输入
    // 其实也不是浮点数，就是一个简单的映射

    localparam FW = DW - 1;

    reg signed [DW-1:0] m_attn;    // 信号乘调制度
    reg signed [2*DW-1:0] m_attn_full;    // 信号乘调制度  
    reg signed [DW:0] m_shift;
    reg signed [2*DW:0] modout_full;      


    // 输入信号乘调制度
    // 这里的index [0,1)，所以说，整数肯定不会被放大的，这里就把第一位截断了
    always @ (posedge clk) begin
        if (rst) begin
            m_attn_full <= 0;
            m_attn <= 0;
        end
        else if (en) begin
            // 这里需要考虑这个调制度了
            // Q1.11 * Q1.11 = Q2.22 右移动Q2.11，并舍弃掉高位(乘的数一定小于1)，结果输出Q1.11
            // 下面这个代码的执行逻辑是这个样子的，不是说算完了再移位然后截位，而是先截位，然后移位
            m_attn_full <= ($signed(base)* $signed(index));
            m_attn <= m_attn_full[2*DW-2:DW-1];
        end
            
    end
    // 这里要保证不溢出 Q2.FW
    always @ (posedge clk) begin
        if (rst)
            m_shift <= 0;
        else if (en)
            // Q1.11+Q1.11 = Q2.11，没问题这里
            m_shift <= $signed(m_attn) + $signed(shift);
    end
    // 这里的输出仍然是Q2.FW
    always @ (posedge clk) begin
        if (rst)
            modout_full <= 0;
        else if (en)
            // Q16的信号
            // Q2.11 * Q1.11 = Q3.22 然后右移动 Q3.11，仍然是把最高位截取掉，变成Q2.11
            modout_full <= $signed(m_shift)* $signed(carr);
    end
    // 最关键的问题是我现在要把这个信号加到另一个信号上去
    assign modout = modout_full[2*DW-1:DW-1];
endmodule
