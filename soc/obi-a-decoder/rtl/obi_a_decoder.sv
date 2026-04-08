import soc_defines::addr_map;

// OBI A channel decoder
module obi_a_decoder #(
    parameter int SUBORDINATES = 8,
    parameter int ADDR_WIDTH = 32,
    //parameter bit [ADDR_WIDTH-1:0] END_ADDRESS = 32'h80000000
    parameter int NoMAPS = 8
)
(
    input   logic [ADDR_WIDTH-1:0]              req_address_i,
    input   soc_defines::addr_map [NoMAPS-1:0]  address_maps_i, 
    input   logic                               config_ready_i,     
    input   logic                               default_sel_en_i,
    input   logic [SEL_WIDTH-1:0]               default_sel_i,
    //output  logic [SUBORDINATES-1:0]    obi_a_sel_o // Outputs a 1-hot encoded signal
    output  logic                               address_map_err_o,
    output  logic [SEL_WIDTH-1:0]               obi_a_sel_o

);
    localparam int SEL_WIDTH = $clog2(SUBORDINATES);

    assign dbg = (address_maps_i[1].base & address_maps_i[1].mask) == (req_address_i & address_maps_i[1].mask);

    always_comb begin
        obi_a_sel_o = default_sel_en_i ? default_sel_i : '1; // Default obi_a_sel_o signal value
        address_map_err_o = default_sel_en_i ? '0 : 1'b1;   
        for (int i=0; i<NoMAPS; i++) begin
            if (config_ready_i) begin 
            // If overlap, higher index has priority
                if ((address_maps_i[i].base & address_maps_i[i].mask) == (req_address_i & address_maps_i[i].mask)) begin
                    obi_a_sel_o = address_maps_i[i].idx;
                end
            end else begin
                address_map_err_o = 1'b1; // Set err in case of ongoing config
            end
        end
    end

    //logic [RANGE-1:0] addr_range;   // addr_range equals top RANGE bits of input req_address_i
    //assign addr_range = req_address_i[(ADDR_WIDTH-1): (ADDR_WIDTH-RANGE)];

    /*
    genvar i;
    generate;   // Generates logic for assigning bit value of 1-hot encoded signal 
                // by checking if input signal req_address_i is in the specified range
        for (i=0; i<SUBORDINATES; i++) begin

            //assign obi_a_sel_o[i] = ((addr_range == i) && (req_address_i < END_ADDRESS)) ? 1'b1  : 1'b0;
        end
    endgenerate
    */

endmodule


