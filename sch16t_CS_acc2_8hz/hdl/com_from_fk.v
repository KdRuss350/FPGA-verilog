`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    15:40:45 01/12/2015 
// Design Name: 
// Module Name:    com_from_fk 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module out_filter(
	inclk,reset,
    ro,
    pitch_init,
    data_rdy_xyz,
    rec_done_pe,
	frame_done_ne
		);

input inclk;
input reset;
input ro;
output data_rdy_xyz;
output rec_done_pe;
output [15:0] pitch_init;
output reg frame_done_ne;
		
wire[7:0] rec_data;
//wire      rec_done_pe;
reg recv_err;
reg [15:0] pitch_init;
reg rdy1;
uart_receiver RECV_FK (
    .clk_40M(inclk), 
    .reset(reset), 
    .ro(ro), 
    .rec_data(rec_data), 
    .rec_done_pe(rec_done_pe)
    );

reg[4:0]  data_cnt;
//reg       recv_err;
//reg       frame_done_ne;

reg[15:0] pitch_init_temp;
reg[7:0]  check_byte, check_sum;
reg       send_en;

always @ (posedge inclk or posedge reset)		//rec_done_pe is generated at posedge 
if(reset)
begin
	data_cnt <= 5'd0;
	recv_err <= 1'b1;
	frame_done_ne <= 1'b0;
	check_byte <= 8'd0;
	check_sum <= 8'd0;

	
	pitch_init_temp <= 16'd0;
	
	pitch_init <= 16'd0;

end
else
begin
	if(rec_done_pe)
	begin
		case(data_cnt)
		5'd0: begin
				frame_done_ne <= 1'b0;
				if(rec_data == 8'heb)
				begin
					data_cnt <= data_cnt + 1'b1;
				end	
				else
				begin
					data_cnt <= 5'd0; 
					recv_err <= 1'b1;
				end
			  end
		5'd1: begin
				data_cnt <= data_cnt + 1'b1;
				pitch_init_temp[15:8] <= rec_data;				//???1
				check_sum <= rec_data;
			  end
		5'd2: begin
				data_cnt <= data_cnt + 1'b1;
				pitch_init_temp[7:0] <= rec_data;				//???2
				check_sum <= check_sum + rec_data;
			  end
		5'd3: begin
				data_cnt <= 5'd0;
				//frame_done_ne <= 1'b1;
				//check_byte <= rec_data;
				if(rec_data == check_sum)					//?????
				begin
					pitch_init   <= pitch_init_temp;
					recv_err     <= 1'b0;
					frame_done_ne   <= 1'b1;
				end
				else
				begin
					recv_err <= 1'b1;
				end
			  end
		default: data_cnt <= 5'd0;
		endcase
	end
	else
	begin
		frame_done_ne <= 1'b0;
	end
end

parameter  START=2'b01, RDY=2'b10;
reg state_rdy,cnt_rdy;
always@(posedge inclk or posedge reset)
if(reset)
   begin 
      rdy1<=0;
      state_rdy<=START;
      cnt_rdy<=0;
   end
else
    begin
        case(state_rdy)
        START:
            begin
                if(send_en)    state_rdy<=RDY;//filter_start
                rdy1<=0;
            end
        RDY:
            begin
                if(cnt_rdy==7'd71)
                    begin
                        cnt_rdy<=0;
                        rdy1<=1;
                        state_rdy<=START;
                    end
                else
                    begin
                        rdy1<=0;
                        cnt_rdy<=cnt_rdy+1;
                    end                
            end
        endcase
    end

 SRL16E XLXI_data_rdy ( .A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), 
              .CE(1'b1), .CLK(inclk), .D(rdy1), .Q(data_rdy_xyz));


endmodule
