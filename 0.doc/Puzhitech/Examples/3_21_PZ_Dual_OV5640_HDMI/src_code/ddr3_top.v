module ddr3_top(
    input              clk_200m             ,  //ddr3�ο�ʱ��
    input              sys_rst_n           ,   //��λ,����Ч
    input              sys_init_done       ,   //ϵͳ��ʼ�����               
    //DDR3�ӿ��ź�                           
    input   [27:0]     app_addr_rd_min     ,   //��ddr3����ʼ��ַ
    input   [27:0]     app_addr_rd_max     ,   //��ddr3�Ľ�����ַ
    input   [7:0]      rd_bust_len         ,   //��ddr3�ж�����ʱ��ͻ������
    input   [27:0]     app_addr_wr_min     ,   //��ddr3����ʼ��ַ
    input   [27:0]     app_addr_wr_max     ,   //��ddr3�Ľ�����ַ
    input   [7:0]      wr_bust_len         ,   //��ddr3�ж�����ʱ��ͻ������
    // DDR3 IO�ӿ� 
    inout   [31:0]     ddr3_dq             ,   //ddr3 ����
    inout   [3:0]      ddr3_dqs_n          ,   //ddr3 dqs��
    inout   [3:0]      ddr3_dqs_p          ,   //ddr3 dqs��  
    output  [13:0]     ddr3_addr           ,   //ddr3 ��ַ   
    output  [2:0]      ddr3_ba             ,   //ddr3 banck ѡ��
    output             ddr3_ras_n          ,   //ddr3 ��ѡ��
    output             ddr3_cas_n          ,   //ddr3 ��ѡ��
    output             ddr3_we_n           ,   //ddr3 ��дѡ��
    output             ddr3_reset_n        ,   //ddr3 ��λ
    output  [0:0]      ddr3_ck_p           ,   //ddr3 ʱ����
    output  [0:0]      ddr3_ck_n           ,   //ddr3 ʱ�Ӹ�
    output  [0:0]      ddr3_cke            ,   //ddr3 ʱ��ʹ��
    output  [0:0]      ddr3_cs_n           ,   //ddr3 Ƭѡ
    output  [3:0]      ddr3_dm             ,   //ddr3_dm
    output  [0:0]      ddr3_odt            ,   //ddr3_odt      
    //�û�
    input              wr_clk_1            ,   //wfifoʱ��
    input              datain_valid_1      ,   //������Чʹ���ź�
    input   [15:0]     datain_1            ,   //��Ч���� 
    input              wr_load_1          ,    //����Դ���ź�    
    input              wr_clk_2            ,   //wfifoʱ��
    input              datain_valid_2      ,   //������Чʹ���ź�
    input   [15:0]     datain_2            ,   //��Ч���� 
    input              wr_load_2          ,    //����Դ���ź�
    
    input   [12:0]     h_disp              ,   //����ͷˮƽ�ֱ��� 
    input              rd_clk              ,   //rfifo�Ķ�ʱ��      
    input              rdata_req           ,   //�������ص���ɫ��������  
    input              rd_load            ,    //���Դ���ź�
    output  [15:0]     dataout             ,   //rfifo�������
    output             init_calib_complete     //ddr3��ʼ������ź�


    );                
                      
 //wire define  
wire                  ui_clk               ;   //�û�ʱ��
wire [27:0]           app_addr             ;   //ddr3 ��ַ
wire [2:0]            app_cmd              ;   //�û���д����
wire                  app_en               ;   //MIG IP��ʹ��
wire                  app_rdy              ;   //MIG IP�˿���
wire [255:0]          app_rd_data          ;   //�û�������
wire                  app_rd_data_end      ;   //ͻ������ǰʱ�����һ������ 
wire                  app_rd_data_valid    ;   //��������Ч
wire [255:0]          app_wdf_data         ;   //�û�д���� 
wire                  app_wdf_end          ;   //ͻ��д��ǰʱ�����һ������ 
wire [31:0]           app_wdf_mask         ;   //д��������                           
wire                  app_wdf_rdy          ;   //д����                               
wire                  app_sr_active        ;   //����                                 
wire                  app_ref_ack          ;   //ˢ������                             
wire                  app_zq_ack           ;   //ZQ У׼����                          
wire                  app_wdf_wren         ;   //ddr3 дʹ��                          
wire                  clk_ref_i            ;   //ddr3�ο�ʱ��                         
wire                  sys_clk_i            ;   //MIG IP������ʱ��                     
wire                  ui_clk_sync_rst      ;   //�û���λ�ź�                         
wire [20:0]           rd_cnt               ;   //ʵ�ʶ���ַ����                       
wire [3 :0]           state_cnt            ;   //״̬������                           
wire [23:0]           rd_addr_cnt          ;   //�û�����ַ������                     
wire [23:0]           wr_addr_cnt          ;   //�û�д��ַ������                     
wire                  rfifo_wren           ;   //��ddr3�������ݵ���Чʹ�� 
wire [255:0]          rfifo_wdata_1        ;   //rfifo1��������  
wire [255:0]          rfifo_wdata_2        ;   //rfifo2��������                                                                                    
wire [10:0]           wfifo_rcount_1       ;   //wfifo1ʣ�����ݼ��� 
wire [10:0]           wfifo_rcount_2       ;   //wfifo2ʣ�����ݼ��� 
wire [10:0]           rfifo_wcount_1       ;   //rfifo1д�����ݼ���
wire [10:0]           rfifo_wcount_2       ;   //rfifo2д�����ݼ���                                                                                     
//*****************************************************                               
//**                    main code                                                     
//*****************************************************                               
                                                                                      
