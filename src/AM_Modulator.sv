// 明白了，其实这里的这个位数截取不一样的
module AM_Modulator #( parameter W = 12 )(
   input wire clk, rst, en,
   input wire signed [W-1:0] carr,
   input wire signed [W-1:0] base,  // m[n], Q1.W-1
   input wire signed [W-1:0] shift, // a0,   Q1.W-1 in [0, 1)
   input wire signed [W-1:0] index, // M,    Q1.W-1 in [0, 1)
   output logic signed [W:0] modout   // s_AM  Q2.W-1
);
   localparam FW = W - 1;

   logic signed [W-1:0] m_attn;    // Q1.FW
   always_ff@(posedge clk) begin
        if (rst) begin
            m_attn <= 'd0;
        end
        else begin
            m_attn <= ((2*W)'(base) * index) >>> FW;
        end
   end

   logic signed [W:0] m_shift;     // Q2.FW
   always_ff@(posedge clk) begin
        if (rst) begin
            m_shift <= 'd0;
        end
        else begin
            m_shift <= m_attn + shift;
        end
   end

   always_ff@(posedge clk) begin  // Q2.FW
        if (rst) begin
            modout <= {(W){1'b0}};
        end
        else begin
            modout <= ((2*W+1)'(m_shift) * carr) >>> FW;
        end
   end
endmodule
