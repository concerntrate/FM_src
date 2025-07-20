module FM_DeModulator #(
    parameter data_width        = 12,
    parameter output_data_width = 10
) (
    input                                     clk                 ,
    input                                     rst                 ,
    input      signed [       data_width-1:0] fm_mod_data         ,
    output     signed [output_data_width-1:0] fm_demod_data       ,
    output            [                  13:0] peak_value         ,
    output reg        [                 13:0] cal_Rb              ,
    output reg signed [output_data_width-1:0] output_fm_demod_data
);

    wire    signed [          23:0] fm_mult_data     ;
    wire    signed [          23:0] fm_fir_data      ;
    reg     signed [data_width-1:0] data_in     [0:5];
    integer                         i                ;

    always @(posedge clk) begin : proc_delay
        data_in[0] <= fm_mod_data;
        for(i=0; i<=4; i=i+1) begin
            data_in[i+1] <= data_in[i];
        end
    end

    mult_delayed i_mult (
        .CLK(clk         ),   // input wire CLK
        .A  (fm_mod_data ),   // input wire [11 : 0] A
        .B  (data_in[5]  ),   // input wire [11 : 0] B
        .P  (fm_mult_data)    // output wire [23 : 0] P
    );


    fir_compiler_FM fir_FM_ip (
        .aclk              (clk         ),   // input wire aclk
        .s_axis_data_tvalid(1'd1        ),   // input wire s_axis_data_tvalid
        //.s_axis_data_tready(s_axis_data_tready),  // output wire s_axis_data_tready
        .s_axis_data_tdata (fm_mult_data),   // input wire [23 : 0] s_axis_data_tdata
        //.m_axis_data_tvalid(m_axis_data_tvalid),  // output wire m_axis_data_tvalid
        .m_axis_data_tdata (fm_fir_data )    // output wire [47 : 0] m_axis_data_tdata
    );

    reg        overranged_flag;
    reg [10:0] deflip         ;
    always @(posedge clk) begin : proc_
        if (fm_demod_data < 80 | fm_demod_data > 950) begin
            deflip          <= 11'd400;
            overranged_flag <= 1;
        end
        else if(deflip == 0) begin
            overranged_flag <= 0;
        end
        else begin
            deflip <= deflip - 1;
        end

        if (!overranged_flag) begin
            output_fm_demod_data <= fm_fir_data[11:2];
        end
        else begin
            output_fm_demod_data <= 200;
        end
    end

    assign fm_demod_data = fm_fir_data[10:1];


    reg [ 1:0] step      ;
    reg [13:0] counter_Rb;
    always @(posedge clk) begin : proc_counter_Rb
        if (rst) begin
            step <= 2'd0;
        end

        case (step)
            2'd0 : begin
                if (~overranged_flag) begin
                    counter_Rb <= 14'd0;
                end
                else begin
                    step       <= step + 2'd1;
                    counter_Rb <= 14'd1;
                end
            end
            2'd1 : begin
                counter_Rb <= counter_Rb + 1'd1;
                if (~overranged_flag) begin
                    step <= step + 2'd1;
                end
            end
            2'd2 : begin
                cal_Rb <= counter_Rb;
                if (overranged_flag) begin
                    step <= 2'd0;
                end
            end
        endcase
    end

    integer       j         ;
    reg     [9:0] delay[0:15];
    assign peak_value = delay[15];
    always @(posedge clk) begin : proc_average_delay
        if (step == 2'd2) begin
            delay[0] <= fm_demod_data;
            for(j=0; j<=14; j=j+1) begin
                delay[j+1] <= delay[j];
            end
        end
    end


endmodule
