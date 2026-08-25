// `define QF10
// `define QF25
`define QF50
// `define QF100

// `define RES_720P60
// // `define RES_1080P30

// `ifdef RES_720P60
//   parameter ACTIVE_WIDTH = 11'd1280;
//   parameter ACTIVE_HEIGHT = 10'd720;
//   parameter TOTAL_WIDTH = 11'd1687;
//   parameter TOTAL_HEIGHT = 11'd850;
// `elsif RES_1080P30
//   parameter ACTIVE_WIDTH = 11'd1920;
//   parameter ACTIVE_HEIGHT = 11'd1080;
//   parameter TOTAL_WIDTH = 12'd2553;
//   parameter TOTAL_HEIGHT = 11'd1125;
// `endif