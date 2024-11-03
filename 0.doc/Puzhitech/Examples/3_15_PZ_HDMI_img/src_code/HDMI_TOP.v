`timescale 1ns / 1ps
/**********************************************************************************************************
*   �������� ��HDMI_TOP
*	���̰汾 : V1.0
*   ����˵�� ��HDMI���̵Ķ����ļ�
*	�������� : VIVADO 2019.1
*   �������� ��2019/10/21
*   �޸����� ����µ��ӿƼ����Ϻ������޹�˾
*   ��˾���� ����µ��ӿƼ����Ϻ������޹�˾ ��Copyright (C), 2018-2025
*   ��˾��ַ ��www.puzhitech.com
**********************************************************************************************************/


module HDMI_TOP(
    input       sys_clk_p,
    input       sys_clk_n,    
    input       sys_rstn, 
    
    output      HDMI_CLK_P,
    output      HDMI_CLK_N,
    output      HDMI_D0_P,
    output      HDMI_D0_N,
    output      HDMI_D1_P,
    output      HDMI_D1_N,
    output      HDMI_D2_P,
    output      HDMI_D2_N  
);

wire pclk;
wire locked;
wire[7:0]   VGA_R,VGA_G,VGA_B;
wire VGA_HS,VGA_VS,VGA_DE;

HDMI_DATA_GEN U0
(
    .pclk               (pclk),
    .rst                (locked),
    .VGA_R              (VGA_R),
    .VGA_G              (VGA_G),
    .VGA_B              (VGA_B),
    .VGA_HS             (VGA_HS),
    .VGA_VS             (VGA_VS),
    .VGA_DE             (VGA_DE)
);

wire sclk;
wire[23:0]  RGB_DATA;
assign RGB_DATA={VGA_R,VGA_G,VGA_B};

HDMI_IP U1(
    .PXLCLK_I           (pclk),
    .PXLCLK_5X_I        (sclk),
    .LOCKED_I           (locked),
    .RST_N              (1'b1),
    .VGA_HS             (VGA_HS),
    .VGA_VS             (VGA_VS),
    .VGA_DE             (VGA_DE),
    .VGA_RGB            (RGB_DATA),
    .HDMI_CLK_P         (HDMI_CLK_P),
    .HDMI_CLK_N         (HDMI_CLK_N),
    .HDMI_D2_P          (HDMI_D2_P),
    .HDMI_D2_N          (HDMI_D2_N),
    .HDMI_D1_P          (HDMI_D1_P),
    .HDMI_D1_N          (HDMI_D1_N),
    .HDMI_D0_P          (HDMI_D0_P),
    .HDMI_D0_N          (HDMI_D0_N)
); 

clk_wiz_0   U3(
    .clk_in1_p          (sys_clk_p),    
    .clk_in1_n          (sys_clk_n),   
    .resetn             (sys_rstn),
    .clk_out1           (pclk),
    .clk_out2           (sclk),
    .locked             (locked)
);


endmodule