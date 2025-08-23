///////////////////////////////////////////////////////////////////////////////////////////////////
// Company: <Name>
//
// File: main_prog.v
// File history:
//      <Revision number>: <Date>: <Comments>
//      <Revision number>: <Date>: <Comments>
//      <Revision number>: <Date>: <Comments>
//
// Description: 
//
// 三通道输出xyz三轴数据
//赋值那块已经修改
// Targeted device: <Family::ProASIC3> <Die::A3P1000> <Package::144 FBGA>
// Author: <Name>
//
/////////////////////////////////////////////////////////////////////////////////////////////////// 

//`timescale <time_units> / <precision>

module main_prog #(
    parameter DATA_WIDTH  = 32 // 数据位宽
)
( 
	input clk_in, 		 // 40MHz 
	input RO,
	input spi_miso,

	output spi_mosi,
	output spi_sck,
	output spi_cs_n,
	output DI
);


reg [DATA_WIDTH -1 :0]  x_gyro_data;
reg [DATA_WIDTH -1 :0]  y_gyro_data;
reg [DATA_WIDTH -1 :0]  z_gyro_data;

reg [DATA_WIDTH -1 :0]  x_acc_data;
reg [DATA_WIDTH -1 :0]  y_acc_data;
reg [DATA_WIDTH -1 :0]  z_acc_data;

reg [DATA_WIDTH -1 :0]  temp ;

reg x_gyro_data_flag;
reg y_gyro_data_flag;
reg z_gyro_data_flag;
reg x_acc_data_flag;
reg y_acc_data_flag;
reg z_acc_data_flag;

wire [23 :0]  w_x_gyro_data;
wire [23 :0]  w_y_gyro_data;
wire [23 :0]  w_z_gyro_data;

wire [23 :0]  datax_out;
wire [23 :0]  datay_out;
wire [23 :0]  dataz_out;

wire [DATA_WIDTH -1 :0]  w_x_acc_data;
wire [DATA_WIDTH -1 :0]  w_y_acc_data;
wire [DATA_WIDTH -1 :0]  w_z_acc_data;

wire [DATA_WIDTH -1 :0]  w_temp ;

wire 					sens_valid;
wire [DATA_WIDTH -1 :0] sens_data;
wire					w_loop_read;
wire [15:0]             o_state;

assign w_x_gyro_data = datax_out;
assign w_y_gyro_data = datay_out;
assign w_z_gyro_data = dataz_out;

assign w_x_acc_data = x_acc_data;
assign w_y_acc_data = y_acc_data;
assign w_z_acc_data = z_acc_data;

assign w_temp = temp;

reg rst;
reg [2:0]   r_cnt;
reg [15:0]  reset_cnt;
wire [15:0] pitch_init;
wire frame_done_ne;	
wire receive_done_pe;
wire data_rdy_xyz;



INBUF INBUF_0(
	.PAD(clk_in),
	.Y(clk_oscillator)
	);

initial
begin
	rst = 1'b0;
	reset_cnt=16'd0;
end

