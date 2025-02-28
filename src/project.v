`default_nettype none
module tt_um_example (
	ui_in,
	uo_out,
	uio_in,
	uio_out,
	uio_oe,
	ena,
	clk,
	rst_n
);
	input wire [7:0] ui_in;
	output wire [7:0] uo_out;
	input wire [7:0] uio_in;
	output wire [7:0] uio_out;
	output wire [7:0] uio_oe;
	input wire ena;
	input wire clk;
	input wire rst_n;
	assign uo_out[2:3] = 2'b00;
	assign uio_out = 0;
	assign uio_oe = 0;
	wire _unused = &{ena};
	wire [3:0] packet;
	SPI_EEPROM eeprom_ctrl(
		.clk(clk),
		.rst(rst_n),
		.IN_addr(0),
		.IN_read(ui_in[1]),
		.IN_cancel(0),
		.OUT_data(packet[1]),
		.OUT_dataValid(packet[0]),
		.OUT_dataByte(packet[2]),
		.OUT_dataWord(packet[3]),
		.OUT_cs(uo_out[0]),
		.OUT_mosi(uo_out[1]),
		.IN_miso(ui_in[0])
	);
	reg [31:0] cnt;
	reg [31:0] sr_r;
	wire [31:0] sr_c = {sr_r[30:0], packet[1]};
	always @(posedge clk)
		if (packet[0]) begin
			sr_r <= sr_c;
			if (packet[3])
				cnt <= cnt + packet[3];
		end
	assign uo_out[4+:4] = cnt[uio_in[7-:3] * 4+:4];
endmodule
module SPI_EEPROM (
	clk,
	rst,
	IN_addr,
	IN_read,
	IN_cancel,
	OUT_data,
	OUT_dataValid,
	OUT_dataByte,
	OUT_dataWord,
	OUT_sclk,
	OUT_cs,
	OUT_mosi,
	IN_miso
);
	input wire clk;
	input wire rst;
	input wire [23:0] IN_addr;
	input wire IN_read;
	input wire IN_cancel;
	output reg OUT_data;
	output reg OUT_dataValid;
	output reg OUT_dataByte;
	output reg OUT_dataWord;
	output wire OUT_sclk;
	output wire OUT_cs;
	output wire OUT_mosi;
	input wire IN_miso;
	reg [2:0] state_r;
	reg [2:0] state_c;
	always @(posedge clk or negedge rst)
		if (!rst)
			state_r <= 3'd0;
		else
			state_r <= state_c;
	reg [4:0] bitcount_r;
	reg [4:0] bitcount_c;
	always @(posedge clk) bitcount_r <= bitcount_c;
	wire [4:0] bitcount_r_inc;
	assign bitcount_r_inc = bitcount_r + 1'b1;
	reg mosi_c;
	always @(*) begin
		mosi_c = 0;
		case (state_r)
			default: begin
				state_c = 3'd0;
				bitcount_c = 0;
				if (IN_read)
					state_c = 3'd1;
			end
			3'd1: begin
				state_c = 3'd1;
				bitcount_c = bitcount_r_inc;
				mosi_c = (bitcount_r == 6) || (bitcount_r == 7);
				if (bitcount_r[2:0] == 7) begin
					state_c = 3'd2;
					bitcount_c = 0;
				end
			end
			3'd2: begin
				state_c = 3'd2;
				bitcount_c = bitcount_r_inc;
				mosi_c = IN_addr[23 - bitcount_r];
				if (bitcount_r == 23) begin
					state_c = 3'd3;
					bitcount_c = 0;
				end
			end
			3'd3: begin
				state_c = 3'd4;
				bitcount_c = 0;
			end
			3'd4: begin
				state_c = 3'd4;
				bitcount_c = bitcount_r_inc;
				if (IN_cancel)
					state_c = 3'd0;
			end
		endcase
	end
	reg mosi_r;
	always @(posedge clk) mosi_r <= mosi_c;
	reg mosi_ne_c;
	always @(negedge clk) mosi_ne_c <= mosi_r;
	assign OUT_mosi = mosi_ne_c;
	wire cs_set_c = (state_r == 3'd0) && IN_read;
	wire cs_unset_c = IN_cancel;
	reg cs_reg;
	always @(posedge clk)
		if (cs_set_c)
			cs_reg <= 1;
		else if (cs_unset_c)
			cs_reg <= 0;
	reg cs_oreg;
	always @(posedge clk) cs_oreg <= ~cs_reg;
	assign OUT_cs = cs_oreg;
	assign OUT_sclk = clk;
	always @(posedge clk) begin
		OUT_data <= IN_miso;
		OUT_dataValid <= state_r == 3'd4;
		OUT_dataWord <= bitcount_r == 31;
		OUT_dataByte <= bitcount_r[2:0] == 7;
	end
endmodule
