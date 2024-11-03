`timescale 1ns / 1ps
/**********************************************************************************************************
*   �������� ��LED_PWM
*	���̰汾 : V1.0
*   ����˵�� ��
*	�������� : VIVADO 2019.1
*   �������� ��2019/10/21
*   �޸����� ����µ��ӿƼ����Ϻ������޹�˾
*   ��˾���� ����µ��ӿƼ����Ϻ������޹�˾ ��Copyright (C), 2018-2025
*   ��˾��ַ ��www.puzhitech.com
**********************************************************************************************************/
module LED(
input sys_clk_p,
input sys_clk_n,
input sys_rstn,
output wire   [1:0]led
    );

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

assign led=(cnt<pwm_cnt)?2'b11:2'b00;

reg [31:0]cnt;
always@(posedge clk)
    begin
    if(!sys_rstn)begin
        cnt<=0;
    end
    else begin
        if(cnt<=200000)begin
            cnt<=cnt+1;
        end
        else begin
            cnt<=0;
        end
    end
 end   
 
reg [31:0]pwm_cnt;
reg [1:0]pwm_state;
always@(posedge clk)
    begin
    if(!sys_rstn)begin
        pwm_cnt<=0;
        pwm_state<=0;
    end
    else begin
        case(pwm_state)
        0:begin
             if(pwm_cnt<=200000)begin
                if(cnt==200000)begin
                    pwm_cnt<=pwm_cnt+100;
                end
                else begin
                    pwm_cnt<=pwm_cnt;
                end
            end
            else begin
                pwm_state<=1;
            end       
        end
        1:begin
             if(pwm_cnt!=0)begin
                if(cnt==200000)begin
                    pwm_cnt<=pwm_cnt-100;
                end
                else begin
                    pwm_cnt<=pwm_cnt;
                end
            end
            else begin
                pwm_state<=0;
            end          
        end
        default:begin
             pwm_cnt<=0;
             pwm_state<=0;
        end
        endcase
    end
 end//*/

endmodule
