// Leap forward LFSR PRNG

module lf_lfsr_prng#(
    parameter int                   LFSR_WIDTH = 16,
    parameter int                   PRN_WIDTH = 2, 
    parameter logic[LFSR_WIDTH-1:0] TAP_MASK = 'b1011010000000000 // Polinomial representation in hex, should be a max period primitive polinomial 2^(n-1) where n = LFSR_WIDTH
    // eg. LFSR_WIDTH = 4, x^4 + x^3 + 1 = 1100 = TAP_MASK 
    // List of taps: https://www.physics.otago.ac.nz/reports/electronics/ETR2012-1.pdf
)
(
    output logic [LFSR_WIDTH-1:0] state_o, // State at the end of the interleave 
    input  logic [LFSR_WIDTH-1:0] state_i, // Starting state, cant be 0

    output logic [PRN_WIDTH-1:0] prn_o // Pseudo random number 
);
    
    logic feedback;
    logic [LFSR_WIDTH-1:0] state;
    always_comb begin
        feedback = 'b0;
        prn_o = 'b0;
        state = '0;
        state = state_i;
        for (int i=0; i<LFSR_WIDTH; i++) begin // interleave 
            feedback = ^(state & TAP_MASK);
            if (i < PRN_WIDTH) begin
                prn_o[i] = state[LFSR_WIDTH-1]; 
            end               
            //state = {feedback, state[LFSR_WIDTH-1:1]};
            state = {state[LFSR_WIDTH-2:0], feedback};
        end
        state_o = state;
    end

endmodule

