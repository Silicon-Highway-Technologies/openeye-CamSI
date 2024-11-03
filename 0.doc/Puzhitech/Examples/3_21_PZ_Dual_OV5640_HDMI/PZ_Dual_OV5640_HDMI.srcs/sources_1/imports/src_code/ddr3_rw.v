module ddr3_rw(  
        
    input           ui_clk               ,  //�û�ʱ��
    input           ui_clk_sync_rst      ,  //��λ,����Ч
    input           init_calib_complete  ,  //DDR3��ʼ�����
    input           app_rdy              ,  //MIG IP�˿���
    input           app_wdf_rdy          ,  //MIGдFIFO����
    input           app_rd_data_valid    ,  //��������Ч
    input   [255:0] app_rd_data          ,  //��������Ч    
    input   [10:0]  wfifo_rcount_1       ,  //д�˿�FIFO1�е�������
    input   [10:0]  rfifo_wcount_1       ,  //���˿�FIFO1�е�������
    input   [10:0]  wfifo_rcount_2       ,  //д�˿�FIFO2�е�������
    input   [10:0]  rfifo_wcount_2       ,  //���˿�FIFO2�е�������
    input           wr_load_1            ,  //����Դ1���ź�   
    input           wr_load_2            ,  //����Դ2���ź�     
    input           rd_load              ,  //���Դ���ź�
    input           wr_clk_2             ,  //����Դ1ʱ�� 
    input           wr_clk_1             ,  //����Դ2ʱ��  

    input   [27:0]  app_addr_rd_min      ,  //��DDR3����ʼ��ַ
    input   [27:0]  app_addr_rd_max      ,  //��DDR3�Ľ�����ַ
    input   [7:0]   rd_bust_len          ,  //��DDR3�ж�����ʱ��ͻ������
    input   [27:0]  app_addr_wr_min      ,  //дDDR3����ʼ��ַ
    input   [27:0]  app_addr_wr_max      ,  //дDDR3�Ľ�����ַ
    input   [7:0]   wr_bust_len          ,  //��DDR3��д����ʱ��ͻ������
        
    output          rfifo_wren_1         ,  //���˿�FIFO1�е�дʹ�� 
    output          rfifo_wren_2         ,  //���˿�FIFO1�е�дʹ�� 
    output  [255:0] rfifo_wdata_1        ,  //��ddr3��������Ч����1  
    output  [255:0] rfifo_wdata_2        ,  //��ddr3��������Ч����2 
    output          wfifo_rden_1         ,  //д�˿�FIFO1�еĶ�ʹ��
    output          wfifo_rden_2         ,  //д�˿�FIFO2�еĶ�ʹ��  
    output  [27:0]  app_addr             ,  //DDR3��ַ                 
    output          app_en               ,  //MIG IP�˲���ʹ��
    output          app_wdf_wren         ,  //�û�дʹ��   
    output          app_wdf_end          ,  //ͻ��д��ǰʱ�����һ������ 
    output  [2:0]   app_cmd                 //MIG IP�˲������������д                    
    );
    
//localparam 
localparam IDLE          = 7'b0000001;   //����״̬
localparam DDR3_DONE     = 7'b0000010;   //DDR3��ʼ�����״̬
localparam WRITE_1       = 7'b0000100;   //��FIFO����״̬
localparam READ_1        = 7'b0001000;   //дFIFO����״̬
localparam WRITE_2       = 7'b0010000;   //��FIFO����״̬
localparam READ_2        = 7'b0100000;   //дFIFO����״̬
localparam READ_WAIT     = 7'b1000000;   //дFIFO����״̬

