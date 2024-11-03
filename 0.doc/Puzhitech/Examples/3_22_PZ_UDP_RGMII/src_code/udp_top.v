`timescale 1ns / 1ps


module udp_top(
    input              sys_clk_p   , //ϵͳʱ��
    input              sys_clk_n   , //ϵͳʱ��    
    input              sys_rst_n , //ϵͳ��λ�źţ��͵�ƽ��Ч 
    //KSZ9031_RGMII�ӿ�   
    output             eth1_mdc  ,
    inout              eth1_mdio ,     
    input              net1_rxc   , //KSZ9031_RGMII��������ʱ��
    input              net1_rx_ctl, //KSZ9031RGMII����������Ч�ź�
    input       [3:0]  net1_rxd   , //KSZ9031RGMII��������
    output             net1_txc   , //KSZ9031RGMII��������ʱ��    
    output             net1_tx_ctl, //KSZ9031RGMII���������Ч�ź�
    output      [3:0]  net1_txd   , //KSZ9031RGMII�������          
    output             net1_rst_n , //KSZ9031оƬ��λ�źţ��͵�ƽ��Ч 
      
    output             eth2_mdc  ,
    inout              eth2_mdio ,     
    input              net2_rxc   , //KSZ9031_RGMII��������ʱ��
    input              net2_rx_ctl, //KSZ9031RGMII����������Ч�ź�
    input       [3:0]  net2_rxd   , //KSZ9031RGMII��������
    output             net2_txc   , //KSZ9031RGMII��������ʱ��    
    output             net2_tx_ctl, //KSZ9031RGMII���������Ч�ź�
    output      [3:0]  net2_txd   , //KSZ9031RGMII�������          
    output             net2_rst_n  //KSZ9031оƬ��λ�źţ��͵�ƽ��Ч   
    );
    
wire    clk_200m; 
wire    clk_50m;    
    //MMCM/PLL
clk_wiz_0 u_clk_wiz
(
    .clk_in1_p(sys_clk_p),    
    .clk_in1_n(sys_clk_n),    
    .clk_out1  (clk_200m  ),   
    .clk_out2  (clk_50m  ),     
    .reset     (~sys_rst_n)
);

(* IODELAY_GROUP = "rgmii_delay" *) 
IDELAYCTRL  IDELAYCTRL_inst (
    .RDY(),                      // 1-bit output: Ready output
    .REFCLK(clk_200m),         // 1-bit input: Reference clock input
    .RST(1'b0)                   // 1-bit input: Active high reset input
);


net_udp_loop  net_udp_loop_inst1(
   .clk_200m (clk_200m ) ,   
   .clk_50m  (clk_50m  ) ,  
   .sys_rst_n(sys_rst_n) , //ϵͳ��λ�źţ��͵�ƽ��Ч 
    //KSZ9031_RGMII�ӿ�   
    .eth_mdc   (eth1_mdc),    // output wire eth_mdc
    .eth_mdio  (eth1_mdio), // inout wire eth_mdio    
    .net_rxc   (net1_rxc   ), //KSZ9031_RGMII��������ʱ��
    .net_rx_ctl(net1_rx_ctl), //KSZ9031RGMII����������Ч�ź�
    .net_rxd   (net1_rxd   ), //KSZ9031RGMII��������
    .net_txc   (net1_txc   ), //KSZ9031RGMII��������ʱ��    
    .net_tx_ctl(net1_tx_ctl), //KSZ9031RGMII���������Ч�ź�
    .net_txd   (net1_txd   ), //KSZ9031RGMII�������          
    .net_rst_n (net1_rst_n )  //KSZ9031оƬ��λ�źţ��͵�ƽ��Ч   
    );

net_udp_loop  net_udp_loop_inst2(
   .clk_200m (clk_200m ) ,   
   .clk_50m  (clk_50m  ) ,  
   .sys_rst_n(sys_rst_n) , //ϵͳ��λ�źţ��͵�ƽ��Ч 
    //KSZ9031_RGMII�ӿ�   
    .eth_mdc   (eth2_mdc),    // output wire eth_mdc
    .eth_mdio  (eth2_mdio), // inout wire eth_mdio    
    .net_rxc   (net2_rxc   ), //KSZ9031_RGMII��������ʱ��
    .net_rx_ctl(net2_rx_ctl), //KSZ9031RGMII����������Ч�ź�
    .net_rxd   (net2_rxd   ), //KSZ9031RGMII��������
    .net_txc   (net2_txc   ), //KSZ9031RGMII��������ʱ��    
    .net_tx_ctl(net2_tx_ctl), //KSZ9031RGMII���������Ч�ź�
    .net_txd   (net2_txd   ), //KSZ9031RGMII�������          
    .net_rst_n (net2_rst_n )  //KSZ9031оƬ��λ�źţ��͵�ƽ��Ч   
    );    
endmodule
