interface obi_r_if#(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int NBytes = DATA_WIDTH / 8,
    parameter int MANAGERS = 4,
    parameter int ID_WIDTH = 32,
    parameter int SUBORDINATES = 2
)();
        logic                    obi_rvalid;
        logic                    obi_rready;
        logic [DATA_WIDTH-1:0]   obi_rdata;
        logic                    obi_rerr;
        logic [ID_WIDTH-1:0]     obi_rid;

        modport master (input obi_rvalid, obi_rdata, obi_rerr, obi_rid,
                        output obi_rready);
        modport slave (output obi_rvalid, obi_rdata, obi_rerr, obi_rid,
                        input obi_rready);
endinterface