//reg define
reg    [27:0] app_addr;               //DDR3��ַ 
reg    [27:0] app_addr_rd_1;          //DDR3����ַ
reg    [27:0] app_addr_wr_1;          //DDR3д��ַ
reg    [27:0] app_addr_rd_2;          //DDR3����ַ
reg    [27:0] app_addr_wr_2;          //DDR3д��ַ
reg    [6:0]  state_cnt;              //״̬������
reg    [23:0] rd_addr_cnt_1;          //�û�����ַ����
reg    [23:0] wr_addr_cnt_1;          //�û�д��ַ����  
reg    [23:0] rd_addr_cnt_2;          //�û�����ַ����
reg    [23:0] wr_addr_cnt_2;          //�û�д��ַ����  
reg    [10:0] raddr_rst_h_cnt;        //���Դ��֡��λ������м���
reg    [255:0]rfifo_wdata_1;          //��ddr3��������Ч����1 
reg    [255:0]rfifo_wdata_2;          //��ddr3��������Ч����2
reg    [7:0]  data_valid_cnt;         //��ddr3��������Ч����ʹ�ܼ�����
reg           rd_load_d0;
reg           rd_load_d1;
reg           raddr_rst_h;            //���Դ��֡��λ����
reg           wr_load_1_d0;
reg           wr_load_1_d1;
reg           wr_load_2_d0;
reg           wr_load_2_d1;
reg           wr_rst_1;               //����Դ1֡��λ��־
reg           wr_rst_2;               //����Դ2֡��λ��־
reg           rd_rst;                 //���Դ֡��λ��־
reg           raddr_page_1;           //ddr3Դ1����ַ�л��ź�
reg           waddr_page_1;           //ddr3Դ1д��ַ�л��ź�
reg           raddr_page_2;           //ddr3Դ2����ַ�л��ź�
reg           waddr_page_2;           //ddr3Դ2д��ַ�л��ź�
reg           rfifo_wren_1;           //���˿�FIFO1�е�дʹ��
reg           rfifo_wren_2;           //���˿�FIFO2�е�дʹ��
reg           rfifo_data_en_1;        //���˿�FIFO1����û��д���ʹ���ź�
reg           rfifo_data_en_2;        //���˿�FIFO2����û��д���ʹ���ź� 
reg           wr_load_1_d2;
reg           wr_load_2_d2;

//wire define
wire          rst_n;

 //*****************************************************
//**                    main code
//***************************************************** 

assign rst_n = ~ui_clk_sync_rst;

//��д״̬MIG������д��Ч,�����ڶ�״̬MIG���У���ʱʹ���ź�Ϊ�ߣ��������Ϊ��
assign app_en = ( ((state_cnt == READ_1 || state_cnt == READ_2 ) && app_rdy) 
                  || ((state_cnt == WRITE_1 || state_cnt == WRITE_2 ) 
                  && (app_rdy && app_wdf_rdy)) ) ? 1'b1:1'b0;
                
//��д״̬,MIG������д��Ч����ʱ����дʹ��
assign app_wdf_wren = ((state_cnt == WRITE_1 || state_cnt == WRITE_2 ) && (app_rdy && app_wdf_rdy)) ? 1'b1:1'b0;

assign wfifo_rden_1 = (state_cnt == WRITE_1  && (app_rdy && app_wdf_rdy)) ? 1'b1:1'b0;

assign wfifo_rden_2 = (state_cnt == WRITE_2 && (app_rdy && app_wdf_rdy)) ? 1'b1:1'b0;

//��������DDR3оƬʱ�Ӻ��û�ʱ�ӵķ�Ƶѡ��4:1��ͻ������Ϊ8���������ź���ͬ
assign app_wdf_end = app_wdf_wren; 

//���ڶ���ʱ������ֵΪ1������ʱ������ֵΪ0
assign app_cmd = (state_cnt == READ_1 || state_cnt == READ_2 ) ? 3'd1 :3'd0; 

//��DDR�����ݵ�����˽���ѡ��
always @(posedge ui_clk or negedge rst_n)  begin
    if(~rst_n || rd_rst)begin
        rfifo_wren_1 <= 0; 
        rfifo_wren_2 <= 0; 
        rfifo_wdata_1 <= 0;
        rfifo_wdata_2 <= 0;        
    end   
    else begin
        if(rfifo_data_en_1)begin
            rfifo_wren_1 <= app_rd_data_valid;
            rfifo_wdata_1 <= app_rd_data;
            rfifo_wren_2 <= 0;
            rfifo_wdata_2 <= 0;                        
        end
        else if(rfifo_data_en_2)begin
            rfifo_wren_2 <= app_rd_data_valid;
            rfifo_wdata_2 <= app_rd_data;           
            rfifo_wren_1 <= 0;
            rfifo_wdata_1 <= 0;                        
        end        
        else begin
            rfifo_wren_2 <= 0;
            rfifo_wdata_2 <= 0;
            rfifo_wren_1 <= 0;
            rfifo_wdata_1 <= 0;               
        end        
        
    end    
end 

