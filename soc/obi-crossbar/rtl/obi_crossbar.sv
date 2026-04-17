import soc_defines::obi_a;
import soc_defines::obi_r;

`include "../../obi-slave/rtl/obi_xbar_slave.sv"

// OBI crossbar
module obi_crossbar #(
    
) 
(
    input   logic clk_i,
    input   logic rstn_i,

// M0 signals
    // Request channel
    input   logic [ADDR_WIDTH-1:0]  m0_req_addr_i,
    input   logic [DATA_WIDTH-1:0]  m0_req_data_i,
    input   logic [NBytes-1:0]      m0_req_strobe_i,
    input   logic                   m0_req_write_i,
    input   logic                   m0_req_valid_i,
    output  logic                   m0_req_ready_o,

    // Response channel
    output  logic [ADDR_WIDTH-1:0]  m0_rsp_data_o,
    output  logic                   m0_rsp_error_o,
    output  logic                   m0_rsp_valid_o,
    output  logic [ID_WIDTH-1:0]    m0_rsp_id_o,
    input   logic                   m0_rsp_ready_i,
    

// M1 signals
    // Request channel
    input   logic [ADDR_WIDTH-1:0]  m1_req_addr_i,
    input   logic [DATA_WIDTH-1:0]  m1_req_data_i,
    input   logic [NBytes-1:0]      m1_req_strobe_i,
    input   logic                   m1_req_write_i,
    input   logic                   m1_req_valid_i,
    output  logic                   m1_req_ready_o,

    // Response channel
    output  logic [ADDR_WIDTH-1:0]  m1_rsp_data_o,
    output  logic                   m1_rsp_error_o,
    output  logic                   m1_rsp_valid_o,
    output  logic [ID_WIDTH-1:0]    m1_rsp_id_o,
    input   logic                   m1_rsp_ready_i,

// M2 signals
    // Request channel
    input   logic [ADDR_WIDTH-1:0]  m2_req_addr_i,
    input   logic [DATA_WIDTH-1:0]  m2_req_data_i,
    input   logic [NBytes-1:0]      m2_req_strobe_i,
    input   logic                   m2_req_write_i,
    input   logic                   m2_req_valid_i,
    output  logic                   m2_req_ready_o,

    // Response channel
    output  logic [ADDR_WIDTH-1:0]  m2_rsp_data_o,
    output  logic                   m2_rsp_error_o,
    output  logic                   m2_rsp_valid_o,
    output  logic [ID_WIDTH-1:0]    m2_rsp_id_o,
    input   logic                   m2_rsp_ready_i,
/*
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
    input logic ramb_agnt_obio_i,
*/



// S0
    output logic [ADDR_WIDTH-1:0]           s0_obi_aadr_o,
    output logic                            s0_obi_awe_o,
    output logic [NBytes-1:0]               s0_obi_abe_o,
    output logic [DATA_WIDTH-1:0]           s0_obi_awdata_o,
    output logic                            s0_req_valid_o,
    input  logic                            s0_req_read_i,

    output logic                            s0_rsp_ready_o,
    input  logic                            s0_rsp_write_i,
    input  logic [DATA_WIDTH-1:0]           s0_obi_rdata_i,
    input  logic                            s0_obi_rerr_i,

// S1
    output logic [ADDR_WIDTH-1:0]           s1_obi_aadr_o,
    output logic                            s1_obi_awe_o,
    output logic [NBytes-1:0]               s1_obi_abe_o,
    output logic [DATA_WIDTH-1:0]           s1_obi_awdata_o,
    output logic                            s1_req_valid_o,
    input  logic                            s1_req_read_i,

    output logic                            s1_rsp_ready_o,
    input  logic                            s1_rsp_write_i,
    input  logic [DATA_WIDTH-1:0]           s1_obi_rdata_i,
    input  logic                            s1_obi_rerr_i
);

    localparam int ADDR_WIDTH = 32;
    localparam int DATA_WIDTH = 32;
    localparam int MANAGERS = 2;
    localparam int SUBORDINATES = 8;
    localparam int ID_WIDTH = 32;
    localparam int NBytes = DATA_WIDTH / 8;

// OBI IFU manager
    soc_defines::obi_a obi_a_m0o [SUBORDINATES];   // DMUX data signal outputs (IFU a channel signals)
    soc_defines::obi_r obi_r_m0i [SUBORDINATES];   // MUX data signal inputs (IFU r channel signals)
    logic obi_agnt_m0i_array [SUBORDINATES]; 
    logic obi_rready_m0o_array [SUBORDINATES];
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
    .obi_a_channels_o(obi_a_m0o),
    .obi_r_channels_i(obi_r_m0i),
    .obi_agnt_array_i(obi_agnt_m0i_array),
    .obi_rready_array_o(obi_rready_m0o_array),
    // M0 A to OBI A
    .obi_areq_i(m0_req_valid_i),
    .obi_aadr_i(m0_req_addr_i),
    .obi_awe_i(m0_req_write_i),
    .obi_abe_i(m0_req_strobe_i),
    .obi_awdata_i(m0_req_data_i),
    .obi_agnt_o(m0_req_ready_o),
    // M0 R to OBI R
    .obi_rready_i(m0_rsp_ready_i),
    .obi_rdata_o(m0_rsp_data_o),
    .obi_rerr_o(m0_rsp_error_o),
    .obi_rvalid_o(m0_rsp_valid_o),
    .obi_rid_o(m0_rsp_id_o)
);

// OBI LSU manager
    soc_defines::obi_a obi_a_m1o [SUBORDINATES];   // DMUX data signal outputs (LSU a channel signals)
    soc_defines::obi_r obi_r_m1i [SUBORDINATES];   // MUX data signal inputs (LSU r channel signals)
    logic obi_agnt_m1i_array [SUBORDINATES];
    logic obi_rready_m1o_array [SUBORDINATES];
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
    .obi_a_channels_o(obi_a_m1o),
    .obi_r_channels_i(obi_r_m1i),
    .obi_agnt_array_i(obi_agnt_m1i_array),
    .obi_rready_array_o(obi_rready_m1o_array),
    // M1 A to OBI A
    .obi_areq_i(m1_req_valid_i),
    .obi_aadr_i(m1_req_addr_i),
    .obi_awe_i(m1_req_write_i),
    .obi_abe_i(m1_req_strobe_i),
    .obi_awdata_i(m1_req_data_i),
    .obi_agnt_o(m1_req_ready_o),
    // M1 R to OBI R 
    .obi_rready_i(m1_rsp_ready_i),
    .obi_rdata_o(m1_rsp_data_o),
    .obi_rerr_o(m1_rsp_error_o),
    .obi_rvalid_o(m1_rsp_valid_o),
    .obi_rid_o(m1_rsp_id_o)
);



// OBI M2 manager
    soc_defines::obi_a obi_a_m2o [SUBORDINATES];   // DMUX data signal outputs (LSU a channel signals)
    soc_defines::obi_r obi_r_m2i [SUBORDINATES];   // MUX data signal inputs (LSU r channel signals)
    logic obi_agnt_m2i_array [SUBORDINATES];
    logic obi_rready_m2o_array [SUBORDINATES];
obi_manager #(
    ADDR_WIDTH,
    DATA_WIDTH,
    NBytes,
    MANAGERS,
    2,
    SUBORDINATES,
    ID_WIDTH
) obi_m2_manager(
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .obi_a_channels_o(obi_a_m2o),
    .obi_r_channels_i(obi_r_m2i),
    .obi_agnt_array_i(obi_agnt_m2i_array),
    .obi_rready_array_o(obi_rready_m2o_array),
    // M1 A to OBI A
    .obi_areq_i(m2_req_valid_i),
    .obi_aadr_i(m2_req_addr_i),
    .obi_awe_i(m2_req_write_i),
    .obi_abe_i(m2_req_strobe_i),
    .obi_awdata_i(m2_req_data_i),
    .obi_agnt_o(m2_req_ready_o),
    // M1 R to OBI R 
    .obi_rready_i(m2_rsp_ready_i),
    .obi_rdata_o(m2_rsp_data_o),
    .obi_rerr_o(m2_rsp_error_o),
    .obi_rvalid_o(m2_rsp_valid_o),
    .obi_rid_o(m2_rsp_id_o)
);

/*
// UART OBI Link
    assign obi_r_lsui[1] = uart_r_obio_i;
    assign uart_rready_obii_o = obi_rready_lsuo_array[1];
    assign uart_a_obii_o = obi_a_lsuo[1];
    assign ob

/*
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
*/

// ---------- S0 ----------
    // S0 params
    localparam int S0_MANAGERS_CONS = 2; // No. of managers connected to slave
    localparam int S0_FIFO_DEPTH = 1024;

    // OBI A channels S0-Masters
    soc_defines::obi_a s0_obi_a_channels [S0_MANAGERS_CONS];
    logic s0_obi_agnt_array [S0_MANAGERS_CONS];

        assign s0_obi_a_channels[0] = obi_a_m0o[0];
        assign s0_obi_a_channels[1] = obi_a_m1o[0];

        assign obi_agnt_m0i_array[0] = s0_obi_agnt_array[0];
        assign obi_agnt_m1i_array[0] = s0_obi_agnt_array[1];

    // OBI R channels S0-Masters
    soc_defines::obi_r s0_obi_r_channels [S0_MANAGERS_CONS];
    logic s0_obi_rready_array [S0_MANAGERS_CONS];

        assign obi_r_m0i[0] = s0_obi_r_channels[0];
        assign obi_r_m1i[0] = s0_obi_r_channels[1];

        assign s0_obi_rready_array[0] = obi_rready_m0o_array[0];
        assign s0_obi_rready_array[1] = obi_rready_m1o_array[0];

obi_xbar_slave #(
    S0_MANAGERS_CONS,
    S0_FIFO_DEPTH
) s0 (
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    .obi_a_channels_i(s0_obi_a_channels),
    .obi_agnt_array_o(s0_obi_agnt_array),
    .obi_r_channels_o(s0_obi_r_channels),
    .obi_rready_array_i(s0_obi_rready_array),

    .obi_aadr_o(s0_obi_aadr_o),
    .obi_awe_o(s0_obi_awe_o),
    .obi_abe_o(s0_obi_abe_o),
    .obi_awdata_o(s0_obi_awdata_o),
    .req_valid_o(s0_req_valid_o),
    .req_read_i(s0_req_read_i),

    .rsp_write_i(s0_rsp_write_i),
    .rsp_ready_o(s0_rsp_ready_o),
    .obi_rdata_i(s0_obi_rdata_i),
    .obi_rerr_i(s0_obi_rerr_i)
);


// ---------- S1 ----------
    // S1 params
    localparam int S1_MANAGERS_CONS = 4; // No. of managers connected to slave
    localparam int S1_FIFO_DEPTH = 1024;

    // OBI A channels S1-Masters
    soc_defines::obi_a s1_obi_a_channels [S1_MANAGERS_CONS];
    logic s1_obi_agnt_array [S1_MANAGERS_CONS];

        assign s1_obi_a_channels[0] = obi_a_m0o[1];
        assign s1_obi_a_channels[1] = obi_a_m1o[1];
        assign s1_obi_a_channels[2] = obi_a_m2o[1];

        assign obi_agnt_m0i_array[1] = s1_obi_agnt_array[0];
        assign obi_agnt_m1i_array[1] = s1_obi_agnt_array[1];
        assign obi_agnt_m2i_array[1] = s1_obi_agnt_array[2];

    // OBI R channels S1-Masters
    soc_defines::obi_r s1_obi_r_channels [S1_MANAGERS_CONS];
    logic s1_obi_rready_array [S1_MANAGERS_CONS];

        assign obi_r_m0i[1] = s1_obi_r_channels[0];
        assign obi_r_m1i[1] = s1_obi_r_channels[1];
        assign obi_r_m2i[1] = s1_obi_r_channels[2];

        assign s1_obi_rready_array[0] = obi_rready_m0o_array[1];
        assign s1_obi_rready_array[1] = obi_rready_m1o_array[1];
        assign s1_obi_rready_array[2] = obi_rready_m2o_array[1];

obi_xbar_slave #(
    S1_MANAGERS_CONS,
    S1_FIFO_DEPTH
) s1 (
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    .obi_a_channels_i(s1_obi_a_channels),
    .obi_agnt_array_o(s1_obi_agnt_array),
    .obi_r_channels_o(s1_obi_r_channels),
    .obi_rready_array_i(s1_obi_rready_array),

    .obi_aadr_o(s1_obi_aadr_o),
    .obi_awe_o(s1_obi_awe_o),
    .obi_abe_o(s1_obi_abe_o),
    .obi_awdata_o(s1_obi_awdata_o),
    .req_valid_o(s1_req_valid_o),
    .req_read_i(s1_req_read_i),

    .rsp_write_i(s1_rsp_write_i),
    .rsp_ready_o(s1_rsp_ready_o),
    .obi_rdata_i(s1_obi_rdata_i),
    .obi_rerr_i(s1_obi_rerr_i)
);
    

endmodule




