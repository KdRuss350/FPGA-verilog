module communication_2M(
							clk40M, 
							reset,
							send_flag,
							out_data_x,
							out_data_y,
							out_data_z,
							pitch_init,
							temperature_x,
							temperature_y,
							temperature_z,
							//serial,
							di2
							 
						 );
                   
input        clk40M;
input        reset;
input 		 send_flag;
input [23:0] out_data_x,out_data_y,out_data_z;

//input serial;
input [15:0] temperature_x;
input [15:0] temperature_y;
input [15:0] temperature_z;
input [15:0] pitch_init;

output       di2;                      
//--------------------------Switch temperature---------------//
wire [15:0]  ex_temperature_x;
wire [15:0]  ex_temperature_y;
wire [15:0]  ex_temperature_z;
assign ex_temperature_x={temperature_x};//16'h87;
//assign ex_temperature_x= 16'd01;
assign ex_temperature_y={temperature_y};
assign ex_temperature_z={temperature_z};


//---------------------------send----------------------------//
wire        delay_send_flag;

wire [23:0]  out_data_x1,out_data_y1,out_data_z1;
// assign 		out_data_x1={out_data_x[31],out_data_x[31:9]};// out_data_x[31:8] out_data_x[28:5]
// assign 		out_data_y1={out_data_x[31],out_data_y[31:9]};//out_data_y[31:8] out_data_y[28:5]
// assign 		out_data_z1={out_data_x[31],out_data_z[31:9]};//out_data_z[31:8] out_data_z[28:5]
assign 		out_data_x1=out_data_x;
assign 		out_data_y1=out_data_y;
assign 		out_data_z1=out_data_z;


// assign delay_send_flag=send_flag;

