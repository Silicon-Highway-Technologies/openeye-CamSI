
module RTL8211_Config_IP(
    input          sys_clk  ,  
    input          sys_rstn,
    //MDIO�ӿ�
    output         eth_mdc  , //PHY����ӿڵ�ʱ���ź�
    inout          eth_mdio , //PHY����ӿڵ�˫�������ź�

    output  [1:0]  led        //LED��������ָʾ
    );
    
    
    parameter CLK_DIV       =6'd60;  
    parameter tx_delay_en   =1'b1;
    parameter rx_delay_en   =1'b1;
    
//wire define
wire          op_exec    ;  //������ʼ�ź�
wire          op_rh_wl   ;  //�͵�ƽд���ߵ�ƽ��
wire  [4:0]   op_addr    ;  //�Ĵ�����ַ
wire  [15:0]  op_wr_data ;  //д��Ĵ���������
wire  [4:0]   phy_addr   ;
wire          op_done    ;  //��д���
wire  [15:0]  op_rd_data ;  //����������
wire          op_rd_ack  ;  //��Ӧ���ź� 0:Ӧ�� 1:δӦ��
wire          dri_clk    ;  //����ʱ��
wire  [5:0]   cur_state ;


//MDIO�ӿ�����
mdio_dri #(
    .CLK_DIV    (CLK_DIV)     //��Ƶϵ��
    )
    u_mdio_dri(
    .clk        (sys_clk),
    .rst_n      (sys_rstn),
    .op_exec    (op_exec   ),
    .op_rh_wl   (op_rh_wl  ),   
    .op_addr    (op_addr   ),   
    .op_wr_data (op_wr_data),   
    .phy_addr   (phy_addr),
    .op_done    (op_done   ),   
    .op_rd_data (op_rd_data),   
    .op_rd_ack  (op_rd_ack ),   
    .dri_clk    (dri_clk   ),  
                 
    .eth_mdc    (eth_mdc   ),   
    .eth_mdio   (eth_mdio  )
);      

//MDIO�ӿڶ�д����    
mdio_ctrl #(
    .tx_delay(tx_delay_en),
    .rx_delay(rx_delay_en)
)
  u_mdio_ctrl(
    .clk           (dri_clk),  
    .rst_n         (sys_rstn ),  
    .op_done       (op_done   ),  
    .op_rd_data    (op_rd_data),  
    .op_rd_ack     (op_rd_ack ),  
    .phy_addr      (phy_addr),    
    .op_exec       (op_exec   ),  
    .op_rh_wl      (op_rh_wl  ),  
    .op_addr       (op_addr   ),  
    .op_wr_data    (op_wr_data)
);      

endmodule
