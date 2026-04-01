// OBI aid generator

module obi_aid_generator #(
    parameter int ID_WIDTH = 32
)
(
    input   logic clk_i,
    input   logic rstn_i,

    input   logic                   gen_next_i, 
    output  logic [ID_WIDTH-1:0]    obi_aid_o 
);
    localparam int MAX_VALUE = (1 << ID_WIDTH) - 1; // Max value of id signal
    
    logic [ID_WIDTH-1:0] id;

    assign obi_aid_o = id;

    always_ff @(posedge clk_i) begin
        if (~rstn_i) begin
            id <= 32'b1;
        end else begin
            if (gen_next_i) begin
                if (id == MAX_VALUE) begin  // Checks if id reached MAX_VALUE, sets signal value to 1, otherwise increments
                    id <= 32'b1;            // Needs to be set to 1 as default values of obi_aid and obi_rid on all channels are 0 
                end else begin
                    id <= id + 1;
                end               
            end 
        end
    end

endmodule

