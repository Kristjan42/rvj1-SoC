import soc_defines::obi_a;
import soc_defines::obi_r;

`include "../../fifo/rtl/fifo"
`include "../../lf-lfsr-prng/rtl/lf_lfsr_prng"

// OBI slave module
module obi_xbar_slave #( // TODO rename module to xbar slave
    parameter int MANAGERS_CONS = 2, // No. of managers connected to slave
    parameter int FIFO_DEPTH = 8
)
(
    input   logic clk_i,
    input   logic rstn_i,

// OBI A channels Slave<-Masters
    input soc_defines::obi_a obi_a_channels_i [MANAGERS_CONS],
    output logic obi_agnt_array_o [MANAGERS_CONS],

// OBI R channels Slave->Masters
    output soc_defines::obi_r obi_r_channels_o [MANAGERS_CONS],
    input logic obi_rready_array_i [MANAGERS_CONS],

// OBI XBAR Slave->OBI Slave
    output logic [ADDR_WIDTH-1:0]           obi_aadr_o,
    output logic                            obi_awe_o,
    output logic [NBytes-1:0]               obi_abe_o,
    output logic [DATA_WIDTH-1:0]           obi_awdata_o,
    output logic                            req_valid_o,
    input  logic                            req_read_i,

// OBI XBAR Slave<-OBI Slave
    input  logic                            rsp_write_i,
    output logic                            rsp_ready_o,
    input  logic [DATA_WIDTH-1:0]           obi_rdata_i,
    input  logic                            obi_rerr_i

);

    localparam int MANAGERS_WIDTH = $clog2(MANAGERS_CONS);



// Leap Forward LFSR PRNG
    localparam int                   LFSR_WIDTH = 10;
    localparam int                   PRN_WIDTH = ($clog2(MANAGERS_CONS)+1); // Is + 1 since the MSB is used in arbitering
    localparam logic[LFSR_WIDTH-1:0] SEED = 'b0101010101;                   // SEED is used as a starting state (period start),  10 bit seed 'b0000000001, b0101010101
    localparam logic[LFSR_WIDTH-1:0] TAP_MASK = LFSR_WIDTH'('b1001000000);  // 16 bit lfsr tap mask 'b1011010000000000, 10 bit tap 'b1001000000
    // Polinomial representation in bin, should be a max period primitive polinomial (2^n)-1 where n = LFSR_WIDTH
    // eg. LFSR_WIDTH = 4, x^4 + x^3 + 1 = 1100 = TAP_MASK 
    // List of taps: https://www.physics.otago.ac.nz/reports/electronics/ETR2012-1.pdf

    logic [LFSR_WIDTH-1:0]  lfsr_state_in; // Input state to LFSR
    logic [LFSR_WIDTH-1:0]  lfsr_state_out; // State that the LFSR ended up in after 1 clock cycle
    logic [PRN_WIDTH-1:0]   prn; // The pseudo random number (PRN) generated
    lf_lfsr_prng #(
        LFSR_WIDTH,
        PRN_WIDTH,
        TAP_MASK
    ) prng_inst (
        .state_i(lfsr_state_in),
        .state_o(lfsr_state_out),
        .prn_o(prn)
    );

    // Seed LFSR each cycle to generate a new prn
    always_ff @(posedge clk_i) begin
        if (~rstn_i) begin
            lfsr_state_in <= SEED;  // On reset set LFSR state to SEED (period start)
        end else begin
            if (req_fifo_empty && ~req_wr_en) begin // If req FIFO is empty and there are no active requests, hold LFSR state to ensure the PRN's distribution
                lfsr_state_in <= lfsr_state_in;     // remains consistant when choosing which requester get's the grant (arbiter)
            end else if (~req_fifo_full && ~id_fifo_full) begin // While the slave module is able to grant requests, the LFSR 
                lfsr_state_in <= lfsr_state_out;                // continues to generate PRN's starting from the last state in the active period
            end else begin
                lfsr_state_in <= lfsr_state_in;
            end

        end
    end

// ID FIFO
    // The ID FIFO holds values of obi_aid and obi_mid signals from the granted request
    // The mid value is used as a control signal for the DMUX when choosing which manager to return the response to
    // The aid value is transmitted back to the manager as the obi_rid signal 
    localparam int ID_FIFO_WIDTH = (ID_WIDTH + $clog2(MANAGERS));
    
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

