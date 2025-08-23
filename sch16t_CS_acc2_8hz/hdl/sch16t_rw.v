`timescale 1ns / 1ps

module sch16t_rw #(
    parameter DATA_WIDTH     = 32         // 数据位宽
)(
    input                       i_clk,
    input                       i_rst,

    input  [DATA_WIDTH-1: 0]    i_cmd,
    input                       i_cmd_valid,
    output                      o_ready,
    output  [DATA_WIDTH-1: 0]   o_data,//deadbeef作为输出数据了，持续了一个时钟
    output                      o_data_valid,

	output         	            spi_cs_n		,
	output			            spi_sck			,
	output			            spi_mosi		,
	input			            spi_miso			
);

reg                         ro_ready;//帧传输完成
reg                         r_data_valid_d1;//帧传输完成
reg     [DATA_WIDTH-1: 0]   ri_cmd;//下一个指令进来
reg                         ri_cmd_valid;
reg     [DATA_WIDTH-1: 0]   r_send;
reg                         r_send_valid;
reg                         flag_isSend;        //是否已发送一次cmd，高电平表示处在发送状态

reg     [DATA_WIDTH-1: 0]   ro_data;
reg                         ro_data_valid;
wire    [DATA_WIDTH-1: 0]   w_data;
wire                        w_data_valid;
wire                        w_active;
reg                         flag_isRecv;        //是否已收到一次data,高电平表明处在接收状态



assign  o_data = ro_data;
assign  o_data_valid = ro_data_valid;
assign  o_ready = ro_ready;
assign  w_active = i_cmd_valid && o_ready;

///输入部分
always @(posedge i_clk, posedge i_rst)///写一个word，ri_cmd_valid就变为1
    if(i_rst)   begin
        ri_cmd <= 0;
        ri_cmd_valid <= 0;
    end else    begin
        ri_cmd <= i_cmd;//错开一个时钟
        ri_cmd_valid <= i_cmd_valid;
    end

///输出部分
always @(posedge i_clk, posedge i_rst)
    if(i_rst)   begin
        r_data_valid_d1 <= 0;
    end else    begin
        r_data_valid_d1 <= o_data_valid;//已经输出数据了
    end

always @(posedge i_clk, posedge i_rst)
    if(i_rst)   begin
        ro_ready <= 1;
    end else if(w_active)   begin
        ro_ready <= 0;
    end else if(~o_data_valid && r_data_valid_d1)   begin    //falling
        ro_ready <= 1;
    end else    begin
        ro_ready <= ro_ready;
    end

/* send cmd */ 
always @(posedge i_clk, posedge i_rst)
    if(i_rst)   begin
        flag_isSend <= 0;
    end else if(flag_isSend && r_send_valid)   begin
        flag_isSend <= 0;
    end else if(r_send_valid)   begin  //开启一个word的传输，flag_isSend置1
        flag_isSend <= 1;
    end else    begin
        flag_isSend <= flag_isSend;
    end

always @(posedge i_clk, posedge i_rst)
    if(i_rst)   begin
        r_send <= 'd0;
        r_send_valid <= 0;
    end else if(flag_isSend && ~w_data_valid)   //发完一个指令，之后读deadbeef
    begin
        r_send <= 32'hDEADBEEF;
        r_send_valid <= 1;//证明指令已经发送出去了，这里面两个r_send_valid频率还不一样，前快(1clk)后慢
    end else if(ri_cmd_valid && ~i_cmd_valid)   begin
        r_send <= ri_cmd;
        r_send_valid <= 1;
    end else    begin
        r_send <= r_send;
        r_send_valid <= 0;
    end

/* recv data */
always @(posedge i_clk, posedge i_rst)
    if(i_rst)   begin
        flag_isRecv <= 0;
    end else if(ro_data_valid)   begin //有有意义的数据读出来了
        flag_isRecv <= 0;
    end else if(~w_data_valid)   begin //ro_data_valid=1和w_data_valid=0时进入接收数据状态
        flag_isRecv <= 1;
    end else    begin
        flag_isRecv <= flag_isRecv;
    end


always @(posedge i_clk, posedge i_rst)
    if(i_rst)   begin
        ro_data <= 'd0;
        ro_data_valid <= 0;
    end else if(flag_isRecv && ~w_data_valid)   begin
        ro_data <= w_data;
        ro_data_valid <= ~w_data_valid;
    end else    begin
        ro_data <= 'd0;
        ro_data_valid <= 0;
    end

spi_master #(
    .CLK_FREQ  (40_000_000), // 系统时钟频率，单位为 Hz
    .SCK_FREQ  (10_000_000), // SPI 时钟频率，单位为 Hz
    .CPOL      (0), // 时钟极性（0 或 1）
    .CPHA      (0), // 时钟相位（0 或 1）
    .DATA_WIDTH(32), // 数据位宽
    .NUM_WORDS (4), // 传输数据的个数
    .T_CS_SETUP(40), // CS 设置时间（ns）
    .T_CS_HOLD (40), // CS 保持时间（ns）
    .T_SETUP   (10)  // 数据设置时间（ns）
)u0_spi_master(
	.sys_rst_n(~i_rst)		, 
	.sys_clk(i_clk)			,
	.spi_cs_n(spi_cs_n)		,
	.spi_sck(spi_sck)	    ,
	.spi_mosi(spi_mosi)	    ,
	.spi_miso(spi_miso)	    ,

	.lb_data_out(w_data)	,   //read data,读出来的数据
	.lb_rd_n(w_data_valid)	,   //valid，一个32bit的word传输完成，默认是0，如果传输完成就变成1

	.lb_data_in(r_send)		,   //write data，写进去的数据
	.lb_wr_n(~r_send_valid) ,	//valid，开启写过程

    .spi_debug()      // 调试信号
);

// always @(posedge i_clk, posedge i_rst)
//     if(i_rst)   begin
//     end else if()   begin
//     end else if()   begin
//     end else    begin
//     end


endmodule
