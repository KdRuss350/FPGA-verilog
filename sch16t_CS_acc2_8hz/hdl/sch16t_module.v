`timescale 1ns / 1ps

module sch16t_module #(

    parameter DATA_WIDTH     = 32         // 数据位宽
)
(
    input                       i_clk           ,
    input                       i_rst           ,
    
    /* user */
    input                       loop_en         ,   //轮询读取传感器值 使能
    output   [DATA_WIDTH-1: 0]  sens_data       ,   //传感器值  有效值（低16_bit） 传感器顺序参考sch16t_loopRead
    output                      sens_valid      ,   //传感器值  有效信号，这个是给上层的信号吗？
	output						w_loop_read		,

    /* drive */
    output                      o_reset_n       ,   //EXTRESET
    output      [1:0]           o_TA            ,
    output         	            spi_cs_n		,
	output			            spi_sck			,
	input			            spi_miso		,
    output      [15:0]          o_state         ,
	output			            spi_mosi			
);

// wire                        w_reset_n          ;
wire                        w_init_finish      ; //初始化完成信号，控制后面所有逻辑
wire                        w_loop_read        ; 
wire  [DATA_WIDTH-1: 0]     w_cmd              ;
wire                        w_cmd_valid        ;
wire                        w_ready            ;
wire  [DATA_WIDTH-1: 0]     w_data             ;
wire                        w_data_valid       ;

wire  [DATA_WIDTH-1: 0]     w_init_cmd              ;
wire                        w_init_cmd_valid        ;
wire                        w_init_ready            ;
wire  [DATA_WIDTH-1: 0]     w_init_data             ;
wire                        w_init_data_valid       ;

wire  [DATA_WIDTH-1: 0]     w_loopread_cmd              ;
wire                        w_loopread_cmd_valid        ;
wire                        w_loopread_ready            ;
wire  [DATA_WIDTH-1: 0]     w_loopread_data             ;
wire                        w_loopread_data_valid       ;

/*两个阶段吧，一个是初始化，另一个是循环读*/
assign  w_loop_read             = w_init_finish ? loop_en               : 0                     ; //初始化完成之后，等待mems传感器信号，开始循环读取数据；否则不开启循环读取
assign  w_cmd                   = w_init_finish ? w_loopread_cmd        : w_init_cmd            ; //初始化完成之后，写循环读取的指令；如果没完成初始化，写初始化的指令
assign  w_cmd_valid             = w_init_finish ? w_loopread_cmd_valid  : w_init_cmd_valid      ;

/*以初始化完成为分界线*/
assign  w_init_ready            = w_init_finish ? 0                     : w_ready               ;
assign  w_init_data             = w_init_finish ? 0                     : w_data                ;
assign  w_init_data_valid       = w_init_finish ? 0                     : w_data_valid          ;

assign  w_loopread_ready        = w_init_finish ? w_ready               : 0                     ;
assign  w_loopread_data         = w_init_finish ? w_data                : 0                     ;
assign  w_loopread_data_valid   = w_init_finish ? w_data_valid          : 0                     ;

sch16t_init #(
    .DATA_WIDTH() // 数据位宽
) u0_sch16t_init(
    .i_clk(i_clk),
    .i_rst(i_rst),
    .o_reset_n(o_reset_n), 

    .o_cmd(w_init_cmd),//指令得输出，输出到spi驱动那里,初始化完成后就一直输出0了
    .o_valid(w_init_cmd_valid),
    .i_ready(w_init_ready),

    .i_data(w_init_data),
    .i_valid(w_init_data_valid),
	.o_state(o_state),
    .o_init_finish(w_init_finish)
);


//这个模块，输出数据和输出指令放在一起；发送指令给驱动模块，再从驱动模块接收数据进行解码
sch16t_loopRead  #(
    .DATA_WIDTH() // 数据位宽
)  u0_sch16t_loopRead(

    .i_clk(i_clk),
    .i_rst(i_rst),

    .loop_read_en(w_loop_read),

    .o_cmd(w_loopread_cmd),
    .o_cmd_valid(w_loopread_cmd_valid),
    .i_ready(w_loopread_ready),
    .i_data(w_loopread_data),
    .i_data_valid(w_loopread_data_valid),

    .o_sens_data(sens_data),
    .o_sens_valid(sens_valid)
);

sch16t_rw  #(
    .DATA_WIDTH() // 数据位宽
)  u0_sch16t_rw(
    .i_clk(i_clk),
    .i_rst(i_rst),

    .i_cmd(w_cmd), //写入的指令
    .i_cmd_valid(w_cmd_valid),

    .o_ready(w_ready),
    .o_data(w_data),
    .o_data_valid(w_data_valid),

	.spi_cs_n(spi_cs_n)		    ,
	.spi_sck (spi_sck )			,
	.spi_miso(spi_miso)			,
	.spi_mosi (spi_mosi)			
);

assign  o_TA = 2'b00;

endmodule
