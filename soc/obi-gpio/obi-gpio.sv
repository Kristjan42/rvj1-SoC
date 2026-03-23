
`define GPIO_READ_OFF 7'h00
`define GPIO_WRITE_OFF 7'h04


module obi_gpio #(
    parameter OBI_ADDR_WIDTH = 32,
    parameter OBI_DATA_WIDTH = 32

) (
    // GPIO interface
    input logic [15:0] gpio_in,            // GPIO input line
    output logic [15:0] gpio_out,             // GPIO output line
    // OBI SLAVE INTERFACE
    //***************************************
    input logic obi_clk_i,
    input logic obi_rstn_i,

    // ADDRESS CHANNEL
    input logic                         obi_req_i,
    output  logic                       obi_gnt_o,
    input logic [OBI_ADDR_WIDTH-1:0]    obi_addr_i,
    input logic                         obi_we_i,
    input logic [OBI_DATA_WIDTH-1:0]    obi_w_data_i,
    input logic [               3:0]    obi_be_i,

    // RESPONSE CHANNEL
    output logic    obi_r_valid_o,
    output logic    [OBI_DATA_WIDTH-1:0] obi_r_data_o
);

    
    // OBI interface logic
    // Write interface
    logic wr_en;
    assign wr_en = obi_we_i & (obi_gnt_o & obi_req_i) & (obi_addr_i[6:0] == `GPIO_WRITE_OFF); // Needs to ensure write request is valid and handshake occured in address phase

    logic rd_en;
    assign rd_en = !obi_we_i & (obi_gnt_o & obi_req_i) & (obi_addr_i[6:0] == `GPIO_READ_OFF); // read from the GPIO read register when there is a valid read request and the address is correct

    // reg data 0x0
    logic[15:0] gpo_reg;
    always_ff @(posedge obi_clk_i) begin
        if (!obi_rstn_i) begin
            gpo_reg <= 0;
        end else begin
            if (wr_en) begin
                gpo_reg <= obi_w_data_i[15:0];
            end
        end
    end

    // GPIO is always ready to accept data, so grant is always high when there is a request
    assign obi_gnt_o = 1'b1;

    // generation of valid sinal and read data for read response
    always_ff @(posedge obi_clk_i) begin
        if (!obi_rstn_i) begin
            obi_r_valid_o <= 0;
        end else begin
            obi_r_valid_o <= (obi_gnt_o & obi_req_i); // valid read response when there is a read request
        end
    end

    // generation of read data for read response
    always_ff @(posedge obi_clk_i) begin
        if (!obi_rstn_i) begin
            obi_r_data_o <= 0;
        end else begin
            if (rd_en) begin
                obi_r_data_o <= {16'b0, gpo_reg};
            end
        end
    end



endmodule