always@(posedge clk_oscillator)
	if(reset_cnt==16'hf000)
	begin  
		reset_cnt<=reset_cnt+1;
		rst<=1'b1;
	end
	else if(reset_cnt>=16'hf00f)
	begin
		
		if(pitch_init==16'he55e)
		begin
		reset_cnt<=16'hf00e;
		//reset_cnt<=16'hf001;
		rst<=1'b1;
		end
		
		else
		begin
		reset_cnt<=16'hf00f;
		rst<=1'b0;
		end
	end
	else
	begin
		reset_cnt<=reset_cnt+1;
		rst<=rst;
	end

	
Global_NET Global_rst(.A(rst), .Y(reset));



// generater_clk clksum  (  
// 					.POWERDOWN (~rst),
// 					.CLKA (clk_oscillator),
// 					.clk_oscillator(clk_oscillator)
// 					); 
			
out_filter out(
		.inclk(clk_oscillator),
		.ro(RO),
		.reset(reset),
		.data_rdy_xyz(data_rdy_xyz),
		.pitch_init(pitch_init),
		.rec_done_pe(receive_done_pe),
		.frame_done_ne(frame_done_ne)
	);


communication_2M  comm(
							.clk40M(clk_oscillator), 
							.reset(reset),
							.send_flag(frame_done_ne),
							.out_data_x(datax_out),
							.out_data_y(datay_out),
							.out_data_z(dataz_out),
							//.serial(serial_start1),
							.pitch_init(pitch_init),
							.temperature_x(w_temp[15:0]),
							.temperature_y(w_temp[15:0]),
							.temperature_z(w_temp[15:0]),
							.di2(DI)							
						 );

sch16t_module sch16t_module_u0(
    .i_clk(clk_oscillator)           ,
    .i_rst(reset)           ,   

    .loop_en(1'b1)         , 
    .sens_data(sens_data)       ,   
    .sens_valid(sens_valid)      , 
	.w_loop_read(w_loop_read),
    // .o_state(o_state),
    // .x_gyro_data(),
    // .y_gyro_data(),
    // .z_gyro_data(),
    // .x_acc_data(),
    // .y_acc_data(),
    // .z_acc_data(),
    // .temp(),

    .o_reset_n()       ,   //EXTRESET
    .o_TA()            ,
    .spi_cs_n(spi_cs_n)		,
    .spi_sck(spi_sck)			,
    .spi_miso(spi_miso)		,   
    .spi_mosi(spi_mosi)
);


always@(posedge clk_oscillator or posedge reset)
    if(reset)
        r_cnt <= 0;
    else
        begin
            if(sens_valid)
                r_cnt <= r_cnt + 1;

            else if(r_cnt > 3'd6)
                r_cnt <= 0 ;
            
            else 
                r_cnt <= r_cnt ;
        end


always@(posedge clk_oscillator or posedge reset)
    if(reset)
    begin
        x_gyro_data <= 32'd0;
        y_gyro_data <= 32'd0;
        z_gyro_data <= 32'd0;
        x_acc_data <= 32'd0;
        y_acc_data <= 32'd0;
        z_acc_data <= 32'd0;
        temp <= 32'd0;
    end
    else
    begin
        if (sens_valid)
        begin
            case(r_cnt)
            0: x_gyro_data <= sens_data;
            1: y_gyro_data <= sens_data;
            2: z_gyro_data <= sens_data;
            3: x_acc_data <= sens_data;
            4: y_acc_data <= sens_data;
            5: z_acc_data <= sens_data;
            6: temp       <= sens_data;
            default ;
            endcase
        end

        else
            begin
            x_gyro_data <= x_gyro_data;
            y_gyro_data <= y_gyro_data;
            z_gyro_data <= z_gyro_data;
            x_acc_data  <= x_acc_data;
            y_acc_data  <= y_acc_data;
            z_acc_data  <= z_acc_data;
            temp        <= temp;
            end
    end


always@(posedge clk_oscillator or posedge reset)
    if(reset)
    begin
        y_gyro_data_flag <= 32'd0;
        z_gyro_data_flag <= 32'd0;
        x_gyro_data_flag <= 32'd0;
        x_acc_data_flag <= 32'd0;
        y_acc_data_flag <= 32'd0;
        z_acc_data_flag <= 32'd0;
      
    end
    else
    begin
        if (sens_valid)
        begin
            case(r_cnt)
            0: x_gyro_data_flag <= 1;
            1: y_gyro_data_flag <= 1;
            2: z_gyro_data_flag <= 1;
            3: x_acc_data_flag  <= 1;
            4: y_acc_data_flag  <= 1;
            5: z_acc_data_flag  <= 1;
            default ;
            endcase
        end

        else
            begin
            x_gyro_data_flag <= 0;
            y_gyro_data_flag <= 0;
            z_gyro_data_flag <= 0;
            x_acc_data_flag  <= 0;
            y_acc_data_flag  <= 0;
            z_acc_data_flag  <= 0;
            end
    end

acc           acc_exampx(
						.ad_clk(clk_oscillator),
						.reset_P(reset),
						.acc_start_flag(x_gyro_data_flag),
						.accdata_in(x_gyro_data[15:0]),
						.acc_num(16'd499),
						.accdata_out(datax_out)
						
					   );

acc           acc_exampy(
						.ad_clk(clk_oscillator),
						.reset_P(reset),
						.acc_start_flag(y_gyro_data_flag),
						.accdata_in(y_gyro_data[15:0]),
						.acc_num(16'd499),
						.accdata_out(datay_out)
						
					   );

acc           acc_exampz(
						.ad_clk(clk_oscillator),
						.reset_P(reset),
						.acc_start_flag(z_gyro_data_flag),
						.accdata_in(z_gyro_data[15:0]),
						.acc_num(16'd499),
						.accdata_out(dataz_out)
					   );

//<statements>

endmodule

