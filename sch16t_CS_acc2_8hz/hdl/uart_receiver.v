`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    15:09:56 01/12/2015 
// Design Name: 
// Module Name:    uart_receiver 
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
module uart_receiver(
input clk_40M,
input reset,
input ro,
output reg [7:0] rec_data,
output reg rec_done_pe
    );
	
	
reg    ro_temp0, ro_temp;
wire   inclk;
assign inclk = clk_40M;

always@(posedge inclk or posedge reset)
if(reset)
   begin
       ro_temp <= 1;
       ro_temp0 <= 1;
	 end
else 
    begin
		ro_temp0 <= ro;
		ro_temp <= ro_temp0;			//2nd synchronization
	end

//reg          rec_done_pe;
reg [11:0]    rec_cnt1, rec_cnt3;
reg [3:0]    rec_cnt2;
reg          rec_bit;
reg [8:0]    rec_data_temp;
//reg [7:0]    rec_data;
reg [4:0]    STATE_REC;
reg          check_bit;
parameter    IDLE=5'h01, START=5'h02, BIT8=5'h04, SHIFT=5'h08, JUDGE=5'h10;

always@(posedge inclk or posedge reset)//-------40M
if(reset)
    begin
		  rec_cnt1 <= 0;
		  rec_cnt2 <= 0;
		  rec_cnt3 <= 0;
		  rec_data_temp <= 0;
		  rec_bit <= 0;
		  rec_done_pe <= 1'b0;
		  STATE_REC <= IDLE;
		  rec_data <=0;
		  check_bit <=0;
	 end
else        
    case(STATE_REC)
         IDLE: if(ro_temp==1'b0)
				begin
					STATE_REC <= START;
					rec_done_pe <= 1'b0;
				end
				else
				begin
					STATE_REC <= IDLE;
					rec_done_pe <= 1'b0;
				end
         START: if(rec_cnt1==12'd347)//5'b10010)		    // 20-1,from 0,then 18		//230.4kbps
					begin
						 rec_cnt1 <= 0;
						 rec_cnt3 <= 0;
						 if(rec_cnt3 > 12'd180)//5'b01100)	 //12
							STATE_REC <= IDLE;
						 else
							STATE_REC <= BIT8;
					end
                else
					begin
						rec_cnt1 <= rec_cnt1 + 1'b1;
						rec_cnt3 <= rec_cnt3 +{4'b0000,ro_temp};
					end 
         BIT8: if(rec_cnt1==12'd347)//
				begin
					STATE_REC <= SHIFT;
					rec_cnt1 <= 0;
					rec_cnt3 <= 0;
					if(rec_cnt3 > 12'd180)//5'b01100)
						rec_bit <= 1;
					else
						rec_bit <= 0;
				end
               else
				begin
					rec_cnt1 <= rec_cnt1+1'b1;
					rec_cnt3 <= rec_cnt3 + {4'b0000,ro_temp};
				end 
         SHIFT: if(rec_cnt2==4'b1001)
				begin
					STATE_REC <= JUDGE;
					rec_cnt2 <= 0;
					check_bit <= (~^rec_data_temp[7:0]);		//odd (~^rec_data_temp[7:0]);  Even !(^rec_data_temp[7:0])
				end
				else
				begin
					rec_data_temp <= {rec_bit, rec_data_temp[8:1]};
					STATE_REC <= BIT8;
					rec_cnt2 <= rec_cnt2 + 1'b1;
				end
		 JUDGE: begin
					STATE_REC <= IDLE;
					if(rec_data_temp[8] == check_bit)
					begin
						rec_done_pe <= 1'b1;
						rec_data <= rec_data_temp[7:0];
					end
				end
		 default: STATE_REC <= IDLE;
     endcase


endmodule