//��дģ��                                                                            
 ddr3_rw u_ddr3_rw(                                                                   
    .ui_clk               (ui_clk)              ,                                     
    .ui_clk_sync_rst      (ui_clk_sync_rst)     ,                                      
    //MIG �ӿ�                                                                        
    .init_calib_complete  (init_calib_complete) ,   //ddr3��ʼ������ź�                                   
    .app_rdy              (app_rdy)             ,   //MIG IP�˿���                                   
    .app_wdf_rdy          (app_wdf_rdy)         ,   //д����                                   
    .app_rd_data_valid    (app_rd_data_valid)   ,   //��������Ч 
    .app_rd_data          (app_rd_data)         ,   //������           
    .app_addr             (app_addr)            ,   //ddr3 ��ַ                                   
    .app_en               (app_en)              ,   //MIG IP��ʹ��                                   
    .app_wdf_wren         (app_wdf_wren)        ,   //ddr3 дʹ��                                    
    .app_wdf_end          (app_wdf_end)         ,   //ͻ��д��ǰʱ�����һ������                                   
    .app_cmd              (app_cmd)             ,   //�û���д����                                                                                                                        
    //DDR3 ��ַ����                                                                   
    .app_addr_rd_min      (app_addr_rd_min)     ,   //��ddr3����ʼ��ַ                                  
    .app_addr_rd_max      (app_addr_rd_max)     ,   //��ddr3�Ľ�����ַ                                  
    .rd_bust_len          (rd_bust_len)         ,   //��ddr3�ж�����ʱ��ͻ������                                  
    .app_addr_wr_min      (app_addr_wr_min)     ,   //дddr3����ʼ��ַ                                  
    .app_addr_wr_max      (app_addr_wr_max)     ,   //дddr3�Ľ�����ַ                                  
    .wr_bust_len          (wr_bust_len)         ,   //��ddr3��д����ʱ��ͻ������                                  
    //�û��ӿ�                                                                        
    .rfifo_wren_1         (rfifo_wren_1)        ,   //rfifoдʹ�� 
    .rfifo_wdata_1        (rfifo_wdata_1)       ,   //rfifoд���� 
    .rfifo_wren_2         (rfifo_wren_2)        ,   //rfifoдʹ��  
    .rfifo_wdata_2        (rfifo_wdata_2)       ,   //rfifoд����
    .wfifo_rden_1         (wfifo_rden_1)        ,   //д�˿�FIFO1�еĶ�ʹ��
    .wfifo_rden_2         (wfifo_rden_2)        ,   //д�˿�FIFO2�еĶ�ʹ��  
    .rd_load              (rd_load)             ,   //���Դ���ź�
    .wr_load_1            (wr_load_1)           ,   //����Դ���ź�
    .wr_load_2            (wr_load_2)           ,   //����Դ���ź�    
    .wfifo_rcount_1       (wfifo_rcount_1)      ,   //rfifoʣ�����ݼ���                  
    .rfifo_wcount_1       (rfifo_wcount_1)      ,   //wfifoд�����ݼ���
    .wfifo_rcount_2       (wfifo_rcount_2)      ,   //rfifoʣ�����ݼ���                  
    .rfifo_wcount_2       (rfifo_wcount_2)      ,   //wfifoд�����ݼ���   
    .wr_clk_2             (wr_clk_2)            ,   //wfifoʱ�� 
    .wr_clk_1             (wr_clk_1)                //wfifoʱ��          
    );
    
