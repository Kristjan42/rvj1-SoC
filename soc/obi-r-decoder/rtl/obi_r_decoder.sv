// OBI R channel decoder

module obi_r_decoder #(
    parameter int SUBORDINATES = 8,
    parameter int ID_WIDTH = 32
    
)
(
    input   logic clk_i,
    input   logic rstn_i,

    input   logic set_next_i,
    input   logic [ID_WIDTH-1:0] rid_array_i[SUBORDINATES],
    output  logic [SUBORDINATES-1:0] obi_r_sel_o
);
    localparam int MAX_VALUE = (1 << ID_WIDTH) - 1;

    logic [ID_WIDTH-1:0] outstanding_id;


    always_comb begin   // Generates logic for assigning bit value of 1-hot encoded signal 
                        // by checking which channels obi_rid signal matches outstanding_id 
        for (int i=0; i<SUBORDINATES; i++) begin
            if (rid_array_i[i] == outstanding_id) begin
                    obi_r_sel_o[i] = 1'b1;
                end else begin
                    obi_r_sel_o[i] = 1'b0;
                end
        end
    end

    always_ff @(posedge clk_i) begin
        if (~rstn_i) begin
            outstanding_id <= 32'b1;
        end else begin
            if (set_next_i) begin
                if (outstanding_id == MAX_VALUE) begin
                    outstanding_id <= 32'b1;
                end else begin
                    outstanding_id <= outstanding_id + 1;
                end
            end
        end
    end

endmodule
