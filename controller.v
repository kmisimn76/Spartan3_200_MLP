`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    02:42:56 11/11/2020 
// Design Name: 
// Module Name:    controller 
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
module Controller
	#(parameter MODEL_ADDR_WIDTH=10, MODEL_DATA_WIDTH=18, MODEL_LOC_SIZE=1024,
					WEIGHT_ADDR_WIDTH=11, WEIGHT_DATA_WIDTH=9, WEIGHT_LOC_SIZE=2048,
					TENSOR_ADDR_WIDTH=9, TENSOR_DATA_WIDTH=36, TENSOR_LOC_SIZE=512,
					OUTPUT_ADDR_OFFSET=256)
	(
	input clk,
	input resetn,
	input [7:0] N,
	input [7:0] M,
	input start_sig,
	
	output reg mm_enb,
	output reg [MODEL_ADDR_WIDTH-1:0] mm_addrb,
	input [MODEL_DATA_WIDTH-1:0] mm_dob,
	
	output reg wm_read,
	output [15:0] wm_addr,
	
	output reg tm_input_read,
	output reg tm_output_write,
	output [TENSOR_ADDR_WIDTH+1:0] tm_input_addr,
	output reg [TENSOR_ADDR_WIDTH-1:0] tm_output_addr,
	output tm_output_group,
	
	output reg [2:0] multStg,
	output reg [7:0] shift,
	
	output reg [3:0] decodeStg,
	
	output reg [15:0] computing_clock
    );

	parameter	Waiting=4'h0,
					Ready=4'h1,
					ReadLInfo=4'h2,
					Multiplying=4'h3,
					Accumulating=4'h4,
					ShtReLU=4'h5,
					WriteBack=4'h6,
					Complete=4'h7;
					
	parameter	Mult_Waiting=3'h0,
					Mult_Multiplying=3'h1,
					Mult_Accumulating=3'h2,
					Mult_Activating=3'h3,
					Mult_MultWithoutAcc=3'h4;
	
	
	reg [3:0] state;
	reg [3:0] next_state;
	reg [15:0] ROWcnt;
	reg [15:0] COLcnt;
	reg [15:0] LAYERcnt;
	reg [4:0] ncnt;
	reg [15:0] COL;
	reg [15:0] ROW;
	
	wire [15:0] COL8;
	wire [18:0] COLadd7;
	assign COLadd7=COL+7;
	assign COL8=COLadd7[18:3];
	reg [15:0] Woffset;
	
	
	wire I;
	assign I=LAYERcnt[0];
	wire [7:0]tmp_tm_output_addr;
	reg [15:0] ROWbyCOL8;
	
	// Command
	assign tm_input_addr={I, ROWcnt[9:0]}; //input memory address
	assign wm_addr=ROWbyCOL8 + COLcnt + Woffset;		//weight memory address
	assign tmp_tm_output_addr = (ncnt==0)?(COLcnt*2):(COLcnt*2 + 8'd1);
	assign tm_output_group=~ncnt;
	always @(posedge clk)
	begin
		if(~resetn)
		begin
			ROW<=0; COL<=0; shift<=0;
			mm_enb<=0; mm_addrb<=0;
			wm_read<=0;
			tm_input_read<=0; tm_output_write<=0;
			tm_output_addr<=0;
			multStg<=Mult_Waiting; decodeStg<=0;
			Woffset<=0;
		end
		else begin
			case(state)
			Waiting:
			begin
				ROW<=0; COL<=0; shift<=0;
				mm_enb<=0; mm_addrb<=0;
				tm_output_addr<=0;
				multStg<=Mult_Waiting; decodeStg<=0;
			end
			Ready:
			begin
				mm_enb<=0;
				tm_output_addr<=0;
				Woffset<=0;
				multStg<=Mult_Waiting; decodeStg<=0;
			end
			ReadLInfo: begin
				case(ncnt)
				0:
				begin
					ROW<=0; COL<=0; shift<=0;
					mm_enb<=1; mm_addrb<=LAYERcnt*4;
					wm_read<=0;
					tm_input_read<=0; tm_output_write<=0;
					multStg<=Mult_Waiting;
				end
				1:
				begin
					ROW<=mm_dob;
					mm_enb<=1; mm_addrb<=LAYERcnt*4+1;
				end
				2:
				begin
					COL<=mm_dob;
					mm_enb<=1; mm_addrb<=LAYERcnt*4+2;
				end
				3:
				begin
					shift<=mm_dob[7:0];
					mm_enb<=0;
					wm_read<=1;
					tm_input_read<=1; tm_output_write<=0;
					multStg<=Mult_Multiplying;
				end
				default: begin end
				endcase
			end
			Multiplying:
			begin
				wm_read<=0;
				tm_input_read<=0; tm_output_write<=0;
				multStg<=Mult_Accumulating;
			end
			Accumulating:
			begin
				wm_read<=(ROWcnt!=ROW-1)?(1):(0);
				tm_input_read<=(ROWcnt!=ROW-1)?(1):(0); tm_output_write<=0;
				multStg<=(ROWcnt!=ROW-1)?(Mult_Multiplying):(Mult_Activating);
			end
			ShtReLU:
			begin
				wm_read<=0;
				tm_input_read<=0; tm_output_write<=0;
				multStg<=Mult_Waiting;
			end
			WriteBack:
			begin
				wm_read<=(ncnt==1)?(1):(0);
				Woffset<=(ncnt==1 && COLcnt==COL8-1)?(wm_addr+1):(Woffset);
				tm_input_read<=(ncnt==1)?(1):(0); tm_output_write<=1; tm_output_addr<={~I, tmp_tm_output_addr};
				multStg<=(ncnt==0)?(Mult_Waiting):(Mult_MultWithoutAcc);
				decodeStg<=(COLcnt==COL8-1 && ROWcnt==ROW-1 && LAYERcnt==N-1 && ncnt==1)?(1):(0);
			end
			Complete:
			begin
				wm_read<=0;
				tm_input_read<=0; tm_input_read<=(ncnt!=10)?(1):(0); tm_output_write<=0;
				decodeStg<=decodeStg+1;
			end
			default: begin mm_enb<=0; end
			endcase
		end
	end
	
	// IntraCount
	always @(posedge clk) begin
		if(~resetn) begin
			ncnt<=0;
			ROWcnt<=0; ROWbyCOL8<=0;
			COLcnt<=0;
			LAYERcnt<=0;
			computing_clock<=0;
		end
		else begin
			case(state)
			Waiting:
			begin
				ncnt<=0;
				ROWcnt<=0;
				COLcnt<=0;
			end
			Ready:
			begin
				ncnt<=0;
				LAYERcnt<=0;
			end
			ReadLInfo:
			begin
				ncnt<=(ncnt!=3)?(ncnt+1):(0);
				ROWcnt<=0; ROWbyCOL8<=0;
				COLcnt<=(ncnt!=3)?(COLcnt):(0);
			end
			Multiplying:
			begin
				ncnt<=0;
			end
			Accumulating:
			begin
				ncnt<=0;
				ROWcnt<=(ROWcnt!=ROW-1)?(ROWcnt+1):(ROWcnt); ROWbyCOL8<=(ROWcnt!=ROW-1)?(ROWbyCOL8+COL8):(ROWbyCOL8);
			end
			ShtReLU:
			begin
				ncnt<=0;
			end
			WriteBack:
			begin
				ncnt<=(ncnt!=1)?(ncnt+1):(0);
				ROWcnt<=(ncnt==0)?(ROWcnt):(0); ROWbyCOL8<=(ncnt==0)?(ROWbyCOL8):(0);
				COLcnt<=(ncnt==0)?(COLcnt):((COLcnt!=COL8-1)?(COLcnt+1):(COLcnt));
				LAYERcnt<=(ncnt==1 && COLcnt==COL8-1)?(LAYERcnt+1):(LAYERcnt);
			end
			Complete:
			begin
				ncnt<=(ncnt!=10)?(ncnt+1):(0);
				ROWcnt<=ROWcnt+1;
			end
			default:
			begin
				ncnt<=0;
			end
			endcase
			
			if(state==ReadLInfo || state==Multiplying || state==Accumulating || state==ShtReLU || state==WriteBack)
				computing_clock<=computing_clock+1;
			else if(state==Ready)
				computing_clock<=0;
			else
				computing_clock<=computing_clock;
		end
	end
	
	// Determine next state
	always @(*) begin
		case(state)
		Waiting:		next_state = (start_sig)?(Ready):(Waiting);
		Ready:		next_state = ReadLInfo;
		ReadLInfo:	next_state = (ncnt!=3)?(ReadLInfo):(Multiplying);
		Multiplying:
						next_state = Accumulating;
		Accumulating:
						next_state = (ROWcnt!=ROW-1)?(Multiplying):(ShtReLU);
		ShtReLU:		next_state = WriteBack;
		WriteBack:	next_state = (ncnt==0)?(WriteBack):(((COLcnt!=COL8-1 || ROWcnt!=ROW-1)?(Multiplying):((LAYERcnt!=N-1)?(ReadLInfo):(Complete))));
		Complete:	next_state = (ncnt==10)?(Waiting):(Complete);
		default:		next_state = Waiting;
		endcase
	end
	
	// State
	always @(posedge clk) begin
		if(~resetn) begin
			state <= Waiting;
		end
		else begin
			state <= next_state;
		end
	end

endmodule
