
module sch16t_loopRead #(
    parameter DATA_WIDTH     = 32         // 数据位宽
)(
    input                       i_clk,
    input                       i_rst,

    input                       loop_read_en,//loop_read_en为0，o_cmd也为0

    output  [DATA_WIDTH-1: 0]   o_cmd,
    output                      o_cmd_valid,
    input                       i_ready,
    input   [DATA_WIDTH-1: 0]   i_data,
    input                       i_data_valid,

    output  [DATA_WIDTH-1: 0]   o_sens_data,
    output                      o_sens_valid
);

localparam      READ_RATE_X1            = 32'h00400001,
                READ_RATE_Y1            = 32'h00800007,
                READ_RATE_Z1            = 32'h00C00005,
// localparam      READ_RATE_X1            = 32'h02800001,
//                 READ_RATE_Y1            = 32'h02C00003,
//                 READ_RATE_Z1            = 32'h03000006,
                READ_ACC_X1             = 32'h01000000,
                READ_ACC_Y1             = 32'h01400002,
                READ_ACC_Z1             = 32'h01800004,
                READ_TEMPERATURE        = 32'h04000004;  

reg  [DATA_WIDTH-1: 0]   ri_data;
reg                      ri_data_valid;
reg  [DATA_WIDTH-1: 0]   ro_sens_data;
reg                      ro_sens_valid;
reg  [DATA_WIDTH-1: 0]   ro_cmd;
reg                      ro_cmd_valid;
reg                      ri_ready;
reg  [7:0]               r_read_seq;
wire                     w_spi_active;
reg                      r_spi_active_d1;
wire                     w_spi_active_rise;

assign  o_sens_data = ro_sens_data;
assign  o_sens_valid = ro_sens_valid;
assign  o_cmd = ro_cmd;
assign  o_cmd_valid = ro_cmd_valid;
assign  w_spi_active = ri_ready && ro_cmd_valid;
assign  w_spi_active_rise = ~w_spi_active && r_spi_active_d1; //w_spi_active从1变成0了

always @(posedge i_clk, posedge i_rst)
    if(i_rst)   begin
        ri_ready <= 'd0;
        r_spi_active_d1 <= 'd0;
        ri_data <= 'd0;
        ri_data_valid <= 0;
    end else    begin
        ri_ready <= i_ready;
        r_spi_active_d1 <= w_spi_active;
        ri_data <= i_data;
        ri_data_valid <= i_data_valid;
    end

always @(posedge i_clk, posedge i_rst)
    if(i_rst)   begin
        r_read_seq <= 'd0;
    end else if(~loop_read_en)   begin
        r_read_seq <= 'd0;
    end else if(r_read_seq == 0)   begin
        r_read_seq <= 'd1;
    end else if(r_read_seq > 7)   begin
        r_read_seq <= 'd0;
    end else if(w_spi_active_rise)   begin       
        r_read_seq <= r_read_seq + 1;
    end else    begin
        r_read_seq <= r_read_seq;
    end

always @(posedge i_clk, posedge i_rst)
    if(i_rst)   begin
        ro_cmd <= 'd0;
    end else    begin
        case(r_read_seq)
            1:  ro_cmd <= READ_RATE_X1    ;
            2:  ro_cmd <= READ_RATE_Y1    ;
            3:  ro_cmd <= READ_RATE_Z1    ;
            4:  ro_cmd <= READ_ACC_X1     ;
            5:  ro_cmd <= READ_ACC_Y1     ;
            6:  ro_cmd <= READ_ACC_Z1     ;
            7:  ro_cmd <= READ_TEMPERATURE;
            default:    ro_cmd <= 'd0;
        endcase
    end

always @(posedge i_clk, posedge i_rst)
    if(i_rst)   begin
        ro_cmd_valid <= 0;
    end else if(~loop_read_en)   begin
        ro_cmd_valid <= 0;
    end else if(ro_cmd_valid)   begin //ro_cmd_valid就一个时钟
        ro_cmd_valid <= 0;
    end else if(r_read_seq != 0 && i_ready)   begin
        ro_cmd_valid <= 1;
    end else    begin
        ro_cmd_valid <= 0;
    end

/*接收到的传感数据进行处理*/
always @(posedge i_clk, posedge i_rst)
    if(i_rst)   begin
        ro_sens_data  <= 'd0;
        ro_sens_valid <= 'd0;
    end else if(~loop_read_en)   begin
        ro_sens_data  <= 'd0;
        ro_sens_valid <= 'd0;
    end else    begin
        ro_sens_data  <= {16'd0, ri_data[19:4]};
        ro_sens_valid <= ri_data_valid;
    end

// always @(posedge i_clk, posedge i_rst)
//     if(i_rst)   begin
//     end else if()   begin
//     end else if()   begin
//     end else    begin
//     end

endmodule
