module  hdmi_top(
    input           pixel_clk,
    input           pixel_clk_5x,    
    input           sys_rst_n,
   //hdmi�ӿ�
   output      HDMI_CLK_P,
   output      HDMI_CLK_N,
   output      HDMI_D0_P,
   output      HDMI_D0_N,
   output      HDMI_D1_P,
   output      HDMI_D1_N,
   output      HDMI_D2_P,
   output      HDMI_D2_N,
   
   output      HDMI_1_CLK_P,
   output      HDMI_1_CLK_N,
   output      HDMI_1_D0_P,
   output      HDMI_1_D0_N,
   output      HDMI_1_D1_P,
   output      HDMI_1_D1_N,
   output      HDMI_1_D2_P,
   output      HDMI_1_D2_N,      
   //�û��ӿ� 
    output          video_vs,       //HDMI���ź�      
    output  [10:0]  h_disp,         //HDMI��ˮƽ�ֱ���  
    input   [15:0]  data_in,        //��������
    output          data_req        //������������   
);

//wire define
wire          video_hs;
wire          video_de;
wire  [23:0]  video_rgb;
wire  [15:0]  video_rgb_565;

//������ͷ16bit����ת��Ϊ24bit��hdmi����
assign video_rgb  = {video_rgb_565[15:11],3'b000,video_rgb_565[10:5],2'b00,
                    video_rgb_565[4:0],3'b000};  
 
//������Ƶ��ʾ����ģ��
video_driver u_video_driver(
    .pixel_clk      (pixel_clk),
    .sys_rst_n      (sys_rst_n),

    .video_hs       (video_hs),
    .video_vs       (video_vs),
    .video_de       (video_de),
    .video_rgb      (video_rgb_565),
   
    .data_req       (data_req),
    .h_disp         (h_disp),
    .v_disp         (), 
    .pixel_data     (data_in)
    );
       
//����HDMI����ģ��              
HDMI_IP U1(
        .PXLCLK_I           (pixel_clk),    
        .PXLCLK_5X_I        (pixel_clk_5x), 
        .LOCKED_I           (sys_rst_n),
        .RST_N              (1'b1),
        .VGA_RGB            (video_rgb), 
        .VGA_HS             (video_hs),  
        .VGA_VS             (video_vs),  
        .VGA_DE             (video_de),  
        .HDMI_CLK_P         (HDMI_CLK_P),
        .HDMI_CLK_N         (HDMI_CLK_N),
        .HDMI_D2_P          (HDMI_D2_P),
        .HDMI_D2_N          (HDMI_D2_N),
        .HDMI_D1_P          (HDMI_D1_P),
        .HDMI_D1_N          (HDMI_D1_N),
        .HDMI_D0_P          (HDMI_D0_P),
        .HDMI_D0_N          (HDMI_D0_N)
    );
 //����HDMI����ģ��              
    HDMI_IP U2(
            .PXLCLK_I           (pixel_clk),    
            .PXLCLK_5X_I        (pixel_clk_5x), 
            .LOCKED_I           (sys_rst_n),
            .RST_N              (1'b1),
            .VGA_RGB            (video_rgb), 
            .VGA_HS             (video_hs),  
            .VGA_VS             (video_vs),  
            .VGA_DE             (video_de),  
            .HDMI_CLK_P         (HDMI_1_CLK_P),
            .HDMI_CLK_N         (HDMI_1_CLK_N),
            .HDMI_D2_P          (HDMI_1_D2_P),
            .HDMI_D2_N          (HDMI_1_D2_N),
            .HDMI_D1_P          (HDMI_1_D1_P),
            .HDMI_D1_N          (HDMI_1_D1_N),
            .HDMI_D0_P          (HDMI_1_D0_P),
            .HDMI_D0_N          (HDMI_1_D0_N)
        );   
endmodule 