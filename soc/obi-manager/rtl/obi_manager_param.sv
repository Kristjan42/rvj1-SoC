import soc_defines::obi_a;
import soc_defines::obi_r;
import soc_defines::addr_map;


// OBI manager
module obi_manager_param #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int NBytes = DATA_WIDTH / 8,
    parameter int MANAGERS = 2,
    parameter bit [$clog2(MANAGERS)-1:0] MANAGER_ID = '0,
    parameter int SUBORDINATES = 8,
    parameter int ID_WIDTH = 32

)
(
    input   logic clk_i,
    input   logic rstn_i,

// OBI R channels Selector-Slaves
    output logic [SUBORDINATES-1:0] obi_rready_array_o,
    input soc_defines::obi_r [SUBORDINATES-1:0] obi_r_channels_i,

// OBI A channels Selector-Slaves
    output soc_defines::obi_a [SUBORDINATES-1:0] obi_a_channels_o,
    input logic [SUBORDINATES-1:0] obi_agnt_array_i,


    
// OBI A channel
    input logic                     obi_areq_i,
    input logic [ADDR_WIDTH-1:0]    obi_aadr_i,
    input logic                     obi_awe_i,
    input logic [NBytes-1:0]        obi_abe_i,
    input logic [DATA_WIDTH-1:0]    obi_awdata_i,
    input logic [ID_WIDTH-1:0]      obi_aid_i,
    
    output logic                    obi_agnt_o,


// OBI R channel
    input logic                     obi_rready_i,

    output logic [DATA_WIDTH-1:0]   obi_rdata_o,
    output logic                    obi_rerr_o,
    output logic                    obi_rvalid_o,
    output logic [ID_WIDTH-1:0]     obi_rid_o


);



// OBI manager to subordinate signals
    soc_defines::obi_a obi_a;

    assign obi_a.obi_areq     =   obi_areq_i;
    assign obi_a.obi_aadr     =   obi_aadr_i;
    assign obi_a.obi_awe      =   obi_awe_i;
    assign obi_a.obi_abe      =   obi_abe_i;
    assign obi_a.obi_awdata   =   obi_awdata_i;
    assign obi_a.obi_aid      =   obi_aid_i;
    assign obi_a.obi_mid      =   MANAGER_ID;

// OBI subordinate to manager signals
    soc_defines::obi_r obi_r;

    assign obi_rdata_o          =   obi_r.obi_rdata;
    assign obi_rerr_o           =   obi_r.obi_rerr;
    assign obi_rvalid_o         =   obi_r.obi_rvalid;
    assign obi_rid_o            =   obi_r.obi_rid;

// Selector signals for dmux and mux
    logic [$clog2(SUBORDINATES)-1:0] obi_a_sel;
    logic [SUBORDINATES-1:0] obi_r_sel;

// Enable signals for generating next aid and setting next rid
    logic gen_next;
    logic set_next;

// Array of rid signals used to compare for mux switching
    logic [ID_WIDTH-1:0]     rid_array[SUBORDINATES];

// R decoder
    // TODO propagate address_maps 
    logic address_map_err;
    soc_defines::addr_map [1:0]  address_maps;
    assign address_maps[0] = '{3'd0,32'h0000_0000,32'h4000_0000};
    assign address_maps[1] = '{3'd1,32'h4000_0000,32'h4000_0000};

// OBI link selector
    obi_link_selector_param #(
        SUBORDINATES,
        ID_WIDTH
    ) obi_link_selector_inst (
        .obi_a_i(obi_a),
        .obi_r_o(obi_r),
        .obi_agnt_o(obi_agnt_o),
        .obi_rready_i(obi_rready_i),
        .obi_a_channels_o(obi_a_channels_o),
        .obi_r_channels_i(obi_r_channels_i),
        .obi_agnt_array_i(obi_agnt_array_i),
        .obi_rready_array_o(obi_rready_array_o),
        .obi_a_sel_i(obi_a_sel),
        .address_map_err_i(address_map_err),
        .obi_r_sel_i(obi_r_sel),
        .set_next_o(set_next),
        .rid_array_o(rid_array),
        .gen_next_o(gen_next)
    );

// OBI aid generator
    /*
    obi_aid_generator #(
        ID_WIDTH
    ) obi_aid_generator_inst (
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .gen_next_i(gen_next),
        .obi_aid_o(obi_a.obi_aid)
    );
    */

// OBI A channel decoder 
    obi_a_decoder #(SUBORDINATES, ADDR_WIDTH, 2) obi_a_decoder_inst (
        .req_address_i(obi_aadr_i),
        .address_maps_i(address_maps),
        .config_ready_i(1'b1),
        .default_sel_en_i('0),
        .default_sel_i(3'd2),
        .address_map_err_o(address_map_err),
        .obi_a_sel_o(obi_a_sel)
    );

// OBI R channel decoder
    obi_r_decoder #(
        SUBORDINATES,
        ID_WIDTH
    ) obi_r_decoder_inst(
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .set_next_i(set_next),
        .rid_array_i(rid_array),
        .obi_r_sel_o(obi_r_sel)
    );

endmodule
