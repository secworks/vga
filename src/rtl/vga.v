//======================================================================
//
// vga.v
// -----
// A very simple BGA interface.
//
//
// Author: Joachim Strombergson
// Copyright (c) 2014, Secworks Sweden AB
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or
// without modification, are permitted provided that the following
// conditions are met:
//
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in
//    the documentation and/or other materials provided with the
//    distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
// FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
// COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
// ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//======================================================================

module vga(
           input wire          clk,
           input wire          reset_n,

           input wire          button0,
           input wire          button1,

           output wire [3 : 0] red,
           output wire [3 : 0] green,
           output wire [3 : 0] blue,

           output wire         test_clk,
           output wire         vsync,
           output wire         hsync
          );


  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  parameter RED_DEFAULT      = 4'hf;
  parameter GREEN_DEFAULT    = 4'hf;
  parameter BLUE_DEFAULT     = 4'hf;

  parameter START_OF_LINE    = 11'h000;
  parameter END_OF_LINE      = 11'h63e;
  parameter END_OF_PIXELS    = 11'h57e;

  parameter END_OF_SCREEN    = 11'h20c;
  parameter START_OF_DISPLAY = 11'h021;
  parameter END_OF_DISPLAY   = 11'h200;

  parameter UPDATE_DELAY_MAX = 32'h002c4b40;


  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------
  reg          vsync_reg;
  reg          vsync_new;
  reg          vsync_we;

  reg          hsync_reg;
  reg          hsync_new;
  reg          hsync_we;

  reg [3 : 0]  red_reg;
  reg [3 : 0]  red_new;
  reg          red_we;

  reg [3 : 0]  green_reg;
  reg [3 : 0]  green_new;
  reg          green_we;

  reg [3 : 0]  blue_reg;
  reg [3 : 0]  blue_new;
  reg          blue_we;

  reg          button0_reg;
  reg          button1_reg;

  reg [31 : 0] delay_ctr_reg;
  reg [31 : 0] delay_ctr_new;
  reg          delay_ctr_we;

  reg [10 : 0] row_cycle_ctr_reg;
  reg [10 : 0] row_cycle_ctr_new;
  reg          row_cycle_ctr_rst;
  reg          row_cycle_ctr_inc;
  reg          row_cycle_ctr_we;

  reg [10 : 0] line_ctr_reg;
  reg [10 : 0] line_ctr_new;
  reg          line_ctr_rst;
  reg          line_ctr_inc;
  reg          line_ctr_we;

  reg          test_clk_reg;


  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  reg new_line;


  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign red   = red_reg;
  assign green = green_reg;
  assign blue  = blue_reg;
  assign hsync = hsync_reg;
  assign vsync = vsync_reg;

  assign test_clk = test_clk_reg;


  //----------------------------------------------------------------
  // reg_update
  // Update functionality for all registers in the core.
  // All registers are positive edge triggered with
  // asynchronous active low reset.
  //----------------------------------------------------------------
  always @ (posedge clk or negedge reset_n)
    begin
      if (!reset_n)
        begin
          red_reg             <= RED_DEFAULT;
          green_reg           <= GREEN_DEFAULT;
          blue_reg            <= BLUE_DEFAULT;
          vsync_reg           <= 0;
          hsync_reg           <= 0;
          button0_reg         <= 0;
          button1_reg         <= 0;
          debug_delay_ctr_reg <= 32'h00000000;
          row_cycle_ctr_reg   <= 11'h000;
          line_ctr_reg        <= 11'h000;
          test_clk_reg        <= 0;
        end
      else
        begin
          button0_reg  <= button0;
          button1_reg  <= button1;
          test_clk_reg <= ~test_clk_reg;

          if (delay_ctr_we)
            begin
              delay_ctr_reg <= delay_ctr_new;
            end

          if (row_cycle_ctr_we)
            begin
              row_cycle_ctr_reg <= row_cycle_ctr_new;
            end

          if (line_ctr_we)
            begin
              line_ctr_reg <= line_ctr_new;
            end

          if (hsync_we)
            begin
              hsync_reg <= hsync_new;
            end

          if (vsync_we)
            begin
              vsync_reg <= vsync_new;
            end

          if (green_we)
            begin
              green_reg <= green_new;
            end

          if (blue_we)
            begin
              blue_reg <= blue_new;
            end

          if (red_we)
            begin
              red_reg <= red_new;
            end
        end
    end // reg_update


  //----------------------------------------------------------------
  // delay_ctr
  //----------------------------------------------------------------
  always @*
    begin : delay_ctr
      if (button1_reg)
        begin
          delay_ctr_we  = 1;
          delay_ctr_new = delay_ctr_reg + 32'h00000001;

          if (delay_ctr_reg == UPDATE_DELAY_MAX)
            begin
              delay_ctr_new = 32'h00000000;
            end
        end
    end

  //----------------------------------------------------------------
  // row_cycle_ctr
  //----------------------------------------------------------------
  always @*
    begin : row_cycle_ctr
      row_cycle_ctr_new = 11'h000;
      row_cycle_ctr_we  = 0;

      if (row_cycle_ctr_rst)
        begin
          row_cycle_ctr_new = 11'h000;
          row_cycle_ctr_we  = 1;
        end

      if (row_cycle_ctr_inc)
        begin
          row_cycle_ctr_new = row_cycle_ctr_reg + 11'h001;
          row_cycle_ctr_we  = 1;
        end
    end // row_cycle_ctr


  //----------------------------------------------------------------
  // line_ctr
  //----------------------------------------------------------------
  always @*
    begin : line_ctr
      line_ctr_new = 11'h000;
      line_ctr_we  = 0;

      if (line_ctr_rst)
        begin
          line_ctr_new = 11'h000;
          line_ctr_we  = 1;
        end

      if (line_ctr_inc)
        begin
          line_ctr_new = line_ctr_reg + 11'h001;
          line_ctr_we  = 1;
        end
    end // line_ctr


  //----------------------------------------------------------------
  // hsync_logic
  //----------------------------------------------------------------
  always @*
    begin : hsync_logic
      hsync_new         = 0;
      hsync_we          = 0;
      row_cycle_ctr_rst = 0;
      row_cycle_ctr_inc = 0;
      new_line          = 0;

      if (row_cycle_ctr_reg == END_OF_LINE)
        begin
          row_cycle_ctr_rst = 1;
          new_line          = 1;
        end
      else
        begin
          row_cycle_ctr_inc = 1;
        end

      if (row_cycle_ctr_reg == START_OF_LINE)
        begin
          hsync_new = 1;
          hsync_we  = 1;
        end

      if (row_cycle_ctr_reg == END_OF_PIXELS)
        begin
          hsync_new = 0;
          hsync_we  = 1;
        end
    end // hsync_logic


  //----------------------------------------------------------------
  // vsync_logic
  //----------------------------------------------------------------
  always @*
    begin : vsync_logic
      vsync_new    = 0;
      vsync_we     = 0;
      line_ctr_rst = 0;
      line_ctr_inc = 0;

      if (new_line)
        begin
          if (line_ctr_reg == END_OF_SCREEN)
            begin
              line_ctr_rst = 1;
            end
          else
            begin
              line_ctr_inc = 1;
            end
        end

      if (line_ctr_reg == START_OF_DISPLAY)
        begin
          vsync_new = 1;
          vsync_we  = 1;
        end

      if (line_ctr_reg == END_OF_DISPLAY)
        begin
          vsync_new = 0;
          vsync_we  = 1;
        end
    end // vsync_logic


  //----------------------------------------------------------------
  // rgb_update
  //----------------------------------------------------------------
  always @*1p
    begin : rgb_update
      red_new   = 4'h0;
      red_we    = 0;
      green_new = 4'h0;
      green_we  = 0;
      blue_new  = 4'h0;
      blue_we   = 0;

      if (button1_reg && (debug_delay_ctr_reg == 32'h00000000))
        begin
          red_new   = red_reg + 4'h1;
          red_we    = 1;
          green_new = green_reg + 4'h3;
          green_we  = 1;
          blue_new  = blue_reg + 4'h5;
          blue_we   = 1;
        end

      if (button0_reg)
        begin
          red_new   = red_reg + 4'h1;
          red_we    = 1;
          green_new = green_reg + 4'h3;
          green_we  = 1;
          blue_new  = blue_reg + 4'h5;
          blue_we   = 1;
        end
    end // rgb_update
endmodule // vga

//======================================================================
// EOF vga.v
//======================================================================
