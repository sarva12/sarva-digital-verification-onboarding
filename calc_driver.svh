class calc_driver #(int DataSize, int AddrSize);

  mailbox #(calc_seq_item #(DataSize, AddrSize)) drv_box;
  virtual interface calc_if #(.DataSize(DataSize), .AddrSize(AddrSize)) calcVif;

  function new(virtual interface calc_if #(DataSize, AddrSize) calcVif,
               mailbox #(calc_seq_item #(DataSize, AddrSize)) drv_box);
    this.calcVif = calcVif;
    this.drv_box = drv_box;
  endfunction

  // reset
  task reset_task();
    $display("[DRV] Applying reset...");
    calcVif.cb.reset <= 1;
    repeat (2) @(calcVif.cb);
    calcVif.cb.reset <= 0;
    @(calcVif.cb);
    $display("[DRV] Reset deasserted, DUT should be in IDLE");
  endtask

  // SRAM initialization
  virtual task initialize_sram(input [AddrSize-1:0] addr, input [DataSize-1:0] data,input logic block_sel);
    $display("[DRV] Initializing SRAM %0s at address %0h with data %0h", (block_sel ? "B" : "A"), addr, data);
    calcVif.cb.initialize         <= 1;
    calcVif.cb.initialize_addr    <= addr;
    calcVif.cb.initialize_data    <= data;
    calcVif.cb.initialize_loc_sel <= block_sel;

    @(calcVif.cb); 
    calcVif.cb.initialize <= 0; 
  endtask : initialize_sram

  // start calc
  virtual task start_calc(input logic [AddrSize-1:0] read_start_addr,
                          input logic [AddrSize-1:0] read_end_addr,
                          input logic [AddrSize-1:0] write_start_addr,
                          input logic [AddrSize-1:0] write_end_addr,
                          input bit direct = 1);

    int delay;
    $display("[DRV] starting calculation with R: [%0d:%0d], W: [%0d:%0d]",read_start_addr, read_end_addr, write_start_addr, write_end_addr);
    // drive inputs
    calcVif.cb.read_start_addr  <= read_start_addr;
    calcVif.cb.read_end_addr    <= read_end_addr;
    calcVif.cb.write_start_addr <= write_start_addr;
    calcVif.cb.write_end_addr   <= write_end_addr;

    reset_task();


    repeat (10) @(calcVif.cb);

    if (!direct) begin
      delay = $urandom_range(0, 5);
      repeat (delay) @(calcVif.cb);
    end
  endtask : start_calc

  //driver loop
  virtual task drive();
    calc_seq_item #(DataSize, AddrSize) trans;
    while (drv_box.try_get(trans)) begin
      start_calc(trans.read_start_addr,
                 trans.read_end_addr,
                 trans.write_start_addr,
                 trans.write_end_addr,
                 0);
    end
  endtask : drive

endclass : calc_driver
