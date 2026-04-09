import soc_defines::obi_a;
import soc_defines::obi_r;

//`include "/foss/designs/rvj1-SoC/soc/fifo/rtl/fifo"

`include "../../fifo/rtl/fifo"
`include "../../lf-lfsr-prng/rtl/lf_lfsr_prng"

// OBI slave module
module obi_slave #(
    parameter int MANAGERS_CONS = 2, // No. of managers connected to slave
    parameter int FIFO_DEPTH = 8

)
(
    input   logic clk_i,
    input   logic rstn_i,

// OBI A channels Slave-Masters
    input soc_defines::obi_a obi_a_channels_i [MANAGERS_CONS],
    output logic obi_agnt_array_o [MANAGERS_CONS],

// OBI R channels Slave-Masters
    output soc_defines::obi_r obi_r_channels_o [MANAGERS_CONS],
    input logic obi_rready_array_i [MANAGERS_CONS],


    output logic [ADDR_WIDTH-1:0]           obi_aadr_o,
    output logic                            obi_awe_o,
    output logic [NBytes-1:0]               obi_abe_o,
    output logic [DATA_WIDTH-1:0]           obi_awdata_o,
    output logic                            req_valid_o,
    input  logic                            req_read_i,

    input  logic                            rsp_write_i,
    output logic                            rsp_ready_o,
    input  logic [DATA_WIDTH-1:0]           obi_rdata_i,
    input  logic                            obi_rerr_i

);

    localparam int MANAGERS_WIDTH = $clog2(MANAGERS_CONS);

    localparam int                   LFSR_WIDTH = 16;
    localparam int                   PRN_WIDTH = ($clog2(MANAGERS_CONS)+1); // Should be MANAGERS + 1 since the MSB is used in arbitering
    localparam logic[LFSR_WIDTH-1:0] SEED = 'b1000000000000000;
// Polinomial representation in bin, should be a max period primitive polinomial 2^(n-1) where n = LFSR_WIDTH
    localparam logic[LFSR_WIDTH-1:0] TAP_MASK = LFSR_WIDTH'('b1011010000000000); // 16 bit lfsr tap mask 'b1011010000000000
// eg. LFSR_WIDTH = 4, x^4 + x^3 + 1 = 1100 = TAP_MASK 
// List of taps: https://www.physics.otago.ac.nz/reports/electronics/ETR2012-1.pdf
    logic [LFSR_WIDTH-1:0]  lfsr_state_in;
    logic [LFSR_WIDTH-1:0]  lfsr_state_out;
    logic [PRN_WIDTH-1:0]   prn;
    lf_lfsr_prng #(
        LFSR_WIDTH,
        PRN_WIDTH,
        TAP_MASK
    ) prng_inst (
        .state_i(lfsr_state_in),
        .state_o(lfsr_state_out),
        .prn_o(prn)
    );