//���˿�FIFO1����û��д���ʹ���ź� 
always @(posedge ui_clk or negedge rst_n)  begin
    if(~rst_n || rd_rst)begin
        rfifo_data_en_1 <= 0;    
    end   
    else begin
        if(state_cnt == DDR3_DONE  )
           rfifo_data_en_1 <= 0;
        else if(state_cnt == READ_1 ) 
           rfifo_data_en_1 <= 1; 
        else
           rfifo_data_en_1 <= rfifo_data_en_1;         
    end    
end 

//���˿�FIFO2����û��д���ʹ���ź� 
always @(posedge ui_clk or negedge rst_n)  begin
    if(~rst_n || rd_rst)begin
        rfifo_data_en_2 <= 0;    
    end   
    else begin
        if(state_cnt == DDR3_DONE)
           rfifo_data_en_2 <= 0;
        else if(state_cnt == READ_2 ) 
           rfifo_data_en_2 <= 1; 
        else
           rfifo_data_en_2 <= rfifo_data_en_2;         
    end    
end 

 //��ddr3��������Ч����ʹ�ܽ��м���
always @(posedge ui_clk or negedge rst_n)  begin
    if(~rst_n || rd_rst )begin
       data_valid_cnt <= 0;    
    end   
    else begin
        if(state_cnt == DDR3_DONE ) 
           data_valid_cnt <= 0;     
        else if(app_rd_data_valid)
           data_valid_cnt <= data_valid_cnt + 1;
        else
           data_valid_cnt <= data_valid_cnt;            
    end    
end 

//�����ݶ�д��ַ����ddr��ַ
always @(*)  begin
    if(~rst_n)
        app_addr <= 0;
    else if(state_cnt == READ_1 )
        app_addr <= {3'b0,raddr_page_1,1'b0,app_addr_rd_1[22:0]};
    else if(state_cnt == READ_2 )
        app_addr <= {3'b1,raddr_page_2,1'b0,app_addr_rd_2[22:0]};
    else if(state_cnt == WRITE_1 )
        app_addr <= {3'b0,waddr_page_1,1'b0,app_addr_wr_1[22:0]};        
    else
        app_addr <= {3'b1,waddr_page_2,1'b0,app_addr_wr_2[22:0]};
end  

//���źŽ��д��Ĵ���
always @(posedge ui_clk or negedge rst_n)  begin
    if(~rst_n)begin
        rd_load_d0 <= 0;
        rd_load_d1 <= 0; 
        wr_load_1_d0 <= 0; 
        wr_load_1_d1 <= 0;   
        wr_load_2_d0 <= 0; 
        wr_load_2_d1 <= 0;        
    end   
    else begin
        rd_load_d0 <= rd_load;
        rd_load_d1 <= rd_load_d0; 
        wr_load_1_d0 <= wr_load_1; 
        wr_load_1_d1 <= wr_load_1_d0; 
        wr_load_2_d0 <= wr_load_2; 
        wr_load_2_d1 <= wr_load_2_d0;         
    end    
end 

//������Դ1����֡��λ��־
always @(posedge ui_clk or negedge rst_n)  begin
    if(~rst_n)
        wr_rst_1 <= 0;                
    else if(wr_load_1_d0 && !wr_load_1_d1)
        wr_rst_1 <= 1;               
    else
        wr_rst_1 <= 0;           
end

//������Դ2����֡��λ��־
always @(posedge ui_clk or negedge rst_n)  begin
    if(~rst_n)
        wr_rst_2 <= 0;                
    else if(wr_load_2_d0 && !wr_load_2_d1)
        wr_rst_2 <= 1;               
    else
        wr_rst_2 <= 0;           
end
 
//�����Դ����֡��λ��־ 
always @(posedge ui_clk or negedge rst_n)  begin
    if(~rst_n)
        rd_rst <= 0;                
    else if(rd_load_d0 && !rd_load_d1)
        rd_rst <= 1;               
    else
        rd_rst <= 0;           
end

//�����Դ�Ķ���ַ����֡��λ���� 
always @(posedge ui_clk or negedge rst_n)  begin
    if(~rst_n)
        raddr_rst_h <= 1'b0;
    else if(rd_load_d0 && !rd_load_d1)
        raddr_rst_h <= 1'b1;
    else if((state_cnt == READ_1) || (state_cnt == READ_2))   
        raddr_rst_h <= 1'b0;
    else
        raddr_rst_h <= raddr_rst_h;              
end 

