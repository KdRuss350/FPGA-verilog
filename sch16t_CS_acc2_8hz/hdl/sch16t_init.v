`timescale 1ns / 1ps

module sch16t_init #(
    parameter DATA_WIDTH     = 32         // 数据位宽
)(
    input                       i_clk,
    input                       i_rst,
    output                      o_reset_n, 

    output  [DATA_WIDTH-1: 0]   o_cmd,
    output                      o_valid,
    input                       i_ready,

    input   [DATA_WIDTH-1: 0]   i_data,
    input                       i_valid,
	
	output  [15:0]              o_state,
    output                      o_init_finish
);

localparam      EN_SENSOR               = 32'h0D60000A,
                SET_EOI                 = 32'h0D60001C,
                SET_FILTER_RATE_XYZ     = 32'h09600006,
                SET_FILTER_ACC          = 32'h09A00000,
                READ_SUM_STATUS         = 32'h05000007;
              //0960024C
/* wire & reg */
reg                      ro_reset_n; //和最开始的1ms有关
reg  [DATA_WIDTH-1: 0]   ro_cmd;
reg                      ro_valid;//从初始化模块输出的指令是有效的
reg                      ro_init_finish;

reg                      ri_ready; //可以开始传输下一个指令了（只有第一个是看齐的，后面都作为指示，开始下一个指令的传输）
reg  [DATA_WIDTH-1: 0]   ri_data;//最后要验证的数据
reg                      ri_valid;

wire                     w_spi_active;
reg                      r_spi_active_d1;
wire                     w_spi_active_rise;
reg                      r_read_once;
// reg  [15:0]              r_state;

assign  o_reset_n   =   ro_reset_n;
assign  o_cmd   =   ro_cmd;
assign  o_valid =   ro_valid;
assign  o_init_finish = ro_init_finish;
assign  w_spi_active = ri_ready && ro_valid;//这个信号的意义？跟着指令一起激活;我向你要指令，并且你的指令也有效
assign  w_spi_active_rise = ~w_spi_active && r_spi_active_d1; //w_spi_active_rise是用来做什么的？内部控制状态机的信号
// assign  o_state = r_state;

/* state machine */
localparam      CLOCK_1MS       =   ('d40_000_000 / 1000); //40M个时钟周期对应1s，所以1ms就是40M÷1000
localparam      P_IDLE          =   1,
                P_RESET         =   2,
                P_WAIT_RESET    =   3,
                P_SET_FILTERS   =   4,
                P_SET_RATESENS  =   5,
                P_SET_ACCSENS   =   6,
                P_SET_DRY       =   7,
                P_EN_SENSOR     =   8,
                P_WAIT_SENSOR   =   9,
                P_EOI           =   10,
                P_WAIT_EOI      =   11,
                P_READ_TWICE    =   12,
                P_CHECK         =   13,
                P_OVER          =   14;

reg [7:0]    r_st_current;
reg [7:0]    r_st_next;
reg [23:0]   r_st_cnt;

always @(posedge i_clk, posedge i_rst)
    if(i_rst)
        r_st_current <= P_IDLE;
    else
        r_st_current <= r_st_next;

always @(posedge i_clk, posedge i_rst)
    if(i_rst)
        r_st_cnt <= 'd0;
    else    if(r_st_current != r_st_next)
        r_st_cnt <= 'd0;
    else
        r_st_cnt <= r_st_cnt + 1;

always @(*) begin
    case    (r_st_current)  
        P_IDLE          :   r_st_next = P_RESET;
        P_RESET         :   r_st_next = (r_st_cnt > CLOCK_1MS*1)            ?   P_WAIT_RESET :  P_RESET;
        P_WAIT_RESET    :   r_st_next = (r_st_cnt > CLOCK_1MS*32)           ?  P_SET_FILTERS :  P_WAIT_RESET;
        P_SET_FILTERS   :   r_st_next = P_SET_RATESENS; //这里没有设置滤波器        
        P_SET_RATESENS  :   r_st_next = (w_spi_active_rise)                      ?   P_SET_ACCSENS   : P_SET_RATESENS; 
        P_SET_ACCSENS   :   r_st_next = (w_spi_active_rise)                      ?   P_SET_DRY       : P_SET_ACCSENS; 
        P_SET_DRY       :   r_st_next = P_EN_SENSOR;  //这里也没有设置DRY      
        P_EN_SENSOR     :   r_st_next = (w_spi_active_rise)                      ?   P_WAIT_SENSOR   : P_EN_SENSOR; 
        P_WAIT_SENSOR   :   r_st_next = (r_st_cnt > CLOCK_1MS*215)          ?   P_EOI           : P_WAIT_SENSOR;
        P_EOI           :   r_st_next = (w_spi_active_rise)                      ?   P_WAIT_EOI      : P_EOI; 
        P_WAIT_EOI      :   r_st_next = (r_st_cnt > CLOCK_1MS*3)            ?   P_READ_TWICE    : P_WAIT_EOI;
        P_READ_TWICE    :   r_st_next = (r_read_once && w_spi_active_rise)       ?   P_CHECK         : P_READ_TWICE; //这里通过r_read_once来实现读两次寄存器
        P_CHECK         :   r_st_next = (~ri_valid)                         ?   P_CHECK     :   
                                        (ri_data[19:12] == 8'hFF)               ?   P_OVER          : P_IDLE;
        P_OVER          :   r_st_next = P_OVER;

        default     :   r_st_next = P_IDLE;
    endcase
    end

always @(posedge i_clk, posedge i_rst)
    if(i_rst)   begin
        ro_cmd <= 'd0;
        ro_valid <= 0;
    end else if(~ri_ready)   begin
        ro_cmd <= 'd0;
        ro_valid <= 0;
    end else if(r_st_current == P_SET_RATESENS)   begin
        ro_cmd <= SET_FILTER_RATE_XYZ;
        ro_valid <= 1;
    end else if(r_st_current == P_SET_ACCSENS)   begin
        ro_cmd <= SET_FILTER_ACC;
        ro_valid <= 1;
    end else if(r_st_current == P_EN_SENSOR)   begin
        ro_cmd <= EN_SENSOR;
        ro_valid <= 1;
    end else if(r_st_current == P_READ_TWICE)   begin
        ro_cmd <= READ_SUM_STATUS;
        ro_valid <= 1;
    end else if(r_st_current == P_EOI)   begin
        ro_cmd <= SET_EOI;
        ro_valid <= 1;
    end else    begin
        ro_cmd <= 'd0;
        ro_valid <= 0;
    end

always @(posedge i_clk, posedge i_rst)
    if(i_rst)   begin
        ri_ready <= 'd0;
        ri_data <= 'd0;
        ri_valid <= 'd0;
        r_spi_active_d1 <= 'd0;
    end else    begin
        ri_ready <= i_ready;
        ri_data <= i_data;
        ri_valid <= i_valid;
        r_spi_active_d1 <= w_spi_active;
    end

always @(posedge i_clk, posedge i_rst)
    if(i_rst)   begin
        ro_reset_n <= 1;
    end else if(r_st_current == P_RESET)   begin
        ro_reset_n <= 0;
    end else    begin
        ro_reset_n <= 1;
    end

//初始化完成后，一直停在P_OVER状态
always @(posedge i_clk, posedge i_rst)
    if(i_rst)   begin
        ro_init_finish <= 'd0;
    end else if(r_st_current == P_OVER)   begin
        ro_init_finish <= 1;
    end else    begin
        ro_init_finish <= ro_init_finish;
    end

//读两次状态寄存器
always @(posedge i_clk, posedge i_rst)
    if(i_rst)   begin
        r_read_once <= 0;
    end else if(r_st_current == P_IDLE)   begin
        r_read_once <= 0;
    end else if((r_st_current == P_READ_TWICE) && w_spi_active_rise)  begin
        r_read_once <= 1;
    end else    begin
        r_read_once <= r_read_once;
    end

// always @(posedge i_clk, posedge i_rst)
//     if(i_rst)   begin
//         r_state <= 0;
//     end else if((r_st_current == P_CHECK) && ri_valid )   begin
//         r_state <= ri_data[19:4];
//     end else    begin
//         r_state <= r_state;
//     end


// always @(posedge i_clk, posedge i_rst)
//     if(i_rst)   begin
//     end else if()   begin
//     end else if()   begin
//     end else    begin
//     end

endmodule
