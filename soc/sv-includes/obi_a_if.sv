interface obi_a_if#(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int NBytes = DATA_WIDTH / 8,
    parameter int MANAGERS = 4,
    parameter int ID_WIDTH = 32,
    parameter int SUBORDINATES = 2
)();
        logic                           obi_areq;
        logic                           obi_agnt;
        logic [ADDR_WIDTH-1:0]          obi_aadr;
        logic                           obi_awe;
        logic [NBytes-1:0]              obi_abe;
        logic [DATA_WIDTH-1:0]          obi_awdata;
        logic [ID_WIDTH-1:0]            obi_aid;

        modport master (output obi_areq, obi_aadr, obi_awe, obi_awdata, obi_abe, obi_aid,
                        input obi_agnt);
        modport slave (input obi_areq, obi_aadr, obi_awe, obi_awdata, obi_abe, obi_aid,
                        output obi_agnt);
endinterface
