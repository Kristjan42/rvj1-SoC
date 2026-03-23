`include "../fifo/rtl/fifo.sv"

`define UART_CONF_OFF 7'h00
`define UART_SPEED_OFF 7'h04
`define UART_TX_OFF 7'h08
`define UART_RX_OFF 7'h0C

module obi_uart #(
    parameter OBI_ADDR_WIDTH = 32,
    parameter OBI_DATA_WIDTH = 32

) (
    // UART interface
    input logic rx,            // UART receive line
    output logic tx,             // UART transmit line
    // OBI SLAVE INTERFACE
    //***************************************
    input logic obi_clk_i,
    input logic obi_rstn_i,

    // ADDRESS CHANNEL
    input logic                      obi_req_i,
    output  logic                      obi_gnt_o,
    input logic [OBI_ADDR_WIDTH-1:0] obi_addr_i,
    input logic                      obi_we_i,
    input logic [OBI_DATA_WIDTH-1:0] obi_w_data_i,
    input logic [               3:0] obi_be_i,

    // RESPONSE CHANNEL
    output logic obi_r_valid_o,
    output logic [OBI_DATA_WIDTH-1:0] obi_r_data_o
);

    // instantiate the fifo interface circuit
    
    logic wr_en_transmitt;
    logic [7:0] r_data_transmitt, w_data_transmitt;
    logic full_transmitt, empty_transmitt;
     
    fifo #(
        .DEPTH(8),
        .WIDTH(8)
    ) fifo_transmitt (
        .clk_i(obi_clk_i),
        .rstn_i(!obi_rstn_i),
        .wr_en_i(wr_en_transmitt),
        .rd_en_i(ready_transmitt),
        .w_data_i(w_data_transmitt),
        .r_data_o(r_data_transmitt),
        .full_o(full_transmitt),
        .empty_o(empty_transmitt)
    );

    // instantiate the uart transmitter system 
    logic [15:0] limit_reg;
    logic ready_transmitt;


    logic uart_tx_start; 
    logic tx_done;
    assign uart_tx_start = uart_conf_reg[0] & !empty_transmitt; // start transmission when fifo is not empty

    transmitter_system transmitter_system_inst (
        .clock(obi_clk_i),
        .reset(!obi_rstn_i),
        .tx_start(uart_tx_start), // start transmission when fifo is not empty
        .limit(limit_reg),
        .data_in(r_data_transmitt),
        .tx(tx),
        .ready(ready_transmitt),
        .tx_done(tx_done) // not used in this design, but can be used for flow control in more complex designs
    );


    // instantiate fifo for UART receiver

    logic wr_en_receiver;
    logic [7:0] r_data_receiver, w_data_receiver;
    logic full_receiver, empty_receiver;

    fifo #(
        .DEPTH(8),
        .WIDTH(8)
    ) fifo_receiver (
        .clk_i(obi_clk_i),
        .rstn_i(!obi_rstn_i),
        .wr_en_i(wr_en_receiver),
        .rd_en_i(rd_bus_en),
        .w_data_i(w_data_receiver),
        .r_data_o(r_data_receiver),
        .full_o(full_receiver),
        .empty_o(empty_receiver)
    );


    // instantiate the uart receiver system
    logic uart_rx_start;
    assign uart_rx_start = uart_conf_reg[1] & !full_receiver; // start transmission when fifo is not empty

    // Instantiation template:
    uart_system_receiver uart_system_receiver_inst (
        .clock(obi_clk_i),
        .reset(!obi_rstn_i),
        .limit(limit_reg),
        .rx_start(uart_rx_start),
        .rx(rx),
        .data_out(w_data_receiver),
        .rx_valid(wr_en_receiver)
    );

    // OBI interface logic
    // Write interface
    logic wr_en;
    assign wr_en = obi_we_i & (obi_gnt_o & obi_req_i); // Needs to ensure write request is valid and handshake occured in address phase

    logic [2:0] wr_bus_en;
    assign wr_bus_en[0] = wr_en & (obi_addr_i[6:0] == `UART_CONF_OFF); // write to the first register
    assign wr_bus_en[1] = wr_en & (obi_addr_i[6:0] == `UART_SPEED_OFF); // write to the first register
    assign wr_bus_en[2] = wr_en & (obi_addr_i[6:0] == `UART_TX_OFF); // write to the first register 
    assign wr_en_transmitt = wr_bus_en[2];
    
    logic rd_bus_en;
    assign rd_bus_en = !obi_we_i & (obi_gnt_o & obi_req_i) & (obi_addr_i[6:0] == `UART_RX_OFF); // read from the receiver fifo when there is a valid read request and the address is correct

    // reg data 0x0
    logic[1:0] uart_conf_reg;
    always_ff @(posedge obi_clk_i) begin
        if (!obi_rstn_i) begin
            uart_conf_reg <= 0;
        end else begin
            if (wr_bus_en[0]) begin
                uart_conf_reg <= obi_w_data_i[1:0];
            end
        end
    end

    // reg data 0x4
    always_ff @(posedge obi_clk_i) begin
        if (!obi_rstn_i) begin
            limit_reg <= 0;
        end else begin
            if (wr_bus_en[1]) begin
                limit_reg <= obi_w_data_i[15:0];
            end
        end
    end

    // reg data 0x8  
    always_ff @(posedge obi_clk_i) begin
        if (!obi_rstn_i) begin
            w_data_transmitt <= 0;
        end else begin
            if (wr_bus_en[2]) begin
                w_data_transmitt <= obi_w_data_i[7:0];
            end
        end
    end


    // Grant logic generation
    always_comb begin
        case (obi_addr_i[6:0])
            `UART_TX_OFF: begin
                obi_gnt_o = !full_transmitt; 
            end
            `UART_RX_OFF: begin
                obi_gnt_o = !empty_receiver; 
            end
            default: begin
                obi_gnt_o = 1'b1;
            end
        endcase
    end

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
            if (obi_gnt_o & obi_req_i & obi_addr_i[6:0] == `UART_RX_OFF) begin
                obi_r_data_o <= {24'b0, r_data_receiver};
            end
        end
    end



endmodule




module baud_rate_generator // General Purpose counter        
    #(parameter PRESCALER_WIDTH = 4)
    (
        input logic clock,
        input logic reset,
        input logic [PRESCALER_WIDTH-1:0] limit,
        output logic baud_rate_tick
    );

    logic [PRESCALER_WIDTH-1:0] count;

    // when the counter reaches the limit, the sample_tick signal is generated

    always_ff @(posedge clock) begin
        if(reset) begin
            count <= 0;
        end else begin
            if(count == limit-1) begin
                count <= 0;
            end else begin
                count <= count + 1;
            end
        end
    end

    assign baud_rate_tick = (count == limit-1);
endmodule

module uart_fsm #(
    parameter DATA_WIDTH = 8
    ) 