// REQ FIFO
    // The REQ FIFO holds values of obi_aadr, obi_awdata, obi_abe, obi_awe signals from the granted request
    // These values are read by the OBI Slave
    localparam int REQ_FIFO_WIDTH = ($bits(soc_defines::obi_a) - ID_FIFO_WIDTH -1);

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
    assign req_rd_en = req_valid_o & req_read_i; // REQ FIFO read enable  
    assign req_valid_o = ~req_fifo_empty;
    assign obi_aadr_o = req_data_out[ADDR_WIDTH-1:0];
    assign obi_awe_o = req_data_out[ADDR_WIDTH];
    assign obi_abe_o = req_data_out[(ADDR_WIDTH + NBytes) : (ADDR_WIDTH +1)];
    assign obi_awdata_o = req_data_out[(ADDR_WIDTH + NBytes + DATA_WIDTH) : (ADDR_WIDTH + NBytes + 1)];

// RSP FIFO
    // The RSP FIFO holds values of obi_rdata, obi_rerr signals from the OBI Slave response
    // These values along with obi_rid are transmitted back to the manager
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

// Vector of obi_areq signals
    logic [MANAGERS_CONS-1:0] areq_vector;
    always_comb begin
        areq_vector = '0;
        for (int i = 0; i<MANAGERS_CONS; ++i) begin
            areq_vector[i] = obi_a_channels_i[i].obi_areq;
        end
    end

// Skip Mask
    // The skip mask is used to determine if an active request should be skiped when a part of the PRN generated used to index 
    // the areq_vector does not result in an active request on that index and the arbiter has to resort to a round robin (RR) way
    // of choosing one of the active requests, it does so by starting the round from the index and progressing either left or right
    // based on the MSB value of the PRN, it grants the request to the first active requestor and its index is marked in the skip mask,
    // the skip mask is reset if it covers the active requests in the areq_vector
    // This ensures fairness when arbitering as it mitigates starvation of requestors in certain scenarios 
    logic [MANAGERS_CONS-1:0]       skip_mask;
    logic [MANAGERS_CONS-1:0]       skip_mask_next;

    always_comb begin
        skip_mask_next = skip_mask;
        if (prn_miss & selected) begin
            skip_mask_next[active_idx] = 1'b1; // Set skip bit for the granted requestor
            if (((areq_vector & skip_mask_next) == areq_vector) ) begin 
                skip_mask_next  = '0; // Skip mask is reset if it covers the the active requests
            end
        end
    end

    always_ff @(posedge clk_i) begin
        if (~rstn_i) begin
            skip_mask<= '0;   
        end else if (prn_miss & selected) begin
            skip_mask <= skip_mask_next;
        end
        
    end


