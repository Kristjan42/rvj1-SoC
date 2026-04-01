import soc_defines::obi_a;
import soc_defines::obi_r;

//`include "obi_crossbar"

module obi_xbar_testing_module #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int MANAGERS = 2,
    parameter int MID_WIDTH = $clog2(MANAGERS),
    parameter int SUBORDINATES = 8,
    parameter int ID_WIDTH = 32
)
(
    input   logic clk_i,
    input   logic rstn_i,

    // IFU signals
    // request channel
    input   logic [ADDR_WIDTH-1:0]  ifu_req_addr_i,
    input   logic [DATA_WIDTH-1:0]  ifu_req_data_i,
    input   logic [NBytes-1:0]      ifu_req_strobe_i,
    input   logic                   ifu_req_write_i,
    input   logic                   ifu_req_valid_i,
    output  logic                   ifu_req_ready_o,

    // response channel
    output  logic [ADDR_WIDTH-1:0]  ifu_rsp_data_o,
    output  logic                   ifu_rsp_error_o,
    output  logic                   ifu_rsp_valid_o,
    output  logic [ID_WIDTH-1:0]    ifu_rsp_id_o,
    input   logic                   ifu_rsp_ready_i,
    

// LSU signals
    // request channel
    input   logic [ADDR_WIDTH-1:0]  lsu_req_addr_i,
    input   logic [DATA_WIDTH-1:0]  lsu_req_data_i,
    input   logic [NBytes-1:0]      lsu_req_strobe_i,
    input   logic                   lsu_req_write_i,
    input   logic                   lsu_req_valid_i,
    output  logic                   lsu_req_ready_o,

    // response channel
    output  logic [ADDR_WIDTH-1:0]  lsu_rsp_data_o,
    output  logic                   lsu_rsp_error_o,
    output  logic                   lsu_rsp_valid_o,
    output  logic [ID_WIDTH-1:0]    lsu_rsp_id_o,
    input   logic                   lsu_rsp_ready_i,

// OBI RAM A port signals
    // request channel
    output   logic [ADDR_WIDTH-1:0]  obi_00_aaddr_o,
    output   logic [DATA_WIDTH-1:0]  obi_00_awdata_o,
    output   logic [NBytes-1:0]      obi_00_abe_o,
    output   logic                   obi_00_awe_o,
    output   logic                   obi_00_areq_o,
    output   logic [ID_WIDTH-1:0]    obi_00_aid_o,
    output   logic [MID_WIDTH-1:0]   obi_00_mid_o,               
    input    logic                   obi_00_agnt_i,

    // response channel
    input  logic [ADDR_WIDTH-1:0]  obi_00_rdata_i,
    input  logic                   obi_00_rerr_i,
    input  logic [ID_WIDTH-1:0]    obi_00_rid_i,
    input  logic                   obi_00_rvalid_i,
    output logic                   obi_00_rready_o,

// OBI RAM B port signals
    // request channel
    output   logic [ADDR_WIDTH-1:0]  obi_10_aaddr_o,
    output   logic [DATA_WIDTH-1:0]  obi_10_awdata_o,
    output   logic [NBytes-1:0]      obi_10_abe_o,
    output   logic                   obi_10_awe_o,
    output   logic                   obi_10_areq_o,
    output   logic [ID_WIDTH-1:0]    obi_10_aid_o,
    output   logic [MID_WIDTH-1:0]   obi_10_mid_o,
    input    logic                   obi_10_agnt_i,

    // response channel
    input  logic [ADDR_WIDTH-1:0]  obi_10_rdata_i,
    input  logic                   obi_10_rerr_i,
    input  logic [ID_WIDTH-1:0]    obi_10_rid_i,
    input  logic                   obi_10_rvalid_i,
    output logic                   obi_10_rready_o,

// OBI UART signals
    // request channel
    output   logic [ADDR_WIDTH-1:0]  obi_11_aaddr_o,
    output   logic [DATA_WIDTH-1:0]  obi_11_awdata_o,
    output   logic [NBytes-1:0]      obi_11_abe_o,
    output   logic                   obi_11_awe_o,
    output   logic                   obi_11_areq_o,
    output   logic [ID_WIDTH-1:0]    obi_11_aid_o,
    output   logic [MID_WIDTH-1:0]   obi_11_mid_o,
    input    logic                   obi_11_agnt_i,

    // response channel
    input  logic [ADDR_WIDTH-1:0]  obi_11_rdata_i,
    input  logic                   obi_11_rerr_i,
    input  logic [ID_WIDTH-1:0]    obi_11_rid_i,
    input  logic                   obi_11_rvalid_i,
    output logic                   obi_11_rready_o
    
);

