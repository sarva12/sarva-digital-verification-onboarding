module controller import calculator_pkg::*;(
    input  logic              clk_i,
    input  logic              rst_i,

    input  logic [ADDR_W-1:0] read_start_addr,
    input  logic [ADDR_W-1:0] read_end_addr,
    input  logic [ADDR_W-1:0] write_start_addr,
    input  logic [ADDR_W-1:0] write_end_addr,
    output logic              write,
    output logic [ADDR_W-1:0] w_addr,
    output logic [MEM_WORD_SIZE-1:0] w_data,

    output logic              read,
    output logic [ADDR_W-1:0] r_addr,
    input  logic [MEM_WORD_SIZE-1:0] r_data,
    output logic              buffer_control,

    output logic [DATA_W-1:0] op_a,
    output logic [DATA_W-1:0] op_b,

    input  logic [MEM_WORD_SIZE-1:0] buff_result
);

    state_t state, next;
    logic half, half_n;
    logic [ADDR_W-1:0] r_ptr, r_ptr_n;
    logic [ADDR_W-1:0] w_ptr, w_ptr_n;

    logic [DATA_W-1:0] op_a_q, op_b_q;
    logic buffer_control_q;

    assign op_a = op_a_q;
    assign op_b = op_b_q;
    assign buffer_control = buffer_control_q;

    always_ff @(posedge clk_i) begin
    if (rst_i) begin
        state <= S_IDLE;
        half  <= 1'b0;
        r_ptr <= '0;            
        w_ptr <= '0;              
        op_a_q <= '0;
        op_b_q <= '0;
        buffer_control_q <= 1'b0;
    end else begin
        state <= next;
        half  <= half_n;
        r_ptr <= r_ptr_n;
        w_ptr <= w_ptr_n;
        if (state == S_RWAIT) begin
            op_a_q <= r_data[31:0];
            op_b_q <= r_data[63:32];
            buffer_control_q <= half;
        end
    end
end

    always_comb begin
        read  = 1'b0;
        write = 1'b0;
        r_addr = r_ptr;
        r_ptr_n = r_ptr;
        w_addr = w_ptr;
        w_ptr_n = w_ptr;
        w_data = '0;
        next = state;
        half_n = half;

        case (state)

            S_IDLE: begin
                r_ptr_n = read_start_addr;
                w_ptr_n = write_start_addr;
                half_n  = 1'b0;
                if ((read_start_addr <= read_end_addr) &&
                    (write_start_addr <= write_end_addr))
                    next = S_READ;
                else
                    next = S_END;
            end

            S_READ: begin
                read   = 1'b1;
                r_addr = r_ptr;
                next   = S_RWAIT;
            end

            S_RWAIT: begin
                next = S_ADD;
            end

            S_ADD: begin
                if (half == 1'b0) begin
                    half_n = 1'b1;
                    next   = S_WSET; 
                end else begin
                    half_n = 1'b0;
                    next   = S_WSET;
                end
            end

            S_WSET: begin
                w_data = buff_result;
                w_addr = w_ptr;
                next   = S_WRITE;
            end

            S_WRITE: begin
                write  = 1'b1;
                w_data = buff_result;
                w_addr = w_ptr;
                if (w_ptr < write_end_addr) begin
                    w_ptr_n = w_ptr + 1;
                end
                if (r_ptr < read_end_addr) begin
                    r_ptr_n = r_ptr + 1;
                    next    = S_READ;
                end else begin
                    next = S_END;
                end
            end

            S_END: begin
                next = S_END;
            end

            default: next = S_IDLE;
        endcase
    end

endmodule
