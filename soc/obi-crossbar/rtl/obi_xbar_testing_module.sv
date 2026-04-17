import soc_defines::obi_a;
import soc_defines::obi_r;

//`include "obi_crossbar"

module obi_xbar_testing_module #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int MANAGERS = 2,
    parameter int MID_WIDTH = $clog2(MANAGERS),
    parameter int SUBORDINATES = 8,
    parameter int ID_WIDTH = 4
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

// M2 signals
    // request channel
    input   logic [ADDR_WIDTH-1:0]  m2_req_addr_i,
    input   logic [DATA_WIDTH-1:0]  m2_req_data_i,
    input   logic [NBytes-1:0]      m2_req_strobe_i,
    input   logic                   m2_req_write_i,
    input   logic                   m2_req_valid_i,
    output  logic                   m2_req_ready_o,

    // response channel
    output  logic [ADDR_WIDTH-1:0]  m2_rsp_data_o,
    output  logic                   m2_rsp_error_o,
    output  logic                   m2_rsp_valid_o,
    output  logic [ID_WIDTH-1:0]    m2_rsp_id_o,
    input   logic                   m2_rsp_ready_i,

/*
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
    */

// S0
    output logic [ADDR_WIDTH-1:0]           s0_obi_aadr_o,
    output logic                            s0_obi_awe_o,
    output logic [NBytes-1:0]               s0_obi_abe_o,
    output logic [DATA_WIDTH-1:0]           s0_obi_awdata_o,
    output logic                            s0_obi_areq_o,
    input  logic                            s0_obi_agnt_i,

    output logic                            s0_obi_rready_o,
    input  logic                            s0_obi_rvalid_i,
    input  logic [DATA_WIDTH-1:0]           s0_obi_rdata_i,
    input  logic                            s0_obi_rerr_i,

// S1
    output logic [ADDR_WIDTH-1:0]           s1_obi_aadr_o,
    output logic                            s1_obi_awe_o,
    output logic [NBytes-1:0]               s1_obi_abe_o,
    output logic [DATA_WIDTH-1:0]           s1_obi_awdata_o,
    output logic                            s1_obi_areq_o,
    input  logic                            s1_obi_agnt_i,

    output logic                            s1_obi_rready_o,
    input  logic                            s1_obi_rvalid_i,
    input  logic [DATA_WIDTH-1:0]           s1_obi_rdata_i,
    input  logic                            s1_obi_rerr_i

);

parameter int NBytes = DATA_WIDTH / 8;

    /*
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
    */
    

    obi_crossbar #(
        32,
        32,
        4,
        2,
        4
    ) xbar (
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        // IFU
        .m0_req_addr_i(ifu_req_addr_i),
        .m0_req_data_i(ifu_req_data_i),
        .m0_req_strobe_i(ifu_req_strobe_i),
        .m0_req_write_i(ifu_req_write_i),
        .m0_req_valid_i(ifu_req_valid_i),
        .m0_req_ready_o(ifu_req_ready_o),

        .m0_rsp_data_o(ifu_rsp_data_o),
        .m0_rsp_error_o(ifu_rsp_error_o),
        .m0_rsp_valid_o(ifu_rsp_valid_o),
        .m0_rsp_ready_i(ifu_rsp_ready_i),
        .m0_rsp_id_o(ifu_rsp_id_o),

        // LSU
        .m1_req_addr_i(lsu_req_addr_i),
        .m1_req_data_i(lsu_req_data_i),
        .m1_req_strobe_i(lsu_req_strobe_i),
        .m1_req_write_i(lsu_req_write_i),
        .m1_req_ready_o(lsu_req_ready_o),
        .m1_req_valid_i(lsu_req_valid_i),
        
        .m1_rsp_data_o(lsu_rsp_data_o),
        .m1_rsp_error_o(lsu_rsp_error_o),
        .m1_rsp_ready_i(lsu_rsp_ready_i),
        .m1_rsp_id_o(lsu_rsp_id_o),
        .m1_rsp_valid_o(lsu_rsp_valid_o),

        // M2
        .m2_req_addr_i(m2_req_addr_i),
        .m2_req_data_i(m2_req_data_i),
        .m2_req_strobe_i(m2_req_strobe_i),
        .m2_req_write_i(m2_req_write_i),
        .m2_req_ready_o(m2_req_ready_o),
        .m2_req_valid_i(m2_req_valid_i),
        
        .m2_rsp_data_o(m2_rsp_data_o),
        .m2_rsp_error_o(m2_rsp_error_o),
        .m2_rsp_ready_i(m2_rsp_ready_i),
        .m2_rsp_id_o(m2_rsp_id_o),
        .m2_rsp_valid_o(m2_rsp_valid_o),


        // S0
        .s0_obi_aadr_o(s0_obi_aadr_o),
        .s0_obi_awe_o(s0_obi_awe_o),
        .s0_obi_abe_o(s0_obi_abe_o),
        .s0_obi_awdata_o(s0_obi_awdata_o),
        .s0_req_valid_o(s0_obi_areq_o),
        .s0_req_read_i(s0_obi_agnt_i),

        .s0_rsp_ready_o(s0_obi_rready_o),
        .s0_rsp_write_i(s0_obi_rvalid_i),
        .s0_obi_rdata_i(s0_obi_rdata_i),
        .s0_obi_rerr_i(s0_obi_rerr_i),

        // S1
        .s1_obi_aadr_o(s1_obi_aadr_o),
        .s1_obi_awe_o(s1_obi_awe_o),
        .s1_obi_abe_o(s1_obi_abe_o),
        .s1_obi_awdata_o(s1_obi_awdata_o),
        .s1_req_valid_o(s1_obi_areq_o),
        .s1_req_read_i(s1_obi_agnt_i),    


        .s1_rsp_ready_o(s1_obi_rready_o),
        .s1_rsp_write_i(s1_obi_rvalid_i),
        .s1_obi_rdata_i(s1_obi_rdata_i),
        .s1_obi_rerr_i(s1_obi_rerr_i)

        /*
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
        */

    );

    


endmodule
