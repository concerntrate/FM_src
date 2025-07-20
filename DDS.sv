module DDS #(
    // PW-频率/相位控制字位宽
    // DW-信号位宽 - DAC分辨率
    // AW-信号深度 - 相位的分辨率
    parameter PW = 32, DW = 10, AW = 13
)(
    input wire clk, rst, en,
    input wire signed [PW - 1 : 0] freq, phase,
    output logic signed [DW - 1 : 0] out
);
    // 输出频率   fout = freq*fclk/2^PW
    // 频率分辨率 Δf = fclk/2^PW
    localparam LEN = 2**AW;
    localparam real PI = 3.1415926535897932;
    logic signed [DW-1 : 0] sine[LEN];

    initial begin
        for(int i = 0; i < LEN; i++) begin
            sine[i] = $sin(2.0 * PI * i / LEN) * (2.0**(DW-1) - 1.0);
        end
    end
    // 先算Phaseacc 积累的，不管这个初始化的相位控制字
    logic [PW-1 : 0] phaseAcc;
    always_ff@(posedge clk) begin
        if(rst) phaseAcc <= '0;
        else if(en) phaseAcc <= phaseAcc + freq;
    end
    // 再算Phasesum 加上这个初始化的相位控制字
    wire [PW-1 : 0] phaseSum = phaseAcc + phase;
    // 截位输出
    always_ff@(posedge clk) begin
        if(rst) out <= '0;
        else if(en) out <= sine[phaseSum[PW-1 -: AW]];
    end
endmodule