SRL16E XLXI_comunication ( .A0(1'b1), .A1(1'b0), .A2(1'b1), .A3(1'b0), 
             .CE(1'b1), .CLK(clk40M), .D(send_flag), .Q(delay_send_flag));
 
//----------ssr--------//
wire check_bit_x0, check_bit_x1, check_bit_x2;

assign check_bit_x0 = !(^out_data_x1[7:0]);
assign check_bit_x1 = !(^out_data_x1[15:8]);
assign check_bit_x2 = !(^out_data_x1[23:16]);

wire check_bit_y0, check_bit_y1, check_bit_y2;
assign check_bit_y0 = !(^out_data_y1[7:0]);
assign check_bit_y1 = !(^out_data_y1[15:8]);
assign check_bit_y2 = !(^out_data_y1[23:16]);

wire check_bit_z0, check_bit_z1, check_bit_z2;
assign check_bit_z0 = !(^out_data_z1[7:0]);
assign check_bit_z1 = !(^out_data_z1[15:8]);
assign check_bit_z2 = !(^out_data_z1[23:16]);

wire check_bit_T0_x, check_bit_T1_x;
assign check_bit_T0_x = !(^ex_temperature_x[7:0]);
assign check_bit_T1_x = !(^ex_temperature_x[15:8]);

wire check_bit_T0_y, check_bit_T1_y;
assign check_bit_T0_y = !(^ex_temperature_y[7:0]);
assign check_bit_T1_y = !(^ex_temperature_y[15:8]);

wire check_bit_T0_z, check_bit_T1_z;
assign check_bit_T0_z = !(^ex_temperature_z[7:0]);
assign check_bit_T1_z = !(^ex_temperature_z[15:8]);

////////////////////////////////////////////////////////


wire [7:0] data_head;
assign data_head=8'h14;


wire check_head;
assign check_head=!(^data_head[7:0]);

wire [7:0] data_effect;
assign data_effect=8'h0f;


wire check_data_effect;
assign check_data_effect=!(^data_effect[7:0]);

reg [7:0] command;
wire check_command;
reg command_effect;
reg [15:0] command_counter;
reg  [7:0] reset_counter;

wire [7:0] command_counter1;
wire [7:0] command_counter2;
wire check_counter1;
wire check_counter2;
always@(posedge clk40M or posedge reset)
begin
	if(reset)
		begin
			command<=0;
			command_effect<=0;
			command_counter<=0;
			reset_counter <=0;
		end
	else if(send_flag==1'b1)
		begin
			case(pitch_init)
			16'h0000:
				begin 
					command<=8'h00; 
					command_effect<=1'b1;
					command_counter<=command_counter+1'b1;
				end
			16'hB22B:
				begin 
					command<=8'h22; 
					command_effect<=1'b1;
					command_counter<=command_counter+1'b1;
				end
			16'hC33C:
				begin 
					command<=8'h33; 
					command_effect<=1'b1;
					command_counter<=command_counter+1'b1;
				end
			16'hD44D:
				begin 
					command<=8'h44; 
					command_effect<=1'b1;
					command_counter<=command_counter+1'b1;
				end
			16'hE55E:
				begin 
					command<=8'h55; 
					command_effect<=1'b1;
					command_counter<=command_counter+1'b1;
                    
				end
			default: 
				begin 
					command<=8'h00; 
					command_effect<=1'b0; 
					command_counter<=command_counter;
				end
			endcase
		end
	else
		begin
			command<=command; 
			command_effect<=command_effect;
			command_counter<=command_counter;
			reset_counter<=0;
		end
end

assign check_command=!(^command);

assign command_counter1=command_counter[7:0];
assign command_counter2=command_counter[15:8];

assign check_counter1=!(^command_counter1);
assign check_counter2=!(^command_counter2);

parameter [7:0] fog_state=8'b00010100;
wire check_fog_state;
assign check_fog_state=!(^fog_state);

wire check_resetcounter;
assign check_resetcounter=!(^reset_counter);

wire [31:0] sum_check_temp;
wire [7:0]  sum_check;
wire        check_sum_check;
assign sum_check_temp=data_effect+command+command_counter1+command_counter2//ex_opticalpower_x[15:8]+ex_opticalpower_x[7:0]  //
						+out_data_x1[23:16]+out_data_x1[15:8]+out_data_x1[7:0]
						+out_data_y1[23:16]+out_data_y1[15:8]+out_data_y1[7:0]
						+out_data_z1[23:16]+out_data_z1[15:8]+out_data_z1[7:0]
						+ex_temperature_x[15:8]+ex_temperature_x[7:0]
						+ex_temperature_y[15:8]+ex_temperature_y[7:0]
						+ex_temperature_z[15:8]+ex_temperature_z[7:0]   ///YH-50陀螺暂定给出x,y,z轴温度和y光功率
						+reset_counter;
assign sum_check=sum_check_temp[7:0];
assign check_sum_check=!(^sum_check);

wire [241:0]   out_data241;
 assign        out_data241[241:0] = {  
									 1'b1,check_sum_check,sum_check,1'b0,   ///11
									 1'b1,check_resetcounter,reset_counter,1'b0,  ///11
								//	 1'b1,check_bit_P0_y,ex_opticalpower_y[7:0],1'b0,
								//	 1'b1,check_bit_P1_y,ex_opticalpower_y[15:8],1'b0, 
									 1'b1,check_bit_T0_z,ex_temperature_z[7:0],1'b0,
									 1'b1,check_bit_T1_z,ex_temperature_z[15:8],1'b0,
									 1'b1,check_bit_T0_y,ex_temperature_y[7:0],1'b0,
									 1'b1,check_bit_T1_y,ex_temperature_y[15:8],1'b0, 
									 1'b1,check_bit_T0_x,ex_temperature_x[7:0],1'b0, ///11
									 1'b1,check_bit_T1_x,ex_temperature_x[15:8],1'b0,
									 1'b1,check_bit_z0,out_data_z1[7:0],1'b0,
									 1'b1,check_bit_z1,out_data_z1[15:8],1'b0,
									 1'b1,check_bit_z2,out_data_z1[23:16],1'b0,
									 1'b1,check_bit_y0,out_data_y1[7:0],1'b0,
									 1'b1,check_bit_y1,out_data_y1[15:8],1'b0,
									 1'b1,check_bit_y2,out_data_y1[23:16],1'b0,
									 1'b1,check_bit_x0,out_data_x1[7:0],1'b0,
									 1'b1,check_bit_x1,out_data_x1[15:8],1'b0,
									 1'b1,check_bit_x2,out_data_x1[23:16],1'b0, ///11   11 X 22  =  242
									 1'b1,check_counter1,command_counter1,1'b0,  ///11
									 1'b1,check_counter2,command_counter2,1'b0,///11
							//		 1'b1,check_bit_P0_x,ex_opticalpower_x[7:0],1'b0,
							//		 1'b1,check_bit_P1_x,ex_opticalpower_x[15:8],1'b0, 
									 
									 1'b1,check_command,command[7:0],1'b0, ///11
									 1'b1,check_data_effect,data_effect[7:0],1'b0,///11
									 1'b1,check_head,data_head[7:0],1'b0  ///11
							        };   
///////////////////////////////////////

//assign        out_data241[241:0]={
//                                                1'b0,data_head[7:0],check_head,1'b1,
//                                                1'b0,data_effect[7:0],check_data_effect,1'b1,
//                                                1'b0,command[7:0],check_command,1'b1,
//                                                1'b0,command_counter2,check_counter2, 1'b1,
//                                                1'b0,command_counter1,check_counter1,1'b1,
//                                                1'b0,out_data_x1[23:16],check_bit_x2, 1'b1,
//                                                1'b0,out_data_x1[15:8],check_bit_x1,1'b1,
//                                                1'b0,out_data_x1[7:0],check_bit_x0, 1'b1,
//                                                1'b0,out_data_y1[23:16],check_bit_y2,1'b1,
//                                                1'b0,out_data_y1[15:8],check_bit_y1,1'b1,
//                                                1'b0,out_data_y1[7:0],check_bit_y0,1'b1,
//                                                1'b0,out_data_z1[23:16],check_bit_z2,1'b1,
//                                                1'b0,out_data_z1[15:8],check_bit_z1,1'b1,
//                                                1'b0,out_data_z1[7:0],check_bit_z0,1'b1,
//                                                1'b0,ex_temperature_x[15:8],check_bit_T1_x,1'b1,
//                                                1'b0,ex_temperature_x[7:0],check_bit_T0_x,1'b1,
//                                                1'b0,ex_temperature_x[15:8],check_bit_T1_x,1'b1,
//                                                1'b0,ex_temperature_x[7:0],check_bit_T0_x,1'b1,
//                                                1'b0,ex_temperature_x[15:8],check_bit_T1_x,1'b1,
//                                                1'b0,ex_temperature_x[7:0],check_bit_T0_x,1'b1,
//                                                1'b0,fog_state,check_fog_state,1'b1,
//                                                1'b0,sum_check,check_sum_check,1'b1
//                                                };
reg [9:0]  count_data_delay;
reg [11:0]  count_clk384;
reg [241:0] data_pc241; 
reg        di1;

reg        out_flag;



reg [7:0]   count_out;

reg[2:0]    STATE_OUT;
parameter   DATA_IDLE = 3'b001, DATA_VALUE = 3'b010,	DATA_OUT = 3'b100;

always@(posedge clk40M or posedge reset)
if(reset)
   begin
      STATE_OUT <= DATA_IDLE;
	   count_clk384 <= 0;
	   count_out <= 0;
		data_pc241 <= 0;
		di1 <= 1;
		out_flag<=0;
	end  
else  
   case(STATE_OUT)													       
	DATA_IDLE: //---------------------------------------------------------------------	//flag  P
		   begin
			out_flag<=0;
		    if(delay_send_flag&&command_effect)
		       begin
				    STATE_OUT<=DATA_VALUE;
				    count_clk384<=0;
	                count_out<=0;
		            di1 <= 1;
				  end
			 else
			    begin
				  	STATE_OUT<=DATA_IDLE;	
					count_clk384<=0;
	                count_out<=0;
		        	di1 <= 1;
				 end
         end
   DATA_VALUE:	//--------------------------------------------------------// data  delay
			begin
		//	    if(count_data_delay>=10'b1010110000)//0111110000    
		//	      begin
				    data_pc241[241:0]<=out_data241;
				    count_data_delay<=0;
				    STATE_OUT<=DATA_OUT;
				    count_clk384<=0;
	        	    count_out<=0;
			        di1 <= 1;
		//		   end
		//	    else 
		//	        begin
		//			    count_data_delay<=count_data_delay+1; 
		//			    STATE_OUT<=DATA_VALUE;
		//			end
			end	  		

   DATA_OUT:  //--------------------------------------------------------//send data
       begin
   		    if(count_out==8'hf5)  
				begin
					STATE_OUT <= DATA_IDLE;
					count_out <= 0;
			      	count_clk384 <= 0;
			      	di1 <= 1;
					out_flag<=1;
            	end
		    else
			    begin	 
					STATE_OUT<=DATA_OUT;
					if(count_clk384>=12'd347)		//2M  19d=10011
						begin
							di1<=data_pc241[0]; 
							data_pc241 <= {1'b1,data_pc241[241:1]};		  //
							count_clk384 <= 0;
							count_out <= count_out + 1;
						end
					else
						begin
							count_clk384 <= count_clk384 + 1;
							count_out <= count_out;
						end
			    end
          end
      default: STATE_OUT <= DATA_IDLE; 
	 endcase

assign di2=di1;

endmodule