// Arbiter
    // This arbiter is based on PRN's being generated and granting requests based on their value, 
    // if the value was to grant an inactive request it is considered as a PRN miss and the arbiter
    // resorts to a round robin (RR) way of choosing one of the active requests, it does so by starting 
    // the round from the index generated and progressing either left or right based on the MSB value of 
    // the PRN, it grants the request to the first active requestor and its index is marked in the skip mask
    logic [PRN_WIDTH-2:0]           idx;
    logic [PRN_WIDTH-2:0]           active_idx;
    logic                           prn_miss;
    logic                           selected;
    always_comb begin
        // Reset to defaults
        req_wr_en = '0;
        id_wr_en = '0;
        id_data_in = '0;
        req_data_in = '0;
        obi_agnt_array_o = '{default: '0};
        idx = prn[PRN_WIDTH-2:0];
        active_idx = '0;
        prn_miss = '0;
        selected = '0;
        if (~req_fifo_full && ~id_fifo_full) begin          // Only arbiter if REQ & ID FIFO's are not full
            prn_miss = ~obi_a_channels_i[idx].obi_areq;     // If request is not active, set prn_miss to high and vice versa 
            if (prn[PRN_WIDTH-1] == 0) begin                // Determines the direction of the round based on PRN's MSB value
                for (int i = 0; i<MANAGERS_CONS; ++i) begin // Progress the round
                    if (    (obi_a_channels_i[idx].obi_areq == '1) & ~selected &     // Check if request is active and if one has already been granted (selected)
                            ((prn_miss == '1 & skip_mask[idx] == '0) || prn_miss == '0 || ((areq_vector & skip_mask) == areq_vector))   // Check if request is to be skipped
                        ) begin
                        req_data_in = { // Data to be written into the REQ FIFO
                            obi_a_channels_i[idx].obi_awdata,
                            obi_a_channels_i[idx].obi_abe,
                            obi_a_channels_i[idx].obi_awe,
                            obi_a_channels_i[idx].obi_aadr
                        };
                        id_data_in = {  // Data to be written into the RSP FIFO
                            obi_a_channels_i[idx].obi_mid,
                            obi_a_channels_i[idx].obi_aid
                        };
                        selected = '1;      // Set selected to high to signal the end of the round
                        active_idx = idx;   // Set active idx to the id of the selected request
                        req_wr_en = '1;     // Set the req write enable signal to high so request gets written to REQ FIFO
                        id_wr_en = '1;      // Set the id write enable signal to high so request id's get written to ID FIFO
                    end else begin  // If request not granted or inactive
                        obi_agnt_array_o[idx] = '0; // Set grant to low
                        if (int'(idx) >= MANAGERS_CONS) begin
                            idx = '0;               // Reset idx (overflow)
                        end else begin
                            idx = idx + 1'b1;       // Increment idx
                        end
                    end
                end
            end else begin
                for (int i = 0; i<MANAGERS_CONS; ++i) begin // Progress the round
                    if (    (obi_a_channels_i[idx].obi_areq == '1) & ~selected &    // Check if request is active and if one has already been granted (selected)
                            ((prn_miss == '1 & skip_mask[idx] == '0) || prn_miss == '0 || ((areq_vector & skip_mask) == areq_vector))   // Check if request is to be skipped
                        ) begin
                        req_data_in = { // Data to be written into the REQ FIFO
                            obi_a_channels_i[idx].obi_awdata,
                            obi_a_channels_i[idx].obi_abe,
                            obi_a_channels_i[idx].obi_awe,
                            obi_a_channels_i[idx].obi_aadr
                        };
                        id_data_in = {  // Data to be written into the RSP FIFO
                            obi_a_channels_i[idx].obi_mid,
                            obi_a_channels_i[idx].obi_aid
                        };
                        selected = '1;      // Set selected to high to signal the end of the round
                        active_idx = idx;   // Set active idx to the id of the selected request
                        req_wr_en = '1;     // Set the req write enable signal to high so request gets written to REQ FIFO
                        id_wr_en = '1;      // Set the id write enable signal to high so request id's get written to ID FIFO
                    end else begin  // If request not granted or inactive
                        obi_agnt_array_o[idx] = '0; // Set grant to low
                        if (int'(idx) >= MANAGERS_CONS) begin
                            idx = '1;               // Reset idx (overflow)
                        end else begin
                            idx = idx - 1'b1;       // Increment idx
                        end
                    end
                end
            end
            if (selected) begin     // If a request has been granted
                obi_agnt_array_o[active_idx] = ~req_fifo_full;  // Set grant to high
            end
        end
    end

// OBI R channel DMUX
    logic [$clog2(MANAGERS_CONS)-1:0] rsp_sel; // DMUX control signal
    assign rsp_sel = MANAGERS_WIDTH'(id_data_out[ID_FIFO_WIDTH-1: (ID_FIFO_WIDTH - $clog2(MANAGERS))]);
    always_comb begin
        // Reset to defaults
        obi_r_channels_o = '{default: '0};
        rsp_rd_en = '0;
        id_rd_en = '0;
        if (~rsp_fifo_empty && ~id_fifo_empty) begin // If RSP FIFO has a valid response, set the selected R channel signal values
            // Set the response signals
            obi_r_channels_o[rsp_sel].obi_rvalid = '1;
            obi_r_channels_o[rsp_sel].obi_rdata = rsp_data_out[DATA_WIDTH:1];
            obi_r_channels_o[rsp_sel].obi_rerr = rsp_data_out[0];
            obi_r_channels_o[rsp_sel].obi_rid = id_data_out[ID_WIDTH-1:0];
            if (obi_rready_array_i[rsp_sel] == '1) begin // When manager is ready to recieve the response, read from RSP & ID FIFO
                rsp_rd_en = '1;
                id_rd_en = '1;
            end
        end
    end
    
endmodule


