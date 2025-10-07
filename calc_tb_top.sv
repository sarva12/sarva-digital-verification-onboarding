module calc_tb_top;
    import calc_tb_pkg::*;
    import calculator_pkg::*;
    
    parameter int DataSize = DATA_W;
    parameter int AddrSize = ADDR_W; 
    
    logic clk = 1'b0;
    logic rst;
    state_t state;
    
    calc_if #(.DataSize(DataSize), .AddrSize(AddrSize)) calc_if(.clk(clk));
    
    top_lvl my_calc (
        .clk (clk),
        .rst (calc_if.reset),
        .read_start_addr (calc_if.read_start_addr),
        .read_end_addr (calc_if.read_end_addr),
        .write_start_addr (calc_if.write_start_addr),
        .write_end_addr (calc_if.write_end_addr)
    );
    
    assign rst = calc_if.reset;
    assign state = my_calc.u_ctrl.state;
    
    calc_driver #(.DataSize(DataSize), .AddrSize(AddrSize)) calc_driver_h;
    calc_sequencer #(.DataSize(DataSize), .AddrSize(AddrSize)) calc_sequencer_h;
    calc_monitor #(.DataSize(DataSize), .AddrSize(AddrSize)) calc_monitor_h;
    calc_sb #(.DataSize(DataSize), .AddrSize(AddrSize)) calc_sb_h;
    
    always #5 clk = ~clk;

    task write_sram(input [AddrSize-1:0] addr, input [DataSize-1:0] data, input logic block_sel);
        @(posedge clk);
        if (!block_sel)
            my_calc.sram_A.mem[addr] = data;
        else 
            my_calc.sram_B.mem[addr] = data;
        calc_driver_h.initialize_sram(addr, data, block_sel);
    endtask

    task automatic pulse_reset(int n = 2);
        calc_if.reset <= 1'b1;
        repeat (n) @(posedge clk);
        calc_if.reset <= 1'b0;
    endtask
    
    initial begin
        `ifdef CADENCE
        $shm_open("waves.shm");
        $shm_probe("AC");
        `endif
        
        calc_monitor_h = new(calc_if);
        calc_sb_h = new(calc_monitor_h.mon_box);
        calc_sequencer_h = new();
        calc_driver_h = new(calc_if, calc_sequencer_h.calc_box);
        
        fork
            calc_monitor_h.main();
            calc_sb_h.main();
        join_none
        
        // Global reset
        calc_driver_h.reset_task();
        repeat (20) @(posedge clk);
        
        // basic computation  
        $display("=== TEST PLAN: Basic Computation ===");
        
        // normal addition with no overflow 
        $display("Test: Normal addition with no overflow - SRAM addr 0x00");
        write_sram(9'h00, 32'h2, 0);      // A = 2
        write_sram(9'h00, 32'h3, 1);      // B = 3, Expected: 2+3=5
        calc_driver_h.start_calc(9'h00, 9'h00, 9'h00, 9'h00, 1);
        
        // normal addition with overflow
        $display("Test: Normal Addition with overflow - SRAM addr 0x01");
        write_sram(9'h01, 32'hFFFF_FFFF, 0);  // A = max value (0xFFFFFFFF)
        write_sram(9'h01, 32'h1, 1);          // B = 1, Expected: wraps to 0x00000000
        calc_driver_h.start_calc(9'h01, 9'h01, 9'h01, 9'h01, 1);
        

        // edge cases
        $display("=== TEST PLAN: Edge Cases ===");
        
        // zero addition
        $display("Test: Zero addition - SRAM addr 0x02");
        write_sram(9'h02, 32'h0, 0);      // A = 0
        write_sram(9'h02, 32'h0, 1);      // B = 0, Expected: 0+0=0
        calc_driver_h.start_calc(9'h02, 9'h02, 9'h02, 9'h02, 1);
        
        // max + 0
        $display("Test: Max + 0 - SRAM addr 0x03");
        write_sram(9'h03, 32'hFFFF_FFFF, 0);  
        write_sram(9'h03, 32'h0, 1);          
        calc_driver_h.start_calc(9'h03, 9'h03, 9'h03, 9'h03, 1);
        
        // data flow and SRAM integrity tests
        $display("=== TEST PLAN: Data Flow and SRAM Integrity ===");
        
        // data red
        $display("Test: Data Read - Write 0x1234 to address 0x10, read back");
        write_sram(9'h10, 32'h1234, 0);  // Initialize A=0x1234
        write_sram(9'h10, 32'h5678, 1);  // Initialize B=0x5678
        calc_driver_h.start_calc(9'h10, 9'h10, 9'h10, 9'h10, 1);  // Read then write
        
        // data write
        $display("Test: Data Write Overwrite - Write 0x5678 to address 0x11");
        write_sram(9'h11, 32'h1111, 0);
        write_sram(9'h11, 32'h2222, 1);
        calc_driver_h.start_calc(9'h11, 9'h11, 9'h11, 9'h11, 1);
        write_sram(9'h11, 32'h5678, 0);  
        write_sram(9'h11, 32'h9ABC, 1);
        calc_driver_h.start_calc(9'h11, 9'h11, 9'h11, 9'h11, 1);
        
        // timing and reset
        $display("=== TEST PLAN: Timing & Reset Tests ===");
        
        // reset functionality
        $display("Test: Reset functionality during operation");
        calc_driver_h.reset_task();
        write_sram(9'h20, 32'h100, 0);
        write_sram(9'h20, 32'h200, 1);

        calc_driver_h.start_calc(9'h20, 9'h22, 9'h30, 9'h32, 1'b1);

        repeat(5) @(posedge clk);
        pulse_reset(3);

        @(posedge clk);
        if (state !== S_IDLE) begin
            $error("Reset during operation failed - State: %s", state.name);
        end else begin
            $display("[PASS] Reset during operation -> IDLE state");
        end
        
        // random constrained testing
        $display("=== TEST PLAN: Random Constrained Testing ===");
        
        for (int i = 0; i < 25; i++) begin
            logic [AddrSize-1:0] read_start, read_end, write_start, write_end;
            int write_range, read_range;
            
            write_start = $urandom_range(100, 200);
            write_range = $urandom_range(1, 10);
            write_end = write_start + write_range;
            
            read_start = $urandom_range(0, 80);
            read_range = 2 * write_range;  
            read_end = read_start + read_range;
            
            if (read_end >= (2**AddrSize)) read_end = (2**AddrSize) - 1;
            if (write_end >= (2**AddrSize)) write_end = (2**AddrSize) - 1;
            
            for (int j = read_start; j <= read_end; j++) begin
                write_sram(j[AddrSize-1:0], $urandom(), 0);  
                write_sram(j[AddrSize-1:0], $urandom(), 1);  
            end
            
            $display("Random Test %0d: R[%0d:%0d] W[%0d:%0d] (read_range=%0d, write_range=%0d)", 
                     i+1, read_start, read_end, write_start, write_end, read_range, write_range);
            
            calc_driver_h.start_calc(read_start, read_end, write_start, write_end, 1);
        end
        

        // fsm coverage
        $display("=== TEST PLAN: FSM Coverage Tests ===");
        
        calc_driver_h.reset_task();
        
        // multi-word operations
        for (int i = 0; i < 8; i++) begin
            write_sram(9'h40+i, 32'h100 + i, 0);
            write_sram(9'h40+i, 32'h200 + i, 1);
        end
        calc_driver_h.start_calc(9'h40, 9'h47, 9'h50, 9'h53, 1);
        

        $display("Testing invalid ranges - DUT should go to END state");
        
        calc_driver_h.start_calc(9'h100, 9'h99, 9'h110, 9'h109, 1);
        wait(state == S_END);
        repeat(10) @(posedge clk);
        
        calc_driver_h.start_calc(9'h85, 9'h84, 9'h95, 9'h97, 1);
        wait(state == S_END);
        repeat(5) @(posedge clk);
        
        $display("=== ALL TEST PLAN REQUIREMENTS COMPLETED ===");
        
        $finish;
    end
    
    // ASSERTIONS
    
    // reset assertion - fixed to check every cycle reset is asserted
    property p_reset_to_idle;
        @(posedge clk) calc_if.reset |-> ##1 (state == S_IDLE);
    endproperty
    RESET_FUNC: assert property (p_reset_to_idle)
        else $error("Reset assertion failed at time %0t", $time);
    
    // buffer control assignment
    property p_buffer_control_assignment;
        @(posedge clk) (!calc_if.reset && state == S_RWAIT) |-> ##1 (my_calc.u_ctrl.buffer_control_q == $past(my_calc.u_ctrl.half));
    endproperty
    BUFFER_CONTROL_ASSIGNMENT: assert property (p_buffer_control_assignment)
        else $error("Buffer control assignment assertion failed at time %0t", $time);
    
    // address limit verification
    property p_valid_addr_limit;
        @(posedge clk)(!calc_if.reset && (my_calc.read || my_calc.write)) |-> ((my_calc.r_addr < 512) && (my_calc.w_addr < 512));  
    endproperty
    VALID_ADDR_LIMIT: assert property (p_valid_addr_limit)
        else $error("Address exceeds 9-bit limit at time %0t", $time);
    
    // validate address ordering 
    property p_valid_operation_ordering;
        @(posedge clk)(!calc_if.reset && state != S_IDLE && state != S_END) |->((calc_if.read_start_addr <= calc_if.read_end_addr) && (calc_if.write_start_addr <= calc_if.write_end_addr));
    endproperty
    VALID_OP_ORDER: assert property (p_valid_operation_ordering)
        else $error("Address ordering violation during valid operation at time %0t", $time);
    
    // current read address within range
    property p_current_read_addr_in_range;
        @(posedge clk)(!calc_if.reset && my_calc.read) |-> (my_calc.r_addr >= calc_if.read_start_addr && my_calc.r_addr <= calc_if.read_end_addr);
    endproperty
    CURRENT_READ_ADDR_IN_RANGE: assert property (p_current_read_addr_in_range)
        else $error("Current read address %0h outside range [%0h:%0h] at time %0t", 
                    my_calc.r_addr, calc_if.read_start_addr, calc_if.read_end_addr, $time);
    
    // current write address within range
    property p_current_write_addr_in_range;
        @(posedge clk)(!calc_if.reset && my_calc.write) |-> (my_calc.w_addr >= calc_if.write_start_addr && my_calc.w_addr <= calc_if.write_end_addr);
    endproperty
    CURRENT_WRITE_ADDR_IN_RANGE: assert property (p_current_write_addr_in_range)
        else $error("Current write address %0h outside range [%0h:%0h] at time %0t", 
                    my_calc.w_addr, calc_if.write_start_addr, calc_if.write_end_addr, $time);
    
endmodule