//�����Դ��֡��λ������м��� 
always @(posedge ui_clk or negedge rst_n)  begin
    if(~rst_n)
        raddr_rst_h_cnt <= 11'b0;
    else if(raddr_rst_h)
        if(raddr_rst_h_cnt >= 1000)
            raddr_rst_h_cnt <= raddr_rst_h_cnt; 
        else            
            raddr_rst_h_cnt <= raddr_rst_h_cnt + 1'b1;
    else
        raddr_rst_h_cnt <= 11'b0;            
end 

//�����Դ֡�Ķ���ַ��λ�л�
always @(posedge ui_clk or negedge rst_n)  begin
    if(~rst_n)
        raddr_page_1 <= 1'b0;
    else if(rd_rst)
        raddr_page_1 <= ~waddr_page_1;         
    else
        raddr_page_1 <= raddr_page_1;           
end 

//�����Դ֡�Ķ���ַ��λ�л�
always @(posedge ui_clk or negedge rst_n)  begin
    if(~rst_n)
        raddr_page_2 <= 1'b0;
    else if(rd_rst)
        raddr_page_2 <= ~waddr_page_2;         
    else
        raddr_page_2 <= raddr_page_2;           
end
  
//������Դ1֡��д��ַ��λ�л�
always @(posedge ui_clk or negedge rst_n)  begin
    if(~rst_n)
        waddr_page_1 <= 1'b1;
    else if(wr_rst_1)
        waddr_page_1 <= ~waddr_page_1 ;         
    else
        waddr_page_1 <= waddr_page_1;           
end   

//������Դ1֡��д��ַ��λ�л�
always @(posedge ui_clk or negedge rst_n)  begin
    if(~rst_n)
        waddr_page_2 <= 1'b1;
    else if(wr_rst_2)
        waddr_page_2 <= ~waddr_page_2 ;         
    else
        waddr_page_2 <= waddr_page_2;           
