module fifo #(
    parameter int DEPTH=8,
    parameter int WIDTH=32 
) (
    input logic clk_i,
    input logic rstn_i,

    input logic                 wr_en_i,
    input logic                 rd_en_i,
    input logic [WIDTH-1:0]     w_data_i,
    output logic [WIDTH-1:0]    r_data_o,
    output logic                full_o,
    output logic                empty_o
    
);
// fifo #(
//     .DEPTH(8),
//     .WIDTH(32)
// ) fifo_inst (
//     .clk_i(clk_i),
//     .rstn_i(rstn_i),
//     .wr_en_i(wr_en_i),
//     .rd_en_i(rd_en_i),
//     .w_data_i(w_data_i),
//     .r_data_o(r_data_o),
//     .full_o(full_o),
//     .empty_o(empty_o)
// );

reg [$clog2(DEPTH)-1:0] wr_ptr;
reg [$clog2(DEPTH)-1:0] rd_ptr;

reg [WIDTH-1:0] fifo_storage[DEPTH];

reg rd_last;

assign full_o = (rd_ptr == wr_ptr) && !rd_last;
assign empty_o = (rd_ptr == wr_ptr) && rd_last;

assign r_data_o = fifo_storage[rd_ptr];

// FIFO write
always_ff @(posedge clk_i ) begin
    if (~rstn_i) begin
        wr_ptr <= '0;
    end else begin
        if (wr_en_i && !full_o) begin
            fifo_storage[wr_ptr] <= w_data_i;
            wr_ptr <= wr_ptr + 1'b1;
        end 
    end
end

// FIFO read
always_ff @(posedge clk_i ) begin
    if (~rstn_i) begin
        rd_ptr <= '0;
    end else begin
        if (rd_en_i && !empty_o) begin
            rd_ptr <= rd_ptr + 1'b1;
        end 
    end
end

// FIFO last operation tracking
// Used to determine whether the FIFO is empty or full
always_ff @(posedge clk_i) begin
    if (~rstn_i) begin
        rd_last <= 1'b1;
    end else begin
        if (rd_en_i && !empty_o) begin
            rd_last <= 1'b1;
        end else if (wr_en_i && !full_o) begin
            rd_last <= '0;
        end
    end
end
    
endmodule