// Seed lfsr each cycle to generate a new prn
    always_ff @(posedge clk_i) begin
        if (~rstn_i) begin
            lfsr_state_in <= SEED;
        end else begin
            lfsr_state_in <= lfsr_state_out;
        end
    end

    localparam int ID_FIFO_WIDTH = (ID_WIDTH + $clog2(MANAGERS));
    localparam int REQ_FIFO_WIDTH = ($bits(soc_defines::obi_a) - ID_FIFO_WIDTH -1);

    logic id_wr_en;
    logic id_rd_en;
    logic [ID_FIFO_WIDTH-1:0] id_data_in;
    logic [ID_FIFO_WIDTH-1:0] id_data_out;
    logic id_fifo_empty;
    logic id_fifo_full;
    fifo #(
        FIFO_DEPTH,
        ID_FIFO_WIDTH
    ) id_fifo (
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .wr_en_i(id_wr_en),
        .rd_en_i(id_rd_en),
        .full_o(id_fifo_full),
        .empty_o(id_fifo_empty),
        .w_data_i(id_data_in),
        .r_data_o(id_data_out)
    );

    logic req_wr_en;
    logic req_rd_en;
    logic [REQ_FIFO_WIDTH-1:0] req_data_in;
    logic [REQ_FIFO_WIDTH-1:0] req_data_out;
    logic req_fifo_empty;
    logic req_fifo_full;
    fifo #(
        FIFO_DEPTH,
        REQ_FIFO_WIDTH
    ) request_fifo (
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .wr_en_i(req_wr_en),
        .rd_en_i(req_rd_en),
        .full_o(req_fifo_full),
        .empty_o(req_fifo_empty),
        .w_data_i(req_data_in),
        .r_data_o(req_data_out)
    );
    assign req_rd_en = req_valid_o & req_read_i;
    assign req_valid_o = ~req_fifo_empty;
    assign obi_aadr_o = req_data_out[ADDR_WIDTH-1:0];
    assign obi_awe_o = req_data_out[ADDR_WIDTH];
    assign obi_abe_o = req_data_out[ADDR_WIDTH + NBytes: ADDR_WIDTH +1];
    assign obi_awdata_o = req_data_out[ADDR_WIDTH + NBytes + DATA_WIDTH : ADDR_WIDTH + NBytes + 1];

    
    localparam int RSP_FIFO_WIDTH = ($bits(soc_defines::obi_r) - ID_WIDTH -1);

    logic rsp_wr_en;
    logic rsp_rd_en;
    logic [RSP_FIFO_WIDTH-1:0] rsp_data_in;
    logic [RSP_FIFO_WIDTH-1:0] rsp_data_out;
    logic rsp_fifo_empty;
    logic rsp_fifo_full;
    fifo #(
        FIFO_DEPTH,
        RSP_FIFO_WIDTH
    ) response_fifo (
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .wr_en_i(rsp_wr_en),
        .rd_en_i(rsp_rd_en),
        .full_o(rsp_fifo_full),
        .empty_o(rsp_fifo_empty),
        .w_data_i(rsp_data_in),
        .r_data_o(rsp_data_out)
    );
    assign rsp_ready_o = ~rsp_fifo_full;
    assign rsp_wr_en = rsp_write_i;
    assign rsp_data_in = {obi_rdata_i, obi_rerr_i};

