module check_dir_stp(
  input phyclk,
  input rst,
  input DIR,
  input STP
);

// // RULE: The FPGA must NEVER assert STP while the PHY owns the bus (DIR=1).
// property prop_no_bus_contention;
//   @(posedge phyclk) disable iff (!rst)
//   DIR |-> !STP;
// endproperty

// assert_no_bus_contention: assert property (prop_no_bus_contention)
//   else $fatal(1, "[%0t] SVA FATAL: Bus Contention! FPGA asserted STP while DIR was high.", $time);


endmodule