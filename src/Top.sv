/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_mathis_demo (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // All output pins must be assigned. If not used, assign to 0.
  assign uo_out[2+:2] = 2'b0;
  assign uio_out = 0;
  assign uio_oe  = 0;

  // List all unused inputs to prevent warnings
  wire _unused = &{ena};

typedef struct packed
{
    logic word;
    logic b;
    logic data;
    logic valid;
} EEPROM_Packet;

EEPROM_Packet packet;
SPI_EEPROM eeprom_ctrl
(
    .clk(clk),
    .rst(rst_n),
    .IN_addr(0),
    .IN_read(ui_in[1]),
    .IN_cancel(0),

    .OUT_data(packet.data),
    .OUT_dataValid(packet.valid),
    .OUT_dataByte(packet.b),
    .OUT_dataWord(packet.word),

    .OUT_sclk(),
    .OUT_cs(uo_out[0]),
    .OUT_mosi(uo_out[1]),
    .IN_miso(ui_in[0])
);

logic[31:0] cnt;
logic[31:0] sr_r;
wire[31:0] sr_c = {sr_r[30:0], packet.data};
always_ff@(posedge clk) begin
    if (packet.valid) begin
        sr_r <= sr_c;
        if (packet.word) begin
            cnt <= cnt + sr_c;
        end
    end
end

assign uo_out[4+:4] = cnt[uio_in[7-:3]*4+:4];

endmodule