// DMUX
    assign rsp_sel = id_data_out[ID_FIFO_WIDTH-1: ID_FIFO_WIDTH - $clog2(MANAGERS)];
    always_comb begin
        obi_r_channels_o = '{default: '0};
        rsp_rd_en = '0;
        id_rd_en = '0;
        if (~rsp_fifo_empty && ~id_fifo_empty) begin
            obi_r_channels_o[rsp_sel].obi_rvalid = '1;
            obi_r_channels_o[rsp_sel].obi_rdata = rsp_data_out[DATA_WIDTH:1];
            obi_r_channels_o[rsp_sel].obi_rerr = rsp_data_out[0];
            obi_r_channels_o[rsp_sel].obi_rid = id_data_out[ID_WIDTH-1:0];
            if (obi_rready_array_i[rsp_sel] == '1) begin
                rsp_rd_en = '1;
                id_rd_en = '1;
            end
        end
    end

    logic [MANAGERS_WIDTH-1:0] areq_vector;
    always_comb begin
        areq_vector = '0;
        for (int i = 0; i<MANAGERS_CONS; ++i) begin
            areq_vector[i] = obi_a_channels_i[i].obi_areq;
        end
    end

// Arbiter
    logic [MANAGERS_WIDTH-1:0]      skip_mask;
    logic [PRN_WIDTH-2:0]           idx;
    logic [PRN_WIDTH-2:0]           active_idx;
    logic                           prn_miss;
    logic                           selected;
    always_comb begin
        req_wr_en = '0;
        id_wr_en = '0;
        id_data_in = '0;
        req_data_in = '0;
        obi_agnt_array_o = '{default: '0};
        idx = prn[PRN_WIDTH-2:0];
        active_idx = '0;
        prn_miss = '0;
        selected = '0;
        if (~req_fifo_full || ~id_fifo_full) begin
            if (obi_a_channels_i[idx].obi_areq == '0) begin
                prn_miss = '1;
            end
            if (prn[PRN_WIDTH-1] == 0) begin
                for (int i = 0; i<MANAGERS_CONS; ++i) begin
                    if (obi_a_channels_i[MANAGERS_WIDTH'(idx+i)].obi_areq == '1 &&
                        selected == '0 &&
                        ((prn_miss == '1 && skip_mask[MANAGERS_WIDTH'(idx+i)] == '0) || prn_miss == '0 || ((areq_vector && skip_mask) == areq_vector))
                        ) begin
                        //req_data_in = obi_a_channels_i[MANAGERS_WIDTH'(idx+i)][REQ_FIFO_WIDTH:0];
                        req_data_in = {
                            obi_a_channels_i[MANAGERS_WIDTH'(idx+i)].obi_awdata,
                            obi_a_channels_i[MANAGERS_WIDTH'(idx+i)].obi_abe,
                            obi_a_channels_i[MANAGERS_WIDTH'(idx+i)].obi_awe,
                            obi_a_channels_i[MANAGERS_WIDTH'(idx+i)].obi_aadr
                        };
                        //id_data_in = obi_a_channels_i[MANAGERS_WIDTH'(idx+i)][$bits(soc_defines::obi_a)-1: $bits(soc_defines::obi_a) - ID_FIFO_WIDTH ];
                        id_data_in = {
                            obi_a_channels_i[MANAGERS_WIDTH'(idx+i)].obi_mid,
                            obi_a_channels_i[MANAGERS_WIDTH'(idx+i)].obi_aid
                        };
                        //obi_agnt_array_o[MANAGERS_WIDTH'(idx+i)] = ~req_fifo_full;
                        selected = '1;
                        active_idx = MANAGERS_WIDTH'(idx+i);
                        req_wr_en = '1;
                        id_wr_en = '1;
                    end else begin
                        obi_agnt_array_o[MANAGERS_WIDTH'(idx+i)] = '0;
                    end
                end
            end else begin
                for (int i = MANAGERS_CONS; i>=0; --i) begin
                    if (obi_a_channels_i[MANAGERS_WIDTH'(idx+i)].obi_areq == '1 &&
                        selected == '0 &&
                        ((prn_miss == '1 && skip_mask[MANAGERS_WIDTH'(idx+i)] == '0) || prn_miss == '0 || ((areq_vector && skip_mask) == areq_vector))
                        ) begin
                        //req_data_in = obi_a_channels_i[MANAGERS_WIDTH'(idx+i)][REQ_FIFO_WIDTH:1];
                        req_data_in = {
                            obi_a_channels_i[MANAGERS_WIDTH'(idx+i)].obi_awdata,
                            obi_a_channels_i[MANAGERS_WIDTH'(idx+i)].obi_abe,
                            obi_a_channels_i[MANAGERS_WIDTH'(idx+i)].obi_awe,
                            obi_a_channels_i[MANAGERS_WIDTH'(idx+i)].obi_aadr
                        };
                        //id_data_in = obi_a_channels_i[MANAGERS_WIDTH'(idx+i)][$bits(soc_defines::obi_a)-1: $bits(soc_defines::obi_a) - ID_FIFO_WIDTH ];
                        id_data_in = {
                            obi_a_channels_i[MANAGERS_WIDTH'(idx+i)].obi_mid,
                            obi_a_channels_i[MANAGERS_WIDTH'(idx+i)].obi_aid
                        };
                        //obi_agnt_array_o[MANAGERS_WIDTH'(idx+i)] = ~req_fifo_full;
                        selected = '1;
                        active_idx = MANAGERS_WIDTH'(idx+i);
                        req_wr_en = '1;
                        id_wr_en = '1;
                    end else begin
                        obi_agnt_array_o[MANAGERS_WIDTH'(idx+i)] = '0;
                    end
                end
            end
            if (selected) begin
                obi_agnt_array_o[active_idx] = ~req_fifo_full;
            end
        end
    end

    
    always_ff @(posedge clk_i) begin
        if (rstn_i) begin
            skip_mask <= '0;   
        end else if (prn_miss && selected) begin
            skip_mask[active_idx] <= '1;    // set bit for selected master
            if ((areq_vector && skip_mask) == areq_vector) begin
                skip_mask <= (1'b1 << active_idx); // reset mask by only setting bit for selected master
            end
        end
        
    end

    
endmodule


