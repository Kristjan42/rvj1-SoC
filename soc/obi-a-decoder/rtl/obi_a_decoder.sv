// OBI A channel decoder

module obi_a_decoder #(
    parameter int SUBORDINATES = 8,
    parameter int ADDR_WIDTH = 32,
    parameter bit [ADDR_WIDTH-1:0] END_ADDRESS = 32'h80000000
)
(
    input   logic [ADDR_WIDTH-1:0]      req_address_i,
    output  logic [SUBORDINATES-1:0]    obi_a_sel_o // Outputs a 1-hot encoded signal  

);
    localparam int RANGE = $clog2(SUBORDINATES);

    logic [RANGE-1:0] addr_range;   // addr_range equals top RANGE bits of input req_address_i
    assign addr_range = req_address_i[(ADDR_WIDTH-1): (ADDR_WIDTH-RANGE)];

    genvar i;
    generate;   // Generates logic for assigning bit value of 1-hot encoded signal 
                // by checking if input signal req_address_i is in the specified range
        for (i=0; i<SUBORDINATES; i++) begin
            assign obi_a_sel_o[i] = ((addr_range == i) && (req_address_i < END_ADDRESS)) ? 1'b1  : 1'b0;
        end
    endgenerate
    

endmodule


