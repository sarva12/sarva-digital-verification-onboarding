class calc_seq_item #(parameter int DataSize = calculator_pkg::DATA_W, parameter int AddrSize = calculator_pkg::ADDR_W);

  rand logic rdn_wr;
  rand logic [AddrSize-1:0] read_start_addr;
  rand logic [AddrSize-1:0] read_end_addr;
  rand logic [AddrSize-1:0] write_start_addr;
  rand logic [AddrSize-1:0] write_end_addr;
  rand logic [DataSize-1:0] lower_data;
  rand logic [DataSize-1:0] upper_data;
  rand logic [AddrSize-1:0] curr_rd_addr;
  rand logic [AddrSize-1:0] curr_wr_addr;
  rand logic loc_sel;
  rand logic initialize;


  constraint read_end_gt_start {
    read_end_addr > read_start_addr;
  }


  constraint write_end_gt_start {
    write_end_addr >= write_start_addr;
  }

  constraint address_ranges_valid {
    read_start_addr  inside {[0 : (2**AddrSize)-1]};
    read_end_addr    inside {[0 : (2**AddrSize)-1]};
    write_start_addr inside {[0 : (2**AddrSize)-1]};
    write_end_addr   inside {[0 : (2**AddrSize)-1]};
    curr_rd_addr     inside {[0 : (2**AddrSize)-1]};
    curr_wr_addr     inside {[0 : (2**AddrSize)-1]};
    
    (read_end_addr - read_start_addr + 1) == 2 * (write_end_addr - write_start_addr + 1);
    
    write_start_addr >= read_end_addr + 1;
  }

  constraint init_control {
    initialize dist { 0 := 90, 1 := 10 };
  }

  function new();
  endfunction

  function void display();
    $display($stime,
      " Rdn_Wr: %b | Read: [%0d:%0d] | Write: [%0d:%0d] | Data: 0x%0x | Curr R: %0d | Curr W: %0d | loc_sel: %b | init: %b",
      rdn_wr, read_start_addr, read_end_addr, write_start_addr, write_end_addr,
      {upper_data, lower_data}, curr_rd_addr, curr_wr_addr, loc_sel, initialize
    );
  endfunction

endclass : calc_seq_item