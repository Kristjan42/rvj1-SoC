    parameter int ADDR_WIDTH = 32;
    parameter int DATA_WIDTH = 32;
    parameter int NBytes = DATA_WIDTH / 8;
    parameter int MANAGERS = 2;
    parameter int ID_WIDTH = 32;

package soc_defines;


    typedef struct packed{
        logic                           obi_areq;
        logic [ADDR_WIDTH-1:0]          obi_aadr;
        logic                           obi_awe;
        logic [NBytes-1:0]              obi_abe;
        logic [DATA_WIDTH-1:0]          obi_awdata;
        logic [ID_WIDTH-1:0]            obi_aid;
        logic [$clog2(MANAGERS)-1:0]    obi_mid;
    } obi_a;


    typedef struct packed{
        logic                    obi_rvalid;
        logic [DATA_WIDTH-1:0]   obi_rdata;
        logic                    obi_rerr;
        logic [ID_WIDTH-1:0]     obi_rid;
    } obi_r;

endpackage






