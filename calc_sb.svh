
class calc_sb #(int DataSize, int AddrSize);

  int mem_a [2**AddrSize];
  int mem_b [2**AddrSize];
  logic second_read = 0;
  int golden_lower_data;
  int golden_upper_data;
  mailbox #(calc_seq_item #(DataSize, AddrSize)) sb_box;

  function new(mailbox #(calc_seq_item #(DataSize, AddrSize)) sb_box);
    this.sb_box = sb_box;
    // Initialize golden memory to known state
    for (int i = 0; i < 2**AddrSize; i++) begin
      mem_a[i] = 0;
      mem_b[i] = 0;
    end
  endfunction

  task main();
    calc_seq_item #(DataSize, AddrSize) trans;
    forever begin
      sb_box.get(trans);

      // Initialize SRAM - Update golden model
      if (trans.initialize) begin
        if (!trans.loc_sel) begin
          mem_a[trans.curr_wr_addr] = trans.lower_data;
          $display("[SB] Init SRAM A addr %0h data %0h", 
                   trans.curr_wr_addr, trans.lower_data);
        end else begin
          mem_b[trans.curr_wr_addr] = trans.upper_data;
          $display("[SB] Init SRAM B addr %0h data %0h", 
                   trans.curr_wr_addr, trans.upper_data);
        end
      end

      else if (!trans.rdn_wr) begin
        int expected_lower = mem_a[trans.curr_rd_addr];
        int expected_upper = mem_b[trans.curr_rd_addr];
        
        // Check SRAM A read
        if (trans.lower_data !== expected_lower) begin
          $error("[SB] SRAM A READ MISMATCH: Addr=%0h DUT=%0h Expected=%0h", 
                 trans.curr_rd_addr, trans.lower_data, expected_lower);
          $finish;
        end else begin
          $display("[SB] SRAM A read CORRECT: Addr=%0h Data=%0h", 
                   trans.curr_rd_addr, trans.lower_data);
        end
        
        // Check SRAM B read
        if (trans.upper_data !== expected_upper) begin
          $error("[SB] SRAM B READ MISMATCH: Addr=%0h DUT=%0h Expected=%0h", 
                 trans.curr_rd_addr, trans.upper_data, expected_upper);
          $finish;
        end else begin
          $display("[SB] SRAM B read CORRECT: Addr=%0h Data=%0h", 
                   trans.curr_rd_addr, trans.upper_data);
        end

        // Store operands for calculation checking
        if (!second_read) begin
          golden_lower_data = trans.lower_data;
          second_read = 1;
          $display("[SB] Stored first operand A=%0h", golden_lower_data);
        end else begin
          golden_upper_data = trans.upper_data;
          second_read = 0;
          $display("[SB] Got operands A=%0h B=%0h", golden_lower_data, golden_upper_data);
        end
      end

      // SRAM Write with calculation checking
      else if (trans.rdn_wr) begin
        int expected = golden_lower_data + golden_upper_data;
        int dut_val = trans.lower_data;
        
        if (dut_val !== expected) begin
          $error("[SB] CALCULATION MISMATCH: Addr=%0h DUT=%0h Expected=%0h (A=%0h + B=%0h)", 
                 trans.curr_wr_addr, dut_val, expected, golden_lower_data, golden_upper_data);
          $finish;
        end else begin
          $display("[SB] Calculation CORRECT: %0h + %0h = %0h @ addr %0h", 
                   golden_lower_data, golden_upper_data, dut_val, trans.curr_wr_addr);
        end
        
        mem_a[trans.curr_wr_addr] = dut_val;
        $display("[SB] Updated golden SRAM A[%0h] = %0h", trans.curr_wr_addr, dut_val);
      end
    end
  endtask

endclass : calc_sb