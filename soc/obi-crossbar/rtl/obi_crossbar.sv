import soc_defines::obi_a;
import soc_defines::obi_r;

// OBI crossbar
module obi_crossbar #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int MANAGERS = 2,
    parameter int SUBORDINATES = 8,
    parameter int ID_WIDTH = 32
) 
(
    input   logic clk_i,
    input   logic rstn_i,

// IFU signals
    // Request channel
    input   logic [ADDR_WIDTH-1:0]  ifu_req_addr_i,
    input   logic [DATA_WIDTH-1:0]  ifu_req_data_i,
    input   logic [NBytes-1:0]      ifu_req_strobe_i,
    input   logic                   ifu_req_write_i,
    input   logic                   ifu_req_valid_i,
    output  logic                   ifu_req_ready_o,

    // Response channel
    output  logic [ADDR_WIDTH-1:0]  ifu_rsp_data_o,
    output  logic                   ifu_rsp_error_o,
    output  logic                   ifu_rsp_valid_o,
    output  logic [ID_WIDTH-1:0]    ifu_rsp_id_o,
    input   logic                   ifu_rsp_ready_i,
    

// LSU signals
    // Request channel
    input   logic [ADDR_WIDTH-1:0]  lsu_req_addr_i,
    input   logic [DATA_WIDTH-1:0]  lsu_req_data_i,
    input   logic [NBytes-1:0]      lsu_req_strobe_i,
    input   logic                   lsu_req_write_i,
    input   logic                   lsu_req_valid_i,
    output  logic                   lsu_req_ready_o,

    // Response channel
    output  logic [ADDR_WIDTH-1:0]  lsu_rsp_data_o,
    output  logic                   lsu_rsp_error_o,
    output  logic                   lsu_rsp_valid_o,
    output  logic [ID_WIDTH-1:0]    lsu_rsp_id_o,
    input   logic                   lsu_rsp_ready_i,

// OBI UART
    // Request channel
    output soc_defines::obi_a uart_a_obii_o,
    input logic uart_agnt_obio_i,

    // Response channel
    input soc_defines::obi_r uart_r_obio_i,
    output logic uart_rready_obii_o,   
// OBI RAM
    // Response channel
    input soc_defines::obi_r rama_r_obio_i,
    output logic rama_rready_obii_o,
    
    // Request channel
    output soc_defines::obi_a rama_a_obii_o,
    input logic rama_agnt_obio_i,

    // Response channel
    input soc_defines::obi_r ramb_r_obio_i,
    output logic ramb_rready_obii_o,

    // Request channel
    output soc_defines::obi_a ramb_a_obii_o,
    input logic ramb_agnt_obio_i
);

    localparam int NBytes = DATA_WIDTH / 8;

// OBI IFU manager
    soc_defines::obi_a obi_a_ifuo [SUBORDINATES];   // DMUX data signal outputs (IFU a channel signals)
    soc_defines::obi_r obi_r_ifui [SUBORDINATES];   // MUX data signal inputs (IFU r channel signals)
    logic obi_agnt_ifui_array [SUBORDINATES]; 
    logic obi_rready_ifuo_array [SUBORDINATES];
obi_manager #(
    ADDR_WIDTH,
    DATA_WIDTH,
    NBytes,
    MANAGERS,
    0,
    SUBORDINATES,
    ID_WIDTH
) obi_ifu_manager(
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .obi_a_channels_o(obi_a_ifuo),
    .obi_r_channels_i(obi_r_ifui),
    .obi_agnt_array_i(obi_agnt_ifui_array),
    .obi_rready_array_o(obi_rready_ifuo_array),
    // IFU A to OBI A
    .obi_areq_i(ifu_req_valid_i),
    .obi_aadr_i(ifu_req_addr_i),
    .obi_awe_i(ifu_req_write_i),
    .obi_abe_i(ifu_req_strobe_i),
    .obi_awdata_i(ifu_req_data_i),
    .obi_agnt_o(ifu_req_ready_o),
    // IFU R to OBI R
    .obi_rready_i(ifu_rsp_ready_i),
    .obi_rdata_o(ifu_rsp_data_o),
    .obi_rerr_o(ifu_rsp_error_o),
    .obi_rvalid_o(ifu_rsp_valid_o),
    .obi_rid_o(ifu_rsp_id_o)
);

// OBI LSU manager
    soc_defines::obi_a obi_a_lsuo [SUBORDINATES];   // DMUX data signal outputs (LSU a channel signals)
    soc_defines::obi_r obi_r_lsui [SUBORDINATES];   // MUX data signal inputs (LSU r channel signals)
    logic obi_agnt_lsui_array [SUBORDINATES];
    logic obi_rready_lsuo_array [SUBORDINATES];
obi_manager #(
    ADDR_WIDTH,
    DATA_WIDTH,
    NBytes,
    MANAGERS,
    1,
    SUBORDINATES,
    ID_WIDTH
) obi_lsu_manager(
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .obi_a_channels_o(obi_a_lsuo),
    .obi_r_channels_i(obi_r_lsui),
    .obi_agnt_array_i(obi_agnt_lsui_array),
    .obi_rready_array_o(obi_rready_lsuo_array),
    // LSU A to OBI A
    .obi_areq_i(lsu_req_valid_i),
    .obi_aadr_i(lsu_req_addr_i),
    .obi_awe_i(lsu_req_write_i),
    .obi_abe_i(lsu_req_strobe_i),
    .obi_awdata_i(lsu_req_data_i),
    .obi_agnt_o(lsu_req_ready_o),
    // LSU R to OBI R 
    .obi_rready_i(lsu_rsp_ready_i),
    .obi_rdata_o(lsu_rsp_data_o),
    .obi_rerr_o(lsu_rsp_error_o),
    .obi_rvalid_o(lsu_rsp_valid_o),
    .obi_rid_o(lsu_rsp_id_o)
);

// UART OBI Link
    assign obi_r_lsui[1] = uart_r_obio_i;
    assign uart_rready_obii_o = obi_rready_lsuo_array[1];
    assign uart_a_obii_o = obi_a_lsuo[1];
    assign obi_agnt_lsui_array[1] = uart_agnt_obio_i;

// RAM-A OBI Link
    assign obi_r_ifui[0] = rama_r_obio_i;
    assign rama_rready_obii_o = obi_rready_ifuo_array[0];
    assign rama_a_obii_o = obi_a_ifuo[0];
    assign obi_agnt_ifui_array[0] = rama_agnt_obio_i; 

// RAM-B OBI Link
    assign obi_r_lsui[0] = ramb_r_obio_i;
    assign ramb_rready_obii_o = obi_rready_lsuo_array[0];
    assign ramb_a_obii_o = obi_a_lsuo[0];
    assign obi_agnt_lsui_array[0] = ramb_agnt_obio_i;
    

endmodule




