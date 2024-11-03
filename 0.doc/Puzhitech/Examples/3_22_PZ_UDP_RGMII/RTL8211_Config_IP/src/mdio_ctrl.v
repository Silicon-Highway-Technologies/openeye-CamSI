
module mdio_ctrl#(
    parameter tx_delay=1'b1,
    parameter rx_delay=1'b1
)
(
    input                clk           ,
    input                rst_n         ,
    input                op_done       , //��д���
    input        [15:0]  op_rd_data    , //����������
    input                op_rd_ack     , //��Ӧ���ź� 0:Ӧ�� 1:δӦ��
    output  reg  [4:0]   phy_addr       ,
    output  reg          op_exec       , //������ʼ�ź�
    output  reg          op_rh_wl      , //�͵�ƽд���ߵ�ƽ��
    output  reg  [4:0]   op_addr       , //�Ĵ�����ַ
    output  reg  [15:0]  op_wr_data     //д��Ĵ���������
    );

//reg define

reg  [23:0]  timer_cnt;       //��ʱ������ 
reg          timer_done;      //��ʱ����ź�
reg          link_error;      //��·�Ͽ�������Э��δ���
reg  [5:0]   flow_cnt;        //���̿��Ƽ����� 



//��ʱ����
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        timer_cnt <= 1'b0;
        timer_done <= 1'b0;
    end
    else begin
        if(timer_cnt == 24'd1_000_000 - 1'b1) begin
            timer_done <= 1'b1;
            timer_cnt <= 1'b0;
        end
        else begin
            timer_done <= 1'b0;
            timer_cnt <= timer_cnt + 1'b1;
        end
    end
end    

//������λ�źŶ�MDIO�ӿڽ�����λ,����ʱ��ȡ��̫��������״̬
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        flow_cnt <=0;
        phy_addr <=0;
        op_exec <= 1'b0; 
        op_rh_wl <= 1'b0; 
        op_addr <= 1'b0;       
        op_wr_data <= 1'b0; 
        link_error <= 1'b0;
    end
    else begin
        op_exec <= 1'b0;                     
        case(flow_cnt)
            0:begin
                op_exec <= 1'b1; 
                phy_addr<=0;
                op_rh_wl <= 1'b0; 
                op_addr <= 5'h00; 
                op_wr_data <= 16'hB100;    //Bit[15]=1'b1,��ʾ��λ
                flow_cnt <= flow_cnt+1;    
            end
            1: begin if(op_done)  flow_cnt <= flow_cnt+1;  end  
            2:begin
                    op_exec <= 1'b1; 
                    op_rh_wl <= 1'b1; 
                    op_addr <= 5'h01; 
                    flow_cnt <= flow_cnt+1; 
            end   
            3: begin                       
                if(op_done) begin              //MDIO�ӿڶ��������
                    if(op_rd_ack == 1'b0 ) //����һ���Ĵ������ӿڳɹ�Ӧ��
                       flow_cnt <= flow_cnt+1; 
                    else begin
                        flow_cnt <= 2;
                        phy_addr<=phy_addr+1;
                     end
                end    
            end
            4: begin      
                if(op_rd_data[5] == 1'b1 && op_rd_data[2] == 1'b1)begin
                    link_error <= 0;
                    flow_cnt <= flow_cnt+1; 
                end
                else begin
                    link_error <= 1'b1; 
                    flow_cnt <= 2;     
               end           
            end     
            5:begin
                    op_exec <= 1'b1; 
                    op_rh_wl <= 1'b1; 
                    op_addr <= 5'h02; 
                    flow_cnt <= flow_cnt+1; 
            end   
            6: begin                       
                if(op_done) begin             
                    if(op_rd_ack == 1'b0 ) 
                       flow_cnt <= flow_cnt+1; 
                    else begin
                        flow_cnt <= 0;
                     end
                end    
            end
            7: begin      
                if(op_rd_data== 16'h001c)begin
                     flow_cnt <= flow_cnt+1; 
                end
                else begin
                     flow_cnt <= 4;     
               end           
            end               
            8:begin
                op_exec <= 1'b1; 
                op_rh_wl <= 1'b0; 
                op_addr <= 5'h1f; 
                op_wr_data <= 16'h0d08;    
               flow_cnt <= flow_cnt+1; 
            end
             9: begin if(op_done)  flow_cnt <= flow_cnt+1;  end  
             10: begin
                op_exec <= 1'b1; 
                op_rh_wl <= 1'b0; 
                op_addr <= 5'h11; 
                op_wr_data <= {7'h0,tx_delay,8'h09}; 
               flow_cnt <= flow_cnt+1; 
            end             
            11: begin if(op_done)  flow_cnt <=flow_cnt+1;     end    
            12:begin
                op_exec <= 1'b1; 
                op_rh_wl <= 1'b0; 
                op_addr <= 5'h1f; 
                op_wr_data <= 16'h0d08;    
                flow_cnt <= flow_cnt+1;    
            end
             13: begin if(op_done) flow_cnt <= flow_cnt+1; end  
             14: begin
                op_exec <= 1'b1; 
                op_rh_wl <= 1'b0; 
                op_addr <= 5'h15; 
                op_wr_data <= {12'h01,rx_delay,3'h001}; 
                flow_cnt <= flow_cnt+1; 
            end             
            15: begin if(op_done)  flow_cnt <=flow_cnt+1;   end   
            16:begin
               if(timer_done) begin      //��ʱ���,��ȡ��̫������״̬
                    op_exec <= 1'b1; 
                    op_rh_wl <= 1'b1; 
                    op_addr <= 5'h01; 
                    flow_cnt <= flow_cnt+1; 
                end 
            end   
            17: begin                       
                if(op_done) begin              //MDIO�ӿڶ��������
                    if(op_rd_ack == 1'b0 ) //����һ���Ĵ������ӿڳɹ�Ӧ��
                       flow_cnt <= flow_cnt+1; 
                    else begin
                        flow_cnt <= 0;
                     end
                end    
            end
            18: begin      
                if(op_rd_data[5] == 1'b1 && op_rd_data[2] == 1'b1)begin
                    link_error <= 0;
                    flow_cnt <= 8;    
                end
                else begin
                    link_error <= 1'b1; 
                    flow_cnt <= 0;     
               end           
            end  
            default:begin
                 flow_cnt <=0;
                 phy_addr<=0;
                op_exec <= 1'b0; 
                op_rh_wl <= 1'b0; 
                op_addr <= 1'b0;       
                op_wr_data <= 1'b0; 
                link_error <= 1'b0;        
            end                      
        endcase
    end    
end 

    
endmodule