//MIG IP��ģ��
mig_7series_0 u_mig_7series_0 (
    // Memory interface ports
    .ddr3_addr           (ddr3_addr)            ,         
    .ddr3_ba             (ddr3_ba)              ,            
    .ddr3_cas_n          (ddr3_cas_n)           ,         
    .ddr3_ck_n           (ddr3_ck_n)            ,        
    .ddr3_ck_p           (ddr3_ck_p)            ,          
    .ddr3_cke            (ddr3_cke)             ,            
    .ddr3_ras_n          (ddr3_ras_n)           ,         
    .ddr3_reset_n        (ddr3_reset_n)         ,      
    .ddr3_we_n           (ddr3_we_n)            ,        
    .ddr3_dq             (ddr3_dq)              ,            
    .ddr3_dqs_n          (ddr3_dqs_n)           ,        
    .ddr3_dqs_p          (ddr3_dqs_p)           ,                                                       
	.ddr3_cs_n           (ddr3_cs_n)            ,                         
    .ddr3_dm             (ddr3_dm)              ,    
    .ddr3_odt            (ddr3_odt)             ,          
    // Application interface ports                                        
    .app_addr            (app_addr)             ,         
    .app_cmd             (app_cmd)              ,          
    .app_en              (app_en)               ,        
    .app_wdf_data        (app_wdf_data)         ,      
    .app_wdf_end         (app_wdf_end)          ,       
    .app_wdf_wren        (app_wdf_wren)         ,           
    .app_rd_data         (app_rd_data)          ,       
    .app_rd_data_end     (app_rd_data_end)      ,                                        
    .app_rd_data_valid   (app_rd_data_valid)    ,     
    .init_calib_complete (init_calib_complete)  ,            
                                                     
    .app_rdy             (app_rdy)              ,      
    .app_wdf_rdy         (app_wdf_rdy)          ,          
    .app_sr_req          ()                     ,                    
    .app_ref_req         ()                     ,              
    .app_zq_req          ()                     ,             
    .app_sr_active       (app_sr_active)        ,        
    .app_ref_ack         (app_ref_ack)          ,         
    .app_zq_ack          (app_zq_ack)           ,             
    .ui_clk              (ui_clk)               ,                
    .ui_clk_sync_rst     (ui_clk_sync_rst)      ,                                               
    .app_wdf_mask        (31'b0)                ,    
    // System Clock Ports                            
    .sys_clk_i           (clk_200m)             ,    
    // Reference Clock Ports                         
    .sys_rst             (sys_rst_n)                 
    );                                               
                                                     

ddr3_fifo_ctrl_top u_ddr3_fifo_ctrl_top(
    .rst_n             (sys_rst_n &&sys_init_done),  //��λ�ź�    
    .rd_clk            (rd_clk)                   ,  //rfifoʱ��
    .clk_100           (ui_clk)                   ,  //�û�ʱ��
    //fifo1�ӿ��ź�    
    .wr_clk_1          (wr_clk_1)                 ,  //wfifoʱ��    
    .datain_valid_1    (datain_valid_1)           ,  //������Чʹ���ź�
    .datain_1          (datain_1)                 ,  //��Ч����
    .wr_load_1         (wr_load_1)                ,  //����Դ���ź�    
    .rfifo_din_1       (rfifo_wdata_1)            ,  //rfifoд����
    .rfifo_wren_1      (rfifo_wren_1)             ,  //rfifoдʹ��
    .wfifo_rden_1      (wfifo_rden_1)             ,  //wfifo��ʹ��
    .wfifo_rcount_1    (wfifo_rcount_1)           ,  //rfifoʣ�����ݼ���
    .rfifo_wcount_1    (rfifo_wcount_1)           ,  //wfifoд�����ݼ���    
    //fifo2�ӿ��ź�    
    .wr_clk_2          (wr_clk_2)                 ,  //wfifoʱ��    
    .datain_valid_2    (datain_valid_2)           ,  //������Чʹ���ź�
    .datain_2          (datain_2)                 ,  //��Ч����    
    .wr_load_2         (wr_load_2)                ,  //����Դ���ź�
    .rfifo_din_2       (rfifo_wdata_2)            ,  //rfifoд����
    .rfifo_wren_2      (rfifo_wren_2)             ,  //rfifoдʹ��
    .wfifo_rden_2      (wfifo_rden_2)             ,  //wfifo��ʹ��    
    .wfifo_rcount_2    (wfifo_rcount_2)           ,  //rfifoʣ�����ݼ���
    .rfifo_wcount_2    (rfifo_wcount_2)           ,  //wfifoд�����ݼ���
                       
    .h_disp            (h_disp)                   ,  //����ͷˮƽ�ֱ���
    .rd_load           (rd_load)                  ,  //���Դ���ź�
    .rdata_req         (rdata_req)                ,  //�������ص���ɫ��������     
    .pic_data          (dataout)                  ,  //��Ч���� 
    .wfifo_dout        (app_wdf_data)                //�û�д����    

    );
      
endmodule