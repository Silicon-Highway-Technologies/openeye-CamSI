`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/10/25 11:27:39
// Design Name: 
// Module Name: AD7606
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module AD7606(              
input        		     clk,         
input                    rst_n,               
input [15:0]             ad_data,          
input                    ad_busy,          
input                    first_data,       
output [2:0]             ad_os,            
output reg               ad_cs,            
output reg               ad_rd,            
output reg               ad_reset,         
output reg               ad_convst,         
output                   ad_range,
output                   ad_par_mode
    );

wire [2:0] 	ad_os_value;
wire       ad_range_value;
assign ad_os_value=0;   
assign ad_range_value=1; 

assign    ad_par_mode=0;

reg [15:0] ad_ch1;
reg [15:0] ad_ch2;
reg [15:0] ad_ch3;
reg [15:0] ad_ch4;
reg [15:0] ad_ch5;
reg [15:0] ad_ch6;
reg [15:0] ad_ch7;
reg [15:0] ad_ch8;   

reg [3:0] cnt;
reg [7:0] i;
reg [15:0] cnt5us;
reg [7:0] ad_state;
reg [7:0] rest_in_cnt;
reg rest_in;



assign ad_os=ad_os_value;  //�޹�����
assign ad_range = ad_range_value; //��10V��ֱ�����뷶Χ


always@(posedge clk)
begin
    if(rest_in_cnt<8'hff)
    begin    
        rest_in<= 1'b0;
        rest_in_cnt <= rest_in_cnt+1'b1;
    end
    else
        rest_in<= 1'b1;
end  

//ad��λ
always@(posedge clk)
begin        
    if(!rst_n)   
        ad_reset<=1'b0;            
    if(cnt<4'hf) 
    begin
        cnt<=cnt+1'b1;
        ad_reset<=1'b1;
    end
    else
        ad_reset<=1'b0;  //������ֹͣ��ad_reset���ͣ���λ����     
end       
	
//���ò���Ƶ��
always@ (posedge clk)   //200k������
begin
        if(!rst_n)
            cnt5us <= 16'd0;
        if((cnt5us < 16'd249)&&(cnt==4'hf))
            cnt5us <= cnt5us + 1'b1;
        else
            cnt5us <= 16'd0;
end

//״̬ѭ��
always @(posedge clk) 
begin
    if(!rst_n)
    begin
        ad_cs<=1'b1;
        ad_rd<=1'b1; 
        ad_convst<=1'b1;    
        i<=8'd0;   
        ad_ch1<=0;
        ad_ch2<=0;
        ad_ch3<=0;
        ad_ch4<=0;
        ad_ch5<=0;
        ad_ch6<=0;
        ad_ch7<=0;
        ad_ch8<=0;
        ad_state<=8'd0; 
    end
    else if(ad_reset)
    begin
        ad_cs<=1'b1;
        ad_rd<=1'b1; 
        ad_convst<=1'b1;    
        i<=8'd0;   
        ad_state<=8'd0; 
    end
    else        
    begin
        case(ad_state)     
		  8'd0: begin
                     ad_cs<=1'b1;
                     ad_rd<=1'b1; 
                     ad_convst<=1'b1;    
                     ad_state <= 8'd1;
		  end
		  
		8'd1: begin
                          if(i == 8'd5)            
                          begin
                              i<=8'd0;             
                              ad_state<=8'd2;
                          end
                          else 
                          begin
                              i<=i+1'b1;
                              ad_state<=8'd1;
                          end
                    end
                    
                    8'd2: begin       
                           if(i==8'd2)     
                           begin                        //�ȴ�2��lock��convstab���½�������Ϊ25ns����������Ҫ����ʱ��
                               i<=8'd0;             
                               ad_convst<=1'b1;
                               ad_state<=8'd3;                                          
                           end
                           else 
                           begin
                               i<=i+1'b1;
                               ad_convst<=1'b0;                     //����ADת��
                               ad_state<=8'd2;
                           end
                    end
                    
                    8'd3: begin            
                           if(i==8'd5) 
                           begin                           //�ȴ�5��clock, �ȴ�busy�ź�Ϊ��(tconv)
                               i<=8'd0;
                               ad_state<=8'd4;
                           end
                           else 
                           begin
                               i<=i+1'b1;
                               ad_state<=8'd3;
                           end
                    end        
                    
                    8'd4: begin            
                             if(!ad_busy) 
                             begin                    //�ȴ�busyΪ�͵�ƽ  ��ת��֮���ȡģʽ         
                                 ad_state<=8'd5;
                             end
                             else
                                 ad_state<=8'd4;
                    end    
                    
                    8'd5: begin 
                            ad_cs<=1'b0;                              //cs�ź���Ч  ֱ����ȡ8ͨ������  
                            ad_rd<=1'b0;                       
                            ad_state<=8'd6;  
                     end
                    
                    8'd6: begin            
                            ad_state<=8'd7;
                    end
                    
                    
                    8'd7: begin  
                            if(first_data)                       
                                ad_state<=8'd8;
                            else
                                ad_state<=8'd7;    
                     end
                     
                     8'd8: begin
                           if(i==8'd1)
                           begin 
                               ad_rd<=1'b1;
                               ad_ch1<=ad_data;                        //��CH1               
                               i<=8'd0;
                               ad_state<=8'd9;                 
                           end
                           else 
                           begin  
                               i<=i+1'b1;
                               ad_state<=8'd8; 
                           end
                     end
                     8'd9: begin
                           if(i==8'd1)
                           begin
                               ad_rd<=1'b0;              
                               i<=8'd0;
                               ad_state<=8'd10;                 
                           end
                           else 
                           begin  
                               i<=i+1'b1;
                               ad_state<=8'd9; 
                           end
                     end
                     
                     8'd10: begin 
                            if(i==8'd1)
                            begin
                                ad_rd<=1'b1;
                                ad_ch2<=ad_data;                        //��CH2
                                i<=8'd0;
                                ad_state<=8'd11;                 
                            end
                            else 
                            begin
                                i<=i+1'b1;
                                ad_state<=8'd10;
                            end
                    end
                    8'd11: begin 
                           if(i==8'd1) 
                            begin
                                ad_rd<=1'b0;
                                i<=8'd0;
                                ad_state<=8'd12;                 
                            end
                            else 
                            begin                           
                                i<=i+1'b1;
                                ad_state<=8'd11;  
                            end
                    end        
                      
                    8'd12: begin 
                            if(i==8'd1)
                            begin
                                ad_rd<=1'b1;
                                ad_ch3<=ad_data;                        //��CH3
                                i<=8'd0;
                                ad_state<=8'd13;                 
                            end
                            else 
                            begin    
                                i<=i+1'b1;
                                ad_state<=8'd12;
                            end
                    end
                    8'd13: begin 
                            if(i==8'd1)
                            begin
                                ad_rd<=1'b0;
                                i<=8'd0;
                                ad_state<=8'd14;                 
                            end
                            else 
                            begin                                 
                                i<=i+1'b1;
                                ad_state<=8'd13;
                            end
                    end
                    
                    8'd14: begin 
                            if(i==8'd1) 
                            begin
                                ad_rd<=1'b1;
                                ad_ch4<=ad_data;                        //��CH4
                                i<=8'd0;
                                ad_state<=8'd15;                 
                            end
                            else 
                            begin
                                i<=i+1'b1;
                                ad_state<=8'd14;
                            end
                    end
                    8'd15: begin 
                            if(i==8'd1) 
                            begin
                                ad_rd<=1'b0;
                                i<=8'd0;
                                ad_state<=8'd16;                 
                            end
                            else 
                            begin                           
                                i<=i+1'b1;
                                ad_state<=8'd15; 
                            end
                    end
                    
                    8'd16: begin 
                            if(i==8'd1) 
                            begin
                                ad_rd<=1'b1;
                                ad_ch5<=ad_data;                        //��CH5
                                i<=8'd0;
                                ad_state<=8'd17;                 
                            end
                            else 
                            begin
                                i<=i+1'b1;
                                ad_state<=8'd16;
                            end
                    end
                    8'd17: begin 
                            if(i==8'd1) 
                            begin
                                ad_rd<=1'b0;
                                i<=8'd0;
                                ad_state<=8'd18;                 
                            end
                            else 
                            begin                            
                                i<=i+1'b1;
                                ad_state<=8'd17; 
                            end
                    end
                    
                    8'd18: begin 
                            if(i==8'd1) 
                            begin
                                ad_rd<=1'b1;
                                ad_ch6<=ad_data;                        //��CH6
                                i<=8'd0;
                                ad_state<=8'd19;                 
                            end
                            else
                            begin
                                i<=i+1'b1;
                                ad_state<=8'd18;
                            end
                    end
                    8'd19: begin 
                            if(i==8'd1) 
                            begin
                                ad_rd<=1'b0;
                                i<=8'd0;
                                ad_state<=8'd20;                 
                            end
                            else
                            begin                          
                                i<=i+1'b1;
                                ad_state<=8'd19;
                            end
                    end
                    
                    8'd20: begin 
                           if(i==8'd1) 
                           begin
                               ad_rd<=1'b1;
                               ad_ch7<=ad_data;                        //��CH7
                               i<=8'd0;
                               ad_state<=8'd21;                 
                           end
                           else
                           begin
                               i<=i+1'b1;
                               ad_state<=8'd20;    
                           end
                    end
                    8'd21: begin 
                           if(i==8'd1) 
                           begin 
                               ad_rd<=1'b0;
                               i<=8'd0;
                               ad_state<=8'd22;                 
                           end
                           else
                           begin                           
                               i<=i+1'b1;
                               ad_state<=8'd21;
                           end
                    end
                    
                    8'd22: begin 
                            if(i==8'd1) 
                            begin
                                ad_rd<=1'b1;
                                ad_ch8<=ad_data;                        //��CH8
                                i<=8'd0;
                                ad_state<=8'd23;                 
                            end
                            else 
                            begin
                                i<=i+1'b1;
                                ad_state<=8'd22;    
                            end
                    end
            
                    8'd23: begin 
                    if(i==8'd1) 
                    begin
                        ad_rd<=1'b1;                      
                        i<=8'd0;
                        ad_state<=8'd24;                 
                    end
                    else 
                    begin                   
                        i<=i+1'b1;
                        ad_state<=8'd23;    
                    end
                    end
                    
                    8'd24: begin                                 //��ɶ����ص�idle״̬
                               ad_rd<=1'b1;     
                               ad_cs<=1'b1;
                               if(cnt5us == 16'd249)                      
                                  ad_state<=8'h0;
                               else
                                  ad_state<=8'd24;
                    end        
                    
                    default:    ad_state<=8'd0;
                    endcase    
              end      
                           
           end



  ila_0 u_ila(
  	.clk(clk),       // input wire clk
  	.probe0(ad_ch1), // input wire [15:0]  probe0  
  	.probe1(ad_ch2), // input wire [15:0]  probe1 
  	.probe2(ad_ch3), // input wire [15:0]  probe2 
  	.probe3(ad_ch4), // input wire [15:0]  probe3 
  	.probe4(ad_ch5), // input wire [15:0]  probe4 
  	.probe5(ad_ch6), // input wire [15:0]  probe5 
  	.probe6(ad_ch7), // input wire [15:0]  probe6 
  	.probe7(ad_ch8)  // input wire [15:0]  probe7
  ); 
                    
endmodule