(
    input logic clock,
    input logic reset,
    input logic [DATA_WIDTH-1:0] data_in,
    input logic baud_rate_tick,
    input logic tx_start,
    output logic tx,
    output logic tx_busy, // indicates that the transmitter is busy transmitting data
    output logic tx_done, // indicates that the transmission is done
    output logic baud_rst // used for baud rate generator reset
);

    // define the states
    typedef enum logic [1:0] { // binary encoding
        IDLE,
        START,
        DATA,
        STOP
    } state_uart_t;
    
 
    state_uart_t state, next_state;

    // signal declarations 
    logic [DATA_WIDTH-1:0] b_reg, b_reg_next;
    logic [3:0] n_counter, n_counter_next; // counter for number of symbols 
    logic tx_busy_next, tx_done_next, tx_reg, tx_reg_next;


    // state register
    always_ff @(posedge clock) begin
        if (reset) begin
            state <= IDLE;
            b_reg <= 0;
            n_counter <= 0;
            tx_busy <= 0;
            tx_done <= 0;
            tx_reg <= 1; // idle state state of the tx line
        end
        else begin
            state <= next_state;
            b_reg <= b_reg_next;
            n_counter <= n_counter_next;
            tx_busy <= tx_busy_next;
            tx_reg <= tx_reg_next;
            tx_done <= tx_done_next;
        end
    end

    // state transition logic
    always_comb begin
        next_state = state;
        b_reg_next = b_reg;
        n_counter_next = n_counter;
        tx_busy_next = 1'b1; // default to busy, will be set to 0 in IDLE state
        tx_done_next = 1'b0; // default to not done, will be set to 1 in STOP state
        tx_reg_next = tx_reg;
        baud_rst = 1'b0;

        case (state)
            IDLE : begin
                tx_reg_next = 1'b0;
                if(tx_start) begin
                    next_state = START;
                    b_reg_next = data_in;
                    baud_rst = 1'b1;
                end
            end 
            START : begin
                tx_reg_next = 1'b0;
                if (baud_rate_tick) begin
                    next_state = DATA;
                    n_counter_next = 0;
                end
            end
            DATA : begin
                tx_reg_next = b_reg[0];
                if (baud_rate_tick) begin
                    if (n_counter == DATA_WIDTH-1) begin
                        next_state = STOP;
                    end
                    else begin
                        n_counter_next = n_counter + 1;
                        b_reg_next = {1'b0, b_reg[7:1]};
                    end
                end
            end
            STOP : begin
                tx_reg_next = 1'b1;
                if (baud_rate_tick) begin
                    begin
                        next_state = IDLE;
                        tx_done_next = 1'b1;
                    end
                end
            end
        endcase
    end

    assign tx = tx_reg;
endmodule

module transmitter_system(
    input logic clock,
    input logic reset,
    input logic [15:0] limit, 
    input logic tx_start,
    input logic [7:0] data_in,
    output logic tx,
    output logic ready,
    output logic tx_done
);

    logic baud_rate_tick;
    logic baud_rst;
    logic local_reset;
    logic tx_busy;
    assign local_reset = reset | baud_rst;

    baud_rate_generator #(
        .PRESCALER_WIDTH(16)
    ) baud_rate_generator_inst (
        .clock(clock),
        .reset(local_reset),
        .limit(limit),
        .baud_rate_tick(baud_rate_tick)
    );

    uart_fsm #(
        .DATA_WIDTH(8)
    ) uart_fsm_inst (
        .clock(clock),
        .reset(reset),
        .data_in(data_in),
        .baud_rate_tick(baud_rate_tick),
        .tx_start(tx_start),
        .tx(tx),
        .tx_done(tx_done),
        .tx_busy(tx_busy),
        .baud_rst(baud_rst)
    );

    assign ready = !tx_busy; // ready when not busy

