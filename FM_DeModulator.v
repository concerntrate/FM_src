module FM_DeModulator #(
    parameter data_width        = 12,
    parameter output_data_width = 10
) (
    input                              clk,
    input                              rst,
    input       signed [data_width-1:0] fm_mod_data,
    output      signed [output_data_width-1:0] fm_demod_data,
    output      [13:0]                 peak_value,
    output reg  [13:0]                 cal_Rb,
    output reg   signed [output_data_width-1:0] output_fm_demod_data
);

    wire signed [23:0] fm_mult_data;
    wire signed [23:0] fm_fir_data;

    // 用reg数组模拟6级移位寄存器
    reg signed [data_width-1:0] data_in_0;
    reg signed [data_width-1:0] data_in_1;
    reg signed [data_width-1:0] data_in_2;
    reg signed [data_width-1:0] data_in_3;
    reg signed [data_width-1:0] data_in_4;
    reg signed [data_width-1:0] data_in_5;

    integer i;

    always @(posedge clk) begin
        data_in_0 <= fm_mod_data;
        data_in_1 <= data_in_0;
        data_in_2 <= data_in_1;
        data_in_3 <= data_in_2;
        data_in_4 <= data_in_3;
        data_in_5 <= data_in_4;
    end

    mult_delayed i_mult (
        .CLK(clk),
        .A(fm_mod_data),
        .B(data_in_5),
        .P(fm_mult_data)
    );

    fir_compiler_FM fir_FM_ip (
        .aclk(clk),
        .s_axis_data_tvalid(1'b1),
        .s_axis_data_tdata(fm_mult_data),
        .m_axis_data_tdata(fm_fir_data)
    );

    reg        overranged_flag;
    reg [10:0] deflip;

    always @(posedge clk) begin
        if (fm_demod_data < 80 || fm_demod_data > 950) begin
            deflip          <= 11'd400;
            overranged_flag <= 1'b1;
        end else if(deflip == 0) begin
            overranged_flag <= 1'b0;
        end else begin
            deflip <= deflip - 1'b1;
        end

        if (!overranged_flag) begin
            output_fm_demod_data <= fm_fir_data[11:2];
        end else begin
            output_fm_demod_data <= 10'd200;
        end
    end

    assign fm_demod_data = fm_fir_data[10:1];

    reg [1:0] step;
    reg [13:0] counter_Rb;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            step <= 2'd0;
        end else begin
            case (step)
                2'd0: begin
                    if (!overranged_flag) begin
                        counter_Rb <= 14'd0;
                    end else begin
                        step       <= step + 2'd1;
                        counter_Rb <= 14'd1;
                    end
                end
                2'd1: begin
                    counter_Rb <= counter_Rb + 14'd1;
                    if (!overranged_flag) begin
                        step <= step + 2'd1;
                    end
                end
                2'd2: begin
                    cal_Rb <= counter_Rb;
                    if (overranged_flag) begin
                        step <= 2'd0;
                    end
                end
            endcase
        end
    end

    reg [9:0] delay [0:15];
    integer j;

    assign peak_value = delay[15];

    always @(posedge clk) begin
        if (step == 2'd2) begin
            delay[0] <= fm_demod_data;
            for (j=0; j<15; j=j+1) begin
                delay[j+1] <= delay[j];
            end
        end
    end

endmodule
