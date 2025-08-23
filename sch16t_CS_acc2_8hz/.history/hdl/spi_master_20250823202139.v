// spi_master.v
`timescale 1ns / 1ps

module spi_master #(
    parameter CLK_FREQ       = 40_000_000, // 系统时钟频率，单位为 Hz
    parameter SCK_FREQ       = 10_000_000, // SPI 时钟频率，单位为 Hz
    parameter CPOL           = 0,          // 时钟极性
    parameter CPHA           = 0,          // 时钟相位,这个对00和11都没问题
    parameter DATA_WIDTH     = 32,         // 数据位宽
    //parameter NUM_WORDS      = 7,          // 这个参数没用上吧，如果读写那应该传输7个word
    parameter T_CS_SETUP     = 40,         // CS 设置时间
    parameter T_CS_HOLD      = 40,         // CS 保持时间
    parameter T_SETUP        = 10          // 数据设置时间
)(
    input wire         sys_rst_n,     // 系统复位，低有效
    input wire         sys_clk,       // 系统时钟
    input wire         lb_wr_n,       // 本地总线写使能，开启写过程
    input wire [DATA_WIDTH-1:0] lb_data_in,  // 本地总线数据输入
    output reg [DATA_WIDTH-1:0] lb_data_out, // 本地总线数据输出
    output reg         lb_rd_n,       // 本地总线读数据有效信号，一个word传输完成
    output wire        spi_cs_n,      // SPI 片选信号，低有效?
    output wire        spi_sck,       // SPI 时钟
    output wire        spi_mosi,      // SPI 主设备发送的数据
    input wire         spi_miso,      // SPI 从设备发送的数据
    output wire [3:0]  spi_debug      // 调试信号,没有输出
);

//----------------------------------------------
// 时钟周期计算
//----------------------------------------------
localparam CLK_PERIOD_NS       = 1_000_000_000 / CLK_FREQ; // 系统时钟周期 (ns)，时钟频率40MHz，周期25ns
localparam SCK_PERIOD_NS       = 1_000_000_000 / SCK_FREQ; // SPI 时钟周期 (ns)，sck频率10MHz，周期100ns
localparam SCK_HALF_CYCLES     = (SCK_PERIOD_NS / 2) / CLK_PERIOD_NS;//这里等于2(0,1,2)一共3个周期
localparam SCK_HALF_CYCLES_ACTUAL = (SCK_HALF_CYCLES < 1) ? 1 : SCK_HALF_CYCLES;//避免spi时钟过快，如果小于1，强制变为1，这里是2

localparam CS_SETUP_CYCLES     = (T_CS_SETUP + CLK_PERIOD_NS - 1) / CLK_PERIOD_NS; // CS 设置延时计数(40+25-1/25=2)，就是3个周期，对应cs拉低之后等待时间，之后mosi发数据
localparam CS_HOLD_CYCLES      = (T_CS_HOLD + CLK_PERIOD_NS - 1) / CLK_PERIOD_NS;  // 没用上，CS 保持延时计数(40+25-1/25=2)，就是3个周期
localparam SETUP_CYCLES        = (T_SETUP + CLK_PERIOD_NS - 1) / CLK_PERIOD_NS;    // 没用上，数据设置延时计数(10+25-1/25=1)，就是2个周期，对应


//----------------------------------------------
// 三种计数方式
//----------------------------------------------
reg [15:0] cycle_cnt;        // 用来计算状态机持续时间
reg [5:0]  bit_cnt;          // 位计数器 (0 - DATA_WIDTH-1)
reg [2:0]  word_cnt;         // 字计数器 (0 - NUM_WORDS-1)
reg [3:0] current_state, next_state;
// reg [4:0]  cs_delay_cnt;

//----------------------------------------------
// SPI 信号寄存�?
//----------------------------------------------
reg spi_sck_reg;
reg spi_cs_n_reg;
reg spi_mosi_reg;

assign spi_sck  = spi_sck_reg;
assign spi_cs_n = spi_cs_n_reg;
assign spi_mosi = spi_mosi_reg;
assign spi_debug = current_state; //把状态机的状态输出，作为spi_debug


//----------------------------------------------
// 状态机编码，使用3bit
//----------------------------------------------
localparam STATE_IDLE               = 4'd0; //空闲状态
localparam STATE_CS_ASSERT          = 4'd1; //cs拉低，开启传输通信
localparam STATE_CS_SETTLE          = 4'd2; //cs低电平持续时间，等mosi传输数据
localparam STATE_SEND_BIT           = 4'd3; //mosi开始传输数据，提前传输
localparam STATE_SCK_HIGH           = 4'd4; //sck拉高
localparam STATE_SCK_LOW            = 4'd5; //sck拉低
localparam STATE_CS_DEASSERT        = 4'd6; //cs拉高
localparam STATE_CS_DELAY           = 4'd7; //cs拉高后延时时间
localparam STATE_TRANSFER_DONE      = 4'd8; //向上层传输完成信号，传输完成，等待下一个传输信号




//----------------------------------------------
// 状态机转换
//----------------------------------------------
always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n)
        current_state <= STATE_IDLE;
    else
        current_state <= next_state;
end

//----------------------------------------------
// 下一个状态�?�辑
//----------------------------------------------
always @(*) begin
    case (current_state)
        STATE_IDLE: begin //如果lb_wr_n写指令拉低，那么等一个时钟进入状态1
//            if (!lb_wr_n && word_cnt < NUM_WORDS)
            if (!lb_wr_n)            
                next_state = STATE_CS_ASSERT;
            else
                next_state = STATE_IDLE;
        end

        STATE_CS_ASSERT: begin
            next_state = STATE_CS_SETTLE;
        end

        STATE_CS_SETTLE: begin
            if (cycle_cnt >= CS_SETUP_CYCLES)
                next_state = STATE_SEND_BIT;
            else
                next_state = STATE_CS_SETTLE;
        end

        STATE_SEND_BIT: begin
            next_state = STATE_SCK_HIGH;
        end

        STATE_SCK_HIGH: begin
            if (cycle_cnt >= SCK_HALF_CYCLES_ACTUAL) //这里的值是2
                next_state = STATE_SCK_LOW;
            else
                next_state = STATE_SCK_HIGH;
        end

        STATE_SCK_LOW: begin
            if (cycle_cnt >= SCK_HALF_CYCLES_ACTUAL - 1) begin
                if (bit_cnt < DATA_WIDTH - 1)
                    next_state = STATE_SEND_BIT;//STATE_SEND_BIT这里又给了一个周期
                else
                    next_state = STATE_CS_DEASSERT;
            end
            else
                next_state = STATE_SCK_LOW;
        end

        STATE_CS_DEASSERT: begin
            next_state = STATE_CS_DELAY;
        end

         STATE_CS_DELAY: begin ///在这里面应该加上延时
//            if (word_cnt < NUM_WORDS - 1)
//                next_state = STATE_IDLE;
           if(cycle_cnt == 'd509)
                next_state = STATE_TRANSFER_DONE;
           else 
                next_state = STATE_CS_DELAY;      
                // next_state = STATE_IDLE;
        end

        STATE_TRANSFER_DONE: begin ///在这里面应该加上延时
//            if (word_cnt < NUM_WORDS - 1)
//                next_state = STATE_IDLE;
                
                next_state = STATE_IDLE;
        end

        default: begin
            next_state = STATE_IDLE;
        end
    endcase
end

//----------------------------------------------
// 用来记录一个状态持续了多少个周期的，发生状态跳转，cycle_cnt清零
//----------------------------------------------
always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n)
        cycle_cnt <= 16'd0;
    else if (current_state != next_state)
        cycle_cnt <= 16'd0;
    else
        cycle_cnt <= cycle_cnt + 1;
end

//----------------------------------------------
// 位计数器逻辑
//----------------------------------------------
always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n)
        bit_cnt <= 6'd0;
    else if (current_state == STATE_SEND_BIT)//这一句是不是有点多余？
        bit_cnt <= bit_cnt; // 保持不变，准备发送当前位
    else if (current_state == STATE_SCK_LOW && cycle_cnt >= SCK_HALF_CYCLES_ACTUAL - 1) //SCK_HALF_CYCLES_ACTUAL - 1值为1；必须在sck传输时，电平为低电平时，才开始计数bit
        bit_cnt <= bit_cnt + 1;
    else if (current_state == STATE_CS_DEASSERT)
        bit_cnt <= 6'd0;
    else
        bit_cnt <= bit_cnt;
end

//----------------------------------------------
// 字计数器逻辑
//----------------------------------------------
always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n)
        word_cnt <= 3'd0;
    else if (current_state == STATE_CS_DEASSERT )
        word_cnt <= word_cnt + 1;
    else
        word_cnt <= word_cnt;
end

//----------------------------------------------
// CS延时计数器逻辑
//----------------------------------------------
// always @(posedge sys_clk or negedge sys_rst_n) begin
//     if (!sys_rst_n)
//         cs_delay_cnt <= 6'd0;
//     else if (current_state == STATE_CS_DELAY)
//         cs_delay_cnt <= cs_delay_cnt + 1;
//     else if (current_state == STATE_TRANSFER_DONE)
//          cs_delay_cnt <= 6'd0;
//     else
//         cs_delay_cnt <= cs_delay_cnt;
// end


//----------------------------------------------
// SPI 信号生成逻辑：线性序列机,对应三段式状态机的输出部分
//----------------------------------------------
always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) 
    begin
        spi_sck_reg  <= CPOL;        // 根据 CPOL 设置时钟初始电平状态
        spi_cs_n_reg <= 1'b1;        // CS 高电平
        spi_mosi_reg <= 1'b0;        // 默认 MOSI 低电平
    end
    else begin
        case (current_state)
            STATE_CS_ASSERT: begin //对应状态1
                spi_cs_n_reg <= 1'b0;    // 断言 CS,拉低cs，开启传输
            end

            STATE_SEND_BIT: //主机发送数据，提前发，对应状态3
            begin 
                spi_mosi_reg <= lb_data_in[DATA_WIDTH-1 - bit_cnt]; //  MSB 优先
            end

            STATE_SCK_HIGH: // SCK 上升，对应状态4
            begin
                spi_sck_reg <= 1'b1;     
            end

            STATE_SCK_LOW: // SCK 下降，对应状态5
            begin
                spi_sck_reg <= 1'b0;     
            end

            STATE_CS_DEASSERT: // 取消断言 CS，拉高cs，结束通信，对应状态6
            begin
                spi_cs_n_reg <= 1'b1;    
            end

            default: 
            begin
                
            end
        endcase
    end
end


/*数据接收模块，依旧是一个reg变量一个always块，不会写在一起！*/

//----------------------------------------------
// 数据接收逻辑(miso输入移位+接收完毕后的传送)，这里是全双工，你mosi在发送的时候我miso也在读
//----------------------------------------------
reg [31:0] shift_in_reg;

always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        shift_in_reg <= 32'd0;
    end
    else begin
        if (next_state == STATE_SCK_HIGH && spi_sck_reg) begin//sck刚刚拉高的时候读取数据
            shift_in_reg <= {shift_in_reg[30:0], spi_miso}; //这里的30要注意！
            $display("Time %t: Master received bit: %b", $time, spi_miso);
        end
        else
            shift_in_reg <= shift_in_reg;

    end
end

//如果接收完毕，则把寄存器的数值移位到lb_data_out
always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n)
        lb_data_out <= 32'd0;
    else if (current_state == STATE_TRANSFER_DONE)
        lb_data_out <= shift_in_reg;
    else
        lb_data_out <= lb_data_out;
end

//----------------------------------------------
// 本地总线接口控制逻辑，读完一个word就会拉低一下
//----------------------------------------------
always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        lb_rd_n <= 1'b1; // 复位时读数据无效
    end
    else begin
        if (current_state == STATE_TRANSFER_DONE) begin
            lb_rd_n <= 1'b0; // 读数据有�? (低有�?)
        end
        else if (current_state == STATE_IDLE) begin
            lb_rd_n <= 1'b1; // 读数据无�?
        end
    end
end

endmodule
