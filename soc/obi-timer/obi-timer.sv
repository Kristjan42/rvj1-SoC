

`define TIMER_CONF_OFF 7'h00
`define TIMER_COUNTL_OFF 7'h04
`define TIMER_COUNTH_OFF 7'h08


module obi_gpio #(
    parameter OBI_ADDR_WIDTH = 32,
    parameter OBI_DATA_WIDTH = 32

) (
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

    // Timer logic
    logic [63:0] timer_count;
    logic timer_start, timer_reset;


    always_ff @(posedge obi_clk_i) begin
        if (!obi_rstn_i) begin
            timer_count <= 0;
        end else begin
            if(timer_start) begin
                if(timer_reset) begin
                    timer_count <= 0;
                end else begin
                    timer_count <= timer_count + 1;
                end
            end
        end
    end

    // OBI interface logic
    // Write interface
    logic wr_en;
    assign wr_en = obi_we_i & (obi_gnt_o & obi_req_i) & (obi_addr_i[6:0] == `TIMER_CONF_OFF); // Needs to ensure write request is valid and handshake occured in address phase

    logic [1:0] rd_en_bus;
    assign rd_en_bus[0] = !obi_we_i & (obi_gnt_o & obi_req_i) & (obi_addr_i[6:0] == `TIMER_COUNTL_OFF); // read from the TIMER_COUNTL register when there is a valid read request and the address is correct
    assign rd_en_bus[1] = !obi_we_i & (obi_gnt_o & obi_req_i) & (obi_addr_i[6:0] == `TIMER_COUNTH_OFF); // read from the TIMER_COUNTH register when there is a valid read request and the address is correct

    // reg data 0x0
    logic[31:0] timer_conf;
    always_ff @(posedge obi_clk_i) begin
        if (!obi_rstn_i) begin
            timer_conf <= 0;
        end else begin
            if (wr_en) begin
                timer_conf <= obi_w_data_i[31:0];
            end
        end
    end

    assign timer_start = timer_conf[0];
    assign timer_reset = timer_conf[1];

    // Timer is always ready to accept data, so grant is always high when there is a request
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
            if (rd_en_bus[0]) begin
                obi_r_data_o <= timer_count[31:0];
            end else if (rd_en_bus[1]) begin
                obi_r_data_o <= timer_count[63:32];
            end
        end
    end



endmodule



