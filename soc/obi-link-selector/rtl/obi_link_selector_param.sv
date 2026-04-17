import soc_defines::obi_a;
import soc_defines::obi_r;

// OBI link selector
module obi_link_selector_param #(
    parameter int SUBORDINATES = 8,
    parameter int ID_WIDTH = 32
)
(
// Manager-Selector OBI Link    
    input soc_defines::obi_a obi_a_i,
    output logic obi_agnt_o,

    output soc_defines::obi_r obi_r_o,
    input logic obi_rready_i,

// OBI A channels Selector-Slaves
    output soc_defines::obi_a [SUBORDINATES-1:0] obi_a_channels_o,
    input logic [SUBORDINATES-1:0] obi_agnt_array_i,

// OBI R channels Selector-Slaves
    input soc_defines::obi_r [SUBORDINATES-1:0] obi_r_channels_i,
    output logic [SUBORDINATES-1:0] obi_rready_array_o,
    

// OBI A decoder signals
    input   logic [$clog2(SUBORDINATES)-1:0]    obi_a_sel_i,
    input   logic                               address_map_err_i,

// OBI R decoder signals
    input   logic [SUBORDINATES-1:0] obi_r_sel_i,

    output  logic                    set_next_o,
    output  logic [ID_WIDTH-1:0]     rid_array_o[SUBORDINATES],

// OBI aid generator signals
    output  logic   gen_next_o    
);

// OBI A channel switching logic
    always_comb begin
        obi_agnt_o = '0;
        obi_a_channels_o = '{default: '0};
        obi_a_channels_o[obi_a_sel_i] = obi_a_i;
        obi_agnt_o = obi_agnt_array_i[obi_a_sel_i];
        if (address_map_err_i) begin
            // TODO handle err
        end
    end

// OBI R channel switching logic        
    always_comb begin
        obi_r_o = '0;
        // TODO handle err
        for (int j = 0; j<SUBORDINATES; j++) begin
                    rid_array_o[j] = obi_r_channels_i[j].obi_rid;
                    if (obi_r_sel_i == (1 << j)) begin
                        // Defualt value of all channels in array is 0, so starting id's have to start from 1
                        obi_r_o = obi_r_channels_i[j]; 
                        obi_rready_array_o[j] = obi_rready_i;
                    end else begin
                        obi_rready_array_o[j] = '0;
                    end
            end
    end

// Logic for generating r-decoder set_next id signal
    always_comb begin
        if (obi_r_o.obi_rvalid && obi_rready_i) begin
            set_next_o = 1'b1;
        end else begin
            set_next_o = '0;
        end
    end

// Logic for generating aid-generator gen_next id signal
    always_comb begin
        if (obi_a_i.obi_areq && obi_agnt_o) begin
            gen_next_o = 1'b1;
        end else begin
            gen_next_o = '0;
        end
    end

endmodule