parameter int NBytes = DATA_WIDTH / 8;

    // OBI UART
    //soc_defines::obi_manager_2_sub  uart_a_obii;
    soc_defines::obi_a uart_a_obii;
    assign obi_11_aaddr_o = uart_a_obii.obi_aadr;
    assign obi_11_awdata_o = uart_a_obii.obi_awdata;
    assign obi_11_abe_o = uart_a_obii.obi_abe;
    assign obi_11_awe_o = uart_a_obii.obi_awe;
    assign obi_11_areq_o = uart_a_obii.obi_areq;
    assign obi_11_aid_o = uart_a_obii.obi_aid;
    assign obi_11_mid_o = uart_a_obii.obi_mid;
    logic  uart_agnt_obio;
    assign uart_agnt_obio = obi_11_agnt_i;
       
    //soc_defines::obi_sub_2_manager  uart_r_obio;
    soc_defines::obi_r uart_r_obio;
    assign uart_r_obio.obi_rdata = obi_11_rdata_i;
    assign uart_r_obio.obi_rerr = obi_11_rerr_i;
    assign uart_r_obio.obi_rid = obi_11_rid_i ;
    assign uart_r_obio.obi_rvalid = obi_11_rvalid_i; 
    logic  uart_rready_obio;
    assign obi_11_rready_o = uart_rready_obio;

    // OBI RAM

    //soc_defines::obi_sub_2_manager  rama_r_obio; // TODO could change name to fit better (ram_a_obio_i)
    soc_defines::obi_r rama_r_obio;
    assign rama_r_obio.obi_rdata = obi_00_rdata_i;
    assign rama_r_obio.obi_rerr = obi_00_rerr_i;
    assign rama_r_obio.obi_rid = obi_00_rid_i;
    assign rama_r_obio.obi_rvalid = obi_00_rvalid_i;
    logic  rama_rready_obio;
    assign obi_00_rready_o = rama_rready_obio; 

    //soc_defines::obi_manager_2_sub  rama_a_obii;
    soc_defines::obi_a rama_a_obii;
    assign obi_00_aaddr_o = rama_a_obii.obi_aadr;
    assign obi_00_awdata_o = rama_a_obii.obi_awdata;
    assign obi_00_abe_o = rama_a_obii.obi_abe;
    assign obi_00_awe_o = rama_a_obii.obi_awe;
    assign obi_00_areq_o = rama_a_obii.obi_areq;
    assign obi_00_aid_o = rama_a_obii.obi_aid;
    assign obi_00_mid_o = rama_a_obii.obi_mid;
    logic  rama_agnt_obii;
    assign rama_agnt_obii = obi_00_agnt_i;
    
    
    //soc_defines::obi_sub_2_manager  ramb_r_obio;
    soc_defines::obi_r ramb_r_obio;
    assign ramb_r_obio.obi_rdata = obi_10_rdata_i;
    assign ramb_r_obio.obi_rerr = obi_10_rerr_i;
    assign ramb_r_obio.obi_rid = obi_10_rid_i;
    assign ramb_r_obio.obi_rvalid = obi_10_rvalid_i;
    logic  ramb_rready_obio;
    assign obi_10_rready_o = ramb_rready_obio;
   

    //soc_defines::obi_manager_2_sub  ramb_a_obii;
    soc_defines::obi_a ramb_a_obii;
    assign obi_10_aaddr_o = ramb_a_obii.obi_aadr;
    assign obi_10_awdata_o = ramb_a_obii.obi_awdata;
    assign obi_10_abe_o = ramb_a_obii.obi_abe;
    assign obi_10_awe_o = ramb_a_obii.obi_awe;
    assign obi_10_areq_o = ramb_a_obii.obi_areq;
    assign obi_10_aid_o = ramb_a_obii.obi_aid;
    assign obi_10_mid_o = ramb_a_obii.obi_mid;
    logic  ramb_agnt_obii;
    assign ramb_agnt_obii = obi_10_agnt_i;
    
    

    obi_crossbar #(
        32,
        32,
        2,
        3,
        4
    ) xbar (
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        // IFU
        .ifu_req_addr_i(ifu_req_addr_i),
        .ifu_req_data_i(ifu_req_data_i),
        .ifu_req_strobe_i(ifu_req_strobe_i),
        .ifu_req_write_i(ifu_req_write_i),
        .ifu_req_valid_i(ifu_req_valid_i),
        .ifu_req_ready_o(ifu_req_ready_o),

        .ifu_rsp_data_o(ifu_rsp_data_o),
        .ifu_rsp_error_o(ifu_rsp_error_o),
        .ifu_rsp_valid_o(ifu_rsp_valid_o),
        .ifu_rsp_ready_i(ifu_rsp_ready_i),
        .ifu_rsp_id_o(ifu_rsp_id_o),

        // LSU
        .lsu_req_addr_i(lsu_req_addr_i),
        .lsu_req_data_i(lsu_req_data_i),
        .lsu_req_strobe_i(lsu_req_strobe_i),
        .lsu_req_write_i(lsu_req_write_i),
        .lsu_req_ready_o(lsu_req_ready_o),
        .lsu_req_valid_i(lsu_req_valid_i),
        
        .lsu_rsp_data_o(lsu_rsp_data_o),
        .lsu_rsp_error_o(lsu_rsp_error_o),
        .lsu_rsp_ready_i(lsu_rsp_ready_i),
        .lsu_rsp_id_o(lsu_rsp_id_o),
        .lsu_rsp_valid_o(lsu_rsp_valid_o),

        // UART
        .uart_r_obio_i(uart_r_obio),
        .uart_rready_obii_o(uart_rready_obio),
        .uart_a_obii_o(uart_a_obii),
        .uart_agnt_obio_i(uart_agnt_obio),

        // RAM A
        .rama_r_obio_i(rama_r_obio),
        .rama_rready_obii_o(rama_rready_obio),
        .rama_a_obii_o(rama_a_obii),
        .rama_agnt_obio_i(rama_agnt_obii),

        // RAM B
        .ramb_r_obio_i(ramb_r_obio),
        .ramb_rready_obii_o(ramb_rready_obio),
        .ramb_a_obii_o(ramb_a_obii),
        .ramb_agnt_obio_i(ramb_agnt_obii)

    );

    


endmodule