end 
  
 
//DDR3��д�߼�ʵ��
always @(posedge ui_clk or negedge rst_n) begin
    if(~rst_n) begin 
        state_cnt    <= IDLE;              
        wr_addr_cnt_1  <= 24'd0;      
        rd_addr_cnt_1  <= 24'd0;       
        app_addr_wr_1  <= 28'd0;   
        app_addr_rd_1  <= 28'd0; 
        wr_addr_cnt_2  <= 24'd0;      
        rd_addr_cnt_2  <= 24'd0;       
        app_addr_wr_2  <= 28'd0;   
        app_addr_rd_2  <= 28'd0;         
    end
    else begin
        case(state_cnt)
            IDLE:begin
                if(init_calib_complete)
                    state_cnt <= DDR3_DONE ;
                else
                    state_cnt <= IDLE;
            end
            DDR3_DONE:begin  //��wfifo1�洢���ݳ���һ��ͻ������ʱ������д����1
                if(wfifo_rcount_1 >= wr_bust_len - 2 )begin  
                    state_cnt <= WRITE_1;                    
                end         //��wfifo2�洢���ݳ���һ��ͻ������ʱ������д����2 
                else if(wfifo_rcount_2 >= wr_bust_len - 2 )begin 
                    state_cnt <= WRITE_2;                    
                end                
                else if(raddr_rst_h)begin         //��֡��λ����ʱ���ԼĴ������и�λ 
                    if(raddr_rst_h_cnt >= 1000 )begin 
                        state_cnt <= READ_1;      //��֤��fifo�ڸ�λʱ������ж�����             
                    end
                    else begin
                        state_cnt <= DDR3_DONE;                      
                    end                                
                end //��rfifo1�洢���������趨��ֵʱ����������Դ1�Ѿ�д��ddr 1֡����                                    
                else if(rfifo_wcount_1 < 5  )begin  //����������1 
                    state_cnt <= READ_1;                                                 
                end //��rfifo1�洢���������趨��ֵʱ����������Դ1�Ѿ�д��ddr 1֡����                                    
                else if(rfifo_wcount_2 < 5  )begin  //����������2 
                    state_cnt <= READ_2;                                                                                        
                end  			                                                                                                
                else begin
                    state_cnt <= state_cnt;                      
                end
                              
                if(raddr_rst_h)begin        //��֡��λ����ʱ�����źŽ��и�λ        
                    rd_addr_cnt_1  <= 24'd0;      
                    app_addr_rd_1 <= app_addr_rd_min; 
                    rd_addr_cnt_2  <= 24'd0;      
                    app_addr_rd_2 <= app_addr_rd_min;                                                        
                end //��rfifo1�洢���������趨��ֵʱ����������Դ1�Ѿ�д��ddr 1֡���� 
                else if(rfifo_wcount_1 < 5 )begin             
                    rd_addr_cnt_1 <= 24'd0;            //����������
                    app_addr_rd_1 <= app_addr_rd_1;    //����ַ���ֲ���
                end //��rfifo1�洢���������趨��ֵʱ����������Դ1�Ѿ�д��ddr 1֡���� 
                else if(rfifo_wcount_2 < 5  )begin             
                    rd_addr_cnt_2 <= 24'd0;            //����������
                    app_addr_rd_2 <= app_addr_rd_2;    //����ַ���ֲ���
                end  			                                                                                                
                else begin
                    wr_addr_cnt_1  <= 24'd0;      
                    rd_addr_cnt_1  <= 24'd0;                     
                end                
  
                if(wr_rst_2)begin             //��֡��λ����ʱ�����źŽ��и�λ
                    wr_addr_cnt_2  <= 24'd0;	
                    app_addr_wr_2 <= app_addr_wr_min;					
			    end                    //��wfifo�洢���ݳ���һ��ͻ������ʱ
                else if(wfifo_rcount_2 >= wr_bust_len - 2 )begin  
                    wr_addr_cnt_2  <= 24'd0;                   //����������    
                    app_addr_wr_2 <= app_addr_wr_2;            //д��ַ���ֲ���
                 end 
                 else begin
                    wr_addr_cnt_2  <= wr_addr_cnt_2;
                    app_addr_wr_2  <= app_addr_wr_2;                  
                 end 
  
                 if(wr_rst_1)begin               //��֡��λ����ʱ�����źŽ��и�λ
                    wr_addr_cnt_1  <= 24'd0;	
                    app_addr_wr_1 <= app_addr_wr_min;					
			    end                  //��wfifo�洢���ݳ���һ��ͻ������ʱ
                else if(wfifo_rcount_1 >= wr_bust_len - 2 )begin  
                    wr_addr_cnt_1  <= 24'd0;                   //����������     
                    app_addr_wr_1 <= app_addr_wr_1;            //д��ַ���ֲ���
                 end 
                 else begin
                    wr_addr_cnt_1  <= wr_addr_cnt_1;
                    app_addr_wr_1  <= app_addr_wr_1;                  
                 end
                
            end    
            WRITE_1:   begin 
                if((wr_addr_cnt_1 == (wr_bust_len - 1)) && 
                   (app_rdy && app_wdf_rdy))begin        //д���趨�ĳ��������ȴ�״̬                  
                    state_cnt    <= DDR3_DONE;           //д���趨�ĳ��������ȴ�״̬               
                    app_addr_wr_1 <= app_addr_wr_1 + 8;   //һ����д��8�������ʼ�8
                end       
                else if(app_rdy && app_wdf_rdy)begin       //д��������
                    wr_addr_cnt_1  <= wr_addr_cnt_1 + 1'd1;//д��ַ�������Լ�
                    app_addr_wr_1  <= app_addr_wr_1 + 8;   //һ����д��8�������ʼ�8
                end
                else begin                                 //д���������㣬���ֵ�ǰֵ     
                    wr_addr_cnt_1  <= wr_addr_cnt_1;
                    app_addr_wr_1  <= app_addr_wr_1; 
                end
            end
            WRITE_2:   begin 
                if((wr_addr_cnt_2 == (wr_bust_len - 1)) && 
                   (app_rdy && app_wdf_rdy))begin         //д���趨�ĳ��������ȴ�״̬                  
                    state_cnt    <= DDR3_DONE;            //д���趨�ĳ��������ȴ�״̬               
                    app_addr_wr_2 <= app_addr_wr_2 + 8;   //һ����д��8�������ʼ�8
                end       
                else if(app_rdy && app_wdf_rdy)begin      //д��������
                    wr_addr_cnt_2  <= wr_addr_cnt_2 + 1'd1; //д��ַ�������Լ�
                    app_addr_wr_2  <= app_addr_wr_2 + 8; //һ����д��8�������ʼ�8
                end
                else begin                              //д���������㣬���ֵ�ǰֵ     
                    wr_addr_cnt_2  <= wr_addr_cnt_2;
                    app_addr_wr_2  <= app_addr_wr_2; 
                end
            end            
            READ_1:begin                                  //�����趨�ĵ�ַ����    
                if((rd_addr_cnt_1 == (rd_bust_len - 1)) && app_rdy)begin
                    state_cnt   <= READ_WAIT;             //����������״̬ 
                    app_addr_rd_1 <= app_addr_rd_1 + 8;
                end       
                else if(app_rdy)begin                   //��MIG�Ѿ�׼����,��ʼ��
                    rd_addr_cnt_1 <= rd_addr_cnt_1 + 1'd1; //�û���ַ������ÿ�μ�һ
                    app_addr_rd_1 <= app_addr_rd_1 + 8; //һ���Զ���8����,DDR3��ַ��8
                end
                else begin                               //��MIGû׼����,�򱣳�ԭֵ
                    rd_addr_cnt_1 <= rd_addr_cnt_1;
                    app_addr_rd_1 <= app_addr_rd_1; 
                end
                
                if(wr_rst_2)begin                    //��֡��λ����ʱ�����źŽ��и�λ
                    wr_addr_cnt_2  <= 24'd0;	
                    app_addr_wr_2 <= app_addr_wr_min;					
			    end 
                 else begin
                    wr_addr_cnt_2  <= wr_addr_cnt_2;
                    app_addr_wr_2  <= app_addr_wr_2;                  
                 end 
 
                 if(wr_rst_1)begin                   //��֡��λ����ʱ�����źŽ��и�λ
                    wr_addr_cnt_1  <= 24'd0;	
                    app_addr_wr_1 <= app_addr_wr_min;					
			    end 
                 else begin
                    wr_addr_cnt_1  <= wr_addr_cnt_1;
                    app_addr_wr_1  <= app_addr_wr_1;                  
                 end			    
            end 
            READ_2:begin                         //�����趨�ĵ�ַ����    
                if((rd_addr_cnt_2 == (rd_bust_len - 1)) && app_rdy)begin
                    state_cnt   <= READ_WAIT;             //����������״̬ 
                    app_addr_rd_2 <= app_addr_rd_2 + 8;
                end       
                else if(app_rdy)begin                      //��MIG�Ѿ�׼����,��ʼ��
                    rd_addr_cnt_2 <= rd_addr_cnt_2 + 1'd1; //�û���ַ������ÿ�μ�һ
                    app_addr_rd_2 <= app_addr_rd_2 + 8; //һ���Զ���8����,DDR3��ַ��8
                end
                else begin                                 //��MIGû׼����,�򱣳�ԭֵ
                    rd_addr_cnt_2 <= rd_addr_cnt_2;
                    app_addr_rd_2 <= app_addr_rd_2; 
                end
                
                 if(wr_rst_2)begin                  //��֡��λ����ʱ�����źŽ��и�λ
                    wr_addr_cnt_2  <= 24'd0;	
                    app_addr_wr_2 <= app_addr_wr_min;					
			    end 
                 else begin
                    wr_addr_cnt_2  <= wr_addr_cnt_2;
                    app_addr_wr_2  <= app_addr_wr_2;                  
                 end 
 
                 if(wr_rst_1)begin                   //��֡��λ����ʱ�����źŽ��и�λ
                    wr_addr_cnt_1  <= 24'd0;	
                    app_addr_wr_1 <= app_addr_wr_min;					
			    end 
                 else begin
                    wr_addr_cnt_1  <= wr_addr_cnt_1;
                    app_addr_wr_1  <= app_addr_wr_1;                  
                 end                
            end
            READ_WAIT:begin       //�Ƶ��趨�ĵ�ַ����    
                if((data_valid_cnt >= rd_bust_len - 1) && app_rd_data_valid)begin
                    state_cnt   <= DDR3_DONE;             //����������״̬ 
                end       
                else begin                               
                    state_cnt   <= READ_WAIT;
                end
            end            
            default:begin
                    state_cnt    <= IDLE;              
                    wr_addr_cnt_1  <= 24'd0;      
                    rd_addr_cnt_1  <= 24'd0;       
                    app_addr_wr_1  <= 28'd0;   
                    app_addr_rd_1  <= 28'd0; 
                    wr_addr_cnt_2  <= 24'd0;      
                    rd_addr_cnt_2  <= 24'd0;       
                    app_addr_wr_2  <= 28'd0;   
                    app_addr_rd_2  <= 28'd0;   
            end
        endcase
    end
end                          

endmodule