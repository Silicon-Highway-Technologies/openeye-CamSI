`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/09/28 14:21:36
// Design Name: 
// Module Name: LCD_TOP
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


module LCD_TOP(
    input                lcd_pclk,  
    input                rst_n,       //ϵͳ��λ
    //RGB LCD�ӿ�
    output               lcd_hs,      //LCD ��ͬ���ź�
    output               lcd_vs,      //LCD ��ͬ���ź�
    output               lcd_clk,     //LCD ����ʱ��
    inout        [23:0]  lcd_rgb,      //LCD RGB888��ɫ����
 
    output  [10:0]       h_disp,         //��ˮƽ�ֱ���  
    input   [15:0]       data_in,        //��������
    output               data_req        //������������       
    );                                                      
    

//parameter define  
// 4.3' 480*272
parameter  H_SYNC   =  11'd41;     //��ͬ��
parameter  H_BACK   =  11'd2;      //����ʾ����
parameter  H_DISP   =  11'd480;    //����Ч����
parameter  H_FRONT  =  11'd2;      //����ʾǰ��
parameter  H_TOTAL  =  11'd525;    //��ɨ������

parameter  V_SYNC   =  11'd10;     //��ͬ��
parameter  V_BACK   =  11'd2;      //����ʾ����
parameter  V_DISP   =  11'd272;    //����Ч����
parameter  V_FRONT  =  11'd2;      //����ʾǰ��
parameter  V_TOTAL  =  11'd286;    //��ɨ������
   
//parameter define  
parameter WHITE = 24'hFFFFFF;  //��ɫ
parameter BLACK = 24'h000000;  //��ɫ
parameter RED   = 24'hFF0000;  //��ɫ
parameter GREEN = 24'h00FF00;  //��ɫ
parameter BLUE  = 24'h0000FF;  //��ɫ

//reg define
reg  [10:0] h_sync ;
reg  [10:0] h_back ;
reg  [10:0] h_total;
reg  [10:0] v_sync ;
reg  [10:0] v_back ;
reg  [10:0] v_total;
reg  [10:0] h_cnt  ;
reg  [10:0] v_cnt  ;

//wire define    
wire        lcd_en;

wire      [23:0]  pixel_data;  //��������
wire      [10:0]  pixel_xpos;  //��ǰ���ص������
wire      [10:0]  pixel_ypos;  //��ǰ���ص�������   
reg       [10:0]  v_disp;      //LCD����ֱ�ֱ���  
//*****************************************************
//**                    main code
//*****************************************************
assign lcd_hs  = ( h_cnt < h_sync ) ? 1'b0 : 1'b1;  //��ͬ���źŸ�ֵ
assign lcd_vs  = ( v_cnt < v_sync ) ? 1'b0 : 1'b1;  //��ͬ���źŸ�ֵ
assign  lcd_clk = lcd_pclk;   //LCD����ʱ��
//RGB888�������
assign lcd_rgb = lcd_en ? pixel_data : 24'd0;
assign pixel_data  = {data_in[4:0],3'b000,data_in[10:5],2'b00, data_in[15:11],3'b000}; 
//ʹ��RGB888�������
assign  lcd_en = ((h_cnt >= h_sync + h_back) && (h_cnt < h_sync + h_back + h_disp)
                  && (v_cnt >= v_sync + v_back) && (v_cnt < v_sync + v_back + v_disp)) 
                  ? 1'b1 : 1'b0;

//�������ص���ɫ��������  
assign data_req = ((h_cnt >= h_sync + h_back - 1'b1) && (h_cnt < h_sync + h_back + h_disp - 1'b1)
                  && (v_cnt >= v_sync + v_back) && (v_cnt < v_sync + v_back + v_disp)) 
                  ? 1'b1 : 1'b0;
//���ص�����  
assign pixel_xpos = data_req ? (h_cnt - (h_sync + h_back - 1'b1)) : 11'd0;
assign pixel_ypos = data_req ? (v_cnt - (v_sync + v_back - 1'b1)) : 11'd0;

//�г�ʱ�����
always @(*) begin
            h_sync  = H_SYNC; 
            h_back  = H_BACK; 
            h_total = H_TOTAL;
            v_sync  = V_SYNC; 
            v_back  = V_BACK; 
            v_disp  = V_DISP; 
            v_total = V_TOTAL;   
end
assign h_disp = H_DISP;
//�м�����������ʱ�Ӽ���
always@ (posedge lcd_pclk or negedge rst_n) begin
    if(!rst_n) 
        h_cnt <= 11'd0;
    else begin
        if(h_cnt == h_total - 1'b1)
            h_cnt <= 11'd0;
        else
            h_cnt <= h_cnt + 1'b1;           
    end
end

//�����������м���
always@ (posedge lcd_pclk or negedge rst_n) begin
    if(!rst_n) 
        v_cnt <= 11'd0;
    else begin
        if(h_cnt == h_total - 1'b1) begin
            if(v_cnt == v_total - 1'b1)
                v_cnt <= 11'd0;
            else
                v_cnt <= v_cnt + 1'b1;    
        end
    end    
end


endmodule