endmodule

module uart_receiver #(
    parameter DBITS = 8,
    parameter SBITS = 1
) (
    input logic clock,
    input logic reset,
    input logic sample_tick,
    input logic rx, 
    output logic [DBITS-1:0] data_out,
    output logic rx_done,
    output logic chg_state
);

    // define the parameters
    localparam STOP_TICKS = SBITS*16;
    

    // define the states
    typedef enum logic [1:0] { // binary encoding
        IDLE,
        START,
        DATA,
        STOP
    } state_uart_t;
    
// Alternative encoding
//    typedef enum {
//   IDLE = 4'b0001,
//   START = 4'b0010,
//   DATA  = 4'b0100,
//   STOP = 4'b1000
// }  state_uart_t;

    state_uart_t state, next_state;

    // signal declarations 
    logic [DBITS-1:0] shift_reg, shift_reg_next;
    logic [4:0] s_counter, s_counter_next; // counter for sample_tick
    logic [3:0] n_counter, n_counter_next; // counter for number of symbols 
    logic rx_done_next, chg_state_next;
    // state register
    always_ff @(posedge clock) begin : state_reg
        if (reset) begin
            state <= IDLE;
            shift_reg <= 0;
            s_counter <= 0;
            n_counter <= 0;
            rx_done <= 0;
            chg_state <= 0;
        end
        else begin
            state <= next_state;
            shift_reg <= shift_reg_next;
            s_counter <= s_counter_next;
            n_counter <= n_counter_next;
            rx_done <= rx_done_next;
            chg_state <= chg_state_next;
        end
    end

    // next state logic
    always_comb begin : next_state_logic
        // default values, otherwise we will have a latch
        // need to cover all the cases 
        next_state = state;
        rx_done_next = 0;
        chg_state_next = 0;
        shift_reg_next = shift_reg;
        s_counter_next = s_counter;
        n_counter_next = n_counter;
        
        
        case (state)
            IDLE : begin
                if (rx == 0) begin
                    next_state = START;
                    s_counter_next = 0;
                    rx_done_next = 0;
                    chg_state_next = 1;
                end
            end
            START : begin
                if(sample_tick) begin
                    if (s_counter == 7) begin
                        // cannot do n_counter = 0, two blocks power the same signal 
                        n_counter_next = 0;
                        s_counter_next = 0;
                        chg_state_next = 1;
                        // do not forget to update state 
                        next_state = DATA;
                    end else begin
                        s_counter_next = s_counter + 1;
                    end
                end
            end 
            DATA : begin
                if(sample_tick) begin
                   if (s_counter == 15) begin
                        s_counter_next = 0;
                        shift_reg_next = {rx,shift_reg[DBITS-1:1]};
                        if (n_counter == DBITS-1) begin
                            next_state = STOP;
                            chg_state_next = 1;
                        end else begin
                            n_counter_next = n_counter + 1;
                        end
                   end  else begin
                        s_counter_next = s_counter + 1;
                   end
                end
            end
            STOP : begin
                if (sample_tick) begin
                    if (s_counter == STOP_TICKS - 1) begin
                        rx_done_next = 1;
                        next_state = IDLE;
                        chg_state_next = 1;
                    end else begin
                        s_counter_next = s_counter + 1;
                    end
                end
            end
        endcase
    end

    // output 
    assign data_out = shift_reg;

