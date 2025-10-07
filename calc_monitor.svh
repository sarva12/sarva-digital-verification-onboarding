class calc_monitor #(int DataSize, int AddrSize);

  virtual interface calc_if #(.DataSize(DataSize), .AddrSize(AddrSize)) calcVif;
  mailbox #(calc_seq_item #(DataSize, AddrSize)) mon_box;

  function new(virtual interface calc_if #(DataSize, AddrSize) calcVif);
    this.calcVif = calcVif;
    this.mon_box = new();
  endfunction

  task main();
    forever begin
      @(calcVif.cb);

      if (calcVif.cb.rd_en && calcVif.cb.wr_en) begin
        $error($stime, " Mon: Error rd_en and wr_en both asserted at the same time");
      end

      if (calcVif.cb.wr_en || calcVif.cb.rd_en) begin
        calc_seq_item #(DataSize, AddrSize) trans = new();
        trans.rdn_wr          = calcVif.cb.wr_en; // 1=write, 0=read
        trans.curr_rd_addr    = calcVif.cb.curr_rd_addr;
        trans.curr_wr_addr    = calcVif.cb.curr_wr_addr;
        trans.loc_sel         = calcVif.cb.loc_sel;

        trans.read_start_addr = calcVif.read_start_addr;
        trans.read_end_addr   = calcVif.read_end_addr;
        trans.write_start_addr= calcVif.write_start_addr;
        trans.write_end_addr  = calcVif.write_end_addr;

        if (trans.rdn_wr) begin
          trans.lower_data = calcVif.cb.wr_data[DataSize-1:0];
          trans.upper_data = calcVif.cb.wr_data[2*DataSize-1:DataSize];
          $display($stime, " Mon: Write addr 0x%0x: Lower=0x%0x Upper=0x%0x",
                   trans.curr_wr_addr, trans.lower_data, trans.upper_data);
          mon_box.put(trans);
        end
        else begin
          @(calcVif.cb);
          trans.lower_data = calcVif.cb.rd_data[DataSize-1:0];
          trans.upper_data = calcVif.cb.rd_data[2*DataSize-1:DataSize];
          $display($stime, " Mon: Read addr 0x%0x: Lower=0x%0x Upper=0x%0x",
                   trans.curr_rd_addr, trans.lower_data, trans.upper_data);
          mon_box.put(trans);
        end
      end

      if (calcVif.initialize) begin
        calc_seq_item #(DataSize, AddrSize) trans = new();
        trans.rdn_wr       = 1'b1; // init is write
        trans.initialize   = 1'b1;
        trans.loc_sel      = calcVif.initialize_loc_sel;
        trans.curr_wr_addr = calcVif.initialize_addr;
        if (!calcVif.initialize_loc_sel)
          trans.lower_data = calcVif.initialize_data;
        else
          trans.upper_data = calcVif.initialize_data;
        $display($stime, " Mon: Init SRAM %s Addr=0x%0x Data=0x%0x",
                 (calcVif.initialize_loc_sel ? "B" : "A"),
                 trans.curr_wr_addr, calcVif.initialize_data);
        mon_box.put(trans);
      end
    end
  endtask

endclass : calc_monitor
