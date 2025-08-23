module acc( ad_clk, reset_P, acc_start_flag, accdata_in, accdata_out, accover_flag ,acc_num);

input		  ad_clk;
input		  reset_P;
input  		  acc_start_flag;
input  [15:0] accdata_in;
input  [15:0] acc_num;
output [23:0] accdata_out;
output 		  accover_flag;


wire  [31:0]  data_in;
assign data_in =(accdata_in[15])?{8'hff,accdata_in}:{8'h00,accdata_in};


reg [15:0] acc_count;
reg [23:0] accdata_out;
reg [23:0] data_acc;
reg		   accover_flag;

always@(posedge ad_clk or posedge reset_P)
if(reset_P)
	begin
		accover_flag <= 1'b0;
		accdata_out<=24'b0;
		data_acc<=24'b0;
		acc_count<=16'd0;
	end
else 
	if(acc_start_flag == 1'b1)
		begin
			if(acc_count==acc_num) 
				begin
					acc_count<=16'd0;
					accdata_out<=data_acc+data_in;
					data_acc<=16'd0;
					accover_flag <= 1'b1;
				end
			else
				begin
					acc_count<=acc_count+16'd1;
					data_acc<=data_acc+data_in;
					accdata_out<=accdata_out;
					accover_flag <= 1'b0;
				end
		end
	else
		begin
			accover_flag <= 1'b0;
			accdata_out<=accdata_out;
			data_acc<=data_acc;
			acc_count<=acc_count;
		end 


endmodule