endmodule


module uart_system_receiver (
    input logic clock,
    input logic reset, 
    input logic [15:0] limit, 
    input logic rx_start,
    input logic rx, 
    output logic [7:0] data_out, 
    output logic rx_valid
);


// Instantiation template:
// uart_system_receiver #(
//     // No parameters for this module
// ) uart_system_receiver_inst (
//     .clock(obi_clk_i),
//     .reset(!obi_rstn_i),
//     .limit(limit_reg),
//     .rx(rx),
//     .data_out(data_out),
//     .rx_valid(rx_valid)
// );



// define parameters for prescaler 
logic sample_tick;
logic local_reset;
assign local_reset = reset & !rx_start; // reset the baud rate generator when not in receiving process

baud_rate_generator #(
    .PRESCALER_WIDTH(16)
) sample_tick_generator (
    .clock(clock),
    .reset(local_reset),
    .limit(limit),
    .baud_rate_tick(sample_tick)
);

// define the parameters for uart_receiver 

localparam DBITS = 8;
localparam SBITS = 1;

logic rx_done;
logic chg_state;

uart_receiver #(
    .DBITS(DBITS),
    .SBITS(SBITS)
) Uart_Machine (
    .clock(clock),
    .reset(local_reset),
    .sample_tick(sample_tick),
    .rx(rx),
    .data_out(data_out),
    .rx_done(rx_done),
    .chg_state(chg_state)
);

// define the interface circuit 
assign rx_valid = rx_done; // in this simple design, we can directly use rx_done as the valid signal, but in more complex design, we might need to do some additional processing to generate the valid signal

endmodule
