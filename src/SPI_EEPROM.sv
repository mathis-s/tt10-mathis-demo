
module SPI_EEPROM
(
    input wire clk,
    input wire rst,

    input wire[23:0] IN_addr,
    input wire IN_read,
    input wire IN_cancel,

    output logic OUT_data,
    output logic OUT_dataValid,
    output logic OUT_dataByte,
    output logic OUT_dataWord,

    output wire OUT_sclk,
    output wire OUT_cs,
    output wire OUT_mosi,
    input wire IN_miso
);

typedef enum logic[2:0]
{
    IDLE,
    COMMAND,
    ADDR,
    WAIT,
    DATA
} State;

State state_r;
State state_c;
always@(posedge clk, negedge rst) begin
    if (!rst) state_r <= IDLE;
    else state_r <= state_c;
end

logic[4:0] bitcount_r;
logic[4:0] bitcount_c;
always@(posedge clk) begin
    bitcount_r <= bitcount_c;
end

wire[4:0] bitcount_r_inc;
assign bitcount_r_inc = bitcount_r + 1'b1;

always_comb begin
    mosi_c = 0;
    case (state_r)
        default: begin
            state_c = IDLE;
            bitcount_c = 0;

            if (IN_read) begin
                state_c = COMMAND;
            end
        end

        COMMAND: begin
            state_c = COMMAND;
            bitcount_c = bitcount_r_inc;

            mosi_c = bitcount_r == 6 || bitcount_r == 7;

            if (bitcount_r[2:0] == 7) begin
                state_c = ADDR;
                bitcount_c = 0;
            end
        end

        ADDR: begin
            state_c = ADDR;
            bitcount_c = bitcount_r_inc;

            mosi_c = IN_addr[23 - bitcount_r];

            if (bitcount_r == 23) begin
                state_c = WAIT;
                bitcount_c = 0;
            end
        end

        WAIT: begin
            state_c = DATA;
            bitcount_c = 0;
        end

        DATA: begin
            state_c = DATA;
            bitcount_c = bitcount_r_inc;
            if (IN_cancel) begin
                state_c = IDLE;
            end
        end
    endcase
end

logic mosi_c;
logic mosi_r;
always@(posedge clk)
    mosi_r <= mosi_c;

logic mosi_ne_c;
always@(negedge clk)
    mosi_ne_c <= mosi_r;
assign OUT_mosi = mosi_ne_c;

wire cs_set_c = state_r == IDLE && IN_read;
wire cs_unset_c = IN_cancel;

logic cs_reg;
always@(posedge clk)
    if (cs_set_c) cs_reg <= 1;
    else if (cs_unset_c) cs_reg <= 0;

logic cs_oreg;
always@(posedge clk)
    cs_oreg <= ~cs_reg;
assign OUT_cs = cs_oreg;

assign OUT_sclk = clk;

always_ff@(posedge clk) begin
    OUT_data <= IN_miso;
    OUT_dataValid <= state_r == DATA;
    OUT_dataWord <= bitcount_r == 31;
    OUT_dataByte <= bitcount_r[2:0] == 7;
end

endmodule
