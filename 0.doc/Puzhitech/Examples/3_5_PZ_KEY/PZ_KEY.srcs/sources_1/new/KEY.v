`timescale 1ns / 1ps
/**********************************************************************************************************
*   �������� ��KEY
*	���̰汾 :V1.0
*   ����˵�� ��
*	�������� : VIVADO 2019.1
*   �������� ��2019/10/21
*   �޸����� ����µ��ӿƼ����Ϻ������޹�˾
*   ��˾���� ����µ��ӿƼ����Ϻ������޹�˾ ��Copyright (C), 2018-2025
*   ��˾��ַ ��www.puzhitech.com
**********************************************************************************************************/
module KEY(
input sys_clk_p,
input sys_clk_n,
input sys_rstn,
input    [1:0]key,
output  reg [1:0]led
    );
parameter delay_time=20;

   wire clk;
   IBUFDS #(
      .DIFF_TERM("FALSE"),       
      .IBUF_LOW_PWR("TRUE"),     
      .IOSTANDARD("DEFAULT")     
   ) IBUFDS_inst (
      .O(clk), 
      .I(sys_clk_p),  
      .IB(sys_clk_n) 
   );

reg [31:0]cnt;
always@(posedge clk)
    begin
    if(!sys_rstn)begin
        cnt<=0;
    end
    else begin
        if(!key[0])begin
            if(cnt<delay_time)begin
                cnt<=cnt+1;
            end
            else begin
               if(!key[0])begin
                    led[0]<=1;
               end
               else begin
                    cnt<=0;
                    led[0]<=0;
               end
            end
        end
        else begin
             cnt<=0;
             led[0]<=0;
        end
    end
 end
    
 reg [31:0]cnt1;
always@(posedge clk)
    begin
    if(!sys_rstn)begin
        cnt1<=0;
    end
    else begin
        if(!key[1])begin
            if(cnt1<delay_time)begin
                cnt1<=cnt1+1;
            end
            else begin
               if(!key[1])begin
                    led[1]<=1;
               end
               else begin
                    cnt1<=0;
                    led[1]<=0;
               end
            end
        end
        else begin
             cnt1<=0;
             led[1]<=0;
        end
    end
 end
 
    
    
endmodule
