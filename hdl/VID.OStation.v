`timescale 1ns / 1ps

/*Project Oberon, Revised Edition 2013

Book copyright (C)2013 Niklaus Wirth and Juerg Gutknecht;
software copyright (C)2013 Niklaus Wirth (NW), Juerg Gutknecht (JG), Paul
Reed (PR/PDR).

Permission to use, copy, modify, and/or distribute this software and its
accompanying documentation (the "Software") for any purpose with or
without fee is hereby granted, provided that the above copyright notice
and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHORS DISCLAIM ALL WARRANTIES
WITH REGARD TO THE SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY, FITNESS AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
AUTHORS BE LIABLE FOR ANY CLAIM, SPECIAL, DIRECT, INDIRECT, OR
CONSEQUENTIAL DAMAGES OR ANY DAMAGES OR LIABILITY WHATSOEVER, WHETHER IN
AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE DEALINGS IN OR USE OR PERFORMANCE OF THE SOFTWARE.*/

// 1024x768 display controller NW/PR 24.1.2014
// OberonStation (externally-clocked) ver PR 7.8.15/03.10.15
// Modified for SDRAM - Nicolae Dumitrache 2016

module VID
#(
    parameter data_delay = 0
)
(
    input clk, pclk, inv, ce,
    input [31:0] viddata,
    output reg req = 1'b1,  // SRAM read request
    output hsync, vsync,  // to display
    output de,
    output [5:0] RGB
);

initial req = 1'b1;

localparam Org = 18'b1101_1111_1111_0000_00;  // DFF00: adr of vcnt=1023
reg [10:0] hcnt;
reg [9:0] vcnt;
reg [4:0] hword;  // from hcnt, but latched in the clk domain
reg [31:0] vidbuf, pixbuf;
reg hblank;
wire hend, vend, vblank, xfer, vid;

assign de = !(hblank|vblank);

assign hend = (hcnt == 1343), vend = (vcnt == 801);
assign vblank = (vcnt[8] & vcnt[9]);  // (vcnt >= 768)
assign hsync = ~((hcnt >= 1080+6) & (hcnt < 1184+6));  // -ve polarity
assign vsync = (vcnt >= 771) & (vcnt < 776);  // +ve polarity
assign xfer = (hcnt[4:0] == data_delay);  // data delay > hcnt cycle + req cycle
assign vid = (pixbuf[0] ^ inv) & ~hblank & ~vblank;
assign RGB = {6{vid}};
//wire vidadr = Org + {3'b0, ~vcnt, hword};

always @(posedge pclk) if(ce) begin  // pixel clock domain
  hcnt <= hend ? 0 : hcnt+1;
  vcnt <= hend ? (vend ? 0 : (vcnt+1)) : vcnt;
  hblank <= xfer ? hcnt[10] : hblank;  // hcnt >= 1024
  pixbuf <= xfer ? vidbuf : {1'b0, pixbuf[31:1]};
end

always @(posedge clk) if(ce) begin  // CPU (SRAM) clock domain
  hword <= hcnt[9:5];
  req <= ~vblank & ~hcnt[10] & (hcnt[5] ^ hword[0]);  // i.e. adr changed
  vidbuf <= req ? viddata : vidbuf;
end

endmodule
