`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    22:08:14 11/09/2020 
// Design Name: 
// Module Name:    allocator 
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
module Allocator
	#(parameter MODEL_ADDR_WIDTH=10, MODEL_DATA_WIDTH=18, MODEL_LOC_SIZE=1024,
					WEIGHT_ADDR_WIDTH=11, WEIGHT_DATA_WIDTH=9, WEIGHT_LOC_SIZE=2048,
					TENSOR_ADDR_WIDTH=9, TENSOR_DATA_WIDTH=36, TENSOR_LOC_SIZE=512)
	(input clk_11MHz, input resetn,
	output reg [7:0] N,
	output reg [7:0] M,
	
	output reg mm_ena,
	output reg mm_wea,
	output reg [MODEL_ADDR_WIDTH-1:0] mm_addra,
	output reg [MODEL_DATA_WIDTH-1:0] mm_dla,
	
	output wm_ena_0, wm_ena_1, wm_ena_2, wm_ena_3, wm_ena_4, wm_ena_5, wm_ena_6, wm_ena_7,
	output wm_wea_0, wm_wea_1, wm_wea_2, wm_wea_3, wm_wea_4, wm_wea_5, wm_wea_6, wm_wea_7,
	output [WEIGHT_ADDR_WIDTH-1:0] wm_addra_0,
	output [WEIGHT_ADDR_WIDTH-1:0] wm_addra_1,
	output [WEIGHT_ADDR_WIDTH-1:0] wm_addra_2,
	output [WEIGHT_ADDR_WIDTH-1:0] wm_addra_3,
	output [WEIGHT_ADDR_WIDTH-1:0] wm_addra_4,
	output [WEIGHT_ADDR_WIDTH-1:0] wm_addra_5,
	output [WEIGHT_ADDR_WIDTH-1:0] wm_addra_6,
	output [WEIGHT_ADDR_WIDTH-1:0] wm_addra_7,
	output [WEIGHT_DATA_WIDTH-1:0] wm_dla_0,
	output [WEIGHT_DATA_WIDTH-1:0] wm_dla_1,
	output [WEIGHT_DATA_WIDTH-1:0] wm_dla_2,
	output [WEIGHT_DATA_WIDTH-1:0] wm_dla_3,
	output [WEIGHT_DATA_WIDTH-1:0] wm_dla_4,
	output [WEIGHT_DATA_WIDTH-1:0] wm_dla_5,
	output [WEIGHT_DATA_WIDTH-1:0] wm_dla_6,
	output [WEIGHT_DATA_WIDTH-1:0] wm_dla_7,

	output reg tm_ena, tm_wea,
	output reg [TENSOR_ADDR_WIDTH-1:0] tm_addra,
	output [TENSOR_DATA_WIDTH-1:0] tm_dla,
	
	input [7:0] RxData,
	input valid,
	output reg start_sig,
	
	output reg [3:0] StateLED
	);
	
	parameter	IMG_SIZE=10'd784;
	parameter 	Waiting=4'h0,
					FType=4'h1,
					Nnum=4'h2,
					S1=4'h3,
					S2=4'h4,
					WN=4'h5,
					Mnum=4'h6,
					MS1=4'h7,
					MS2=4'h8,
					ReadW=4'h9,
					ReadS=4'hA,
					ReadImage=4'hB,
					Last=4'hC,
					Error=4'hD;
					
	reg wm_ena[7:0];
	reg wm_wea[7:0];
	reg [WEIGHT_ADDR_WIDTH-1:0] wm_addra[7:0];
	reg [WEIGHT_DATA_WIDTH-1:0] wm_dla[7:0];
	assign wm_ena_0=wm_ena[0]; //wm_ena
	assign wm_ena_1=wm_ena[1];
	assign wm_ena_2=wm_ena[2];
	assign wm_ena_3=wm_ena[3];
	assign wm_ena_4=wm_ena[4];
	assign wm_ena_5=wm_ena[5];
	assign wm_ena_6=wm_ena[6];
	assign wm_ena_7=wm_ena[7];
	assign wm_wea_0=wm_wea[0]; //wm_wea
	assign wm_wea_1=wm_wea[1];
	assign wm_wea_2=wm_wea[2];
	assign wm_wea_3=wm_wea[3];
	assign wm_wea_4=wm_wea[4];
	assign wm_wea_5=wm_wea[5];
	assign wm_wea_6=wm_wea[6];
	assign wm_wea_7=wm_wea[7];
	assign wm_addra_0=wm_addra[0]; //wm_addra
	assign wm_addra_1=wm_addra[1];
	assign wm_addra_2=wm_addra[2];
	assign wm_addra_3=wm_addra[3];
	assign wm_addra_4=wm_addra[4];
	assign wm_addra_5=wm_addra[5];
	assign wm_addra_6=wm_addra[6];
	assign wm_addra_7=wm_addra[7];
	assign wm_dla_0=wm_dla[0]; //wm_dla
	assign wm_dla_1=wm_dla[1];
	assign wm_dla_2=wm_dla[2];
	assign wm_dla_3=wm_dla[3];
	assign wm_dla_4=wm_dla[4];
	assign wm_dla_5=wm_dla[5];
	assign wm_dla_6=wm_dla[6];
	assign wm_dla_7=wm_dla[7];
	
	reg [3:0] state;
	reg [3:0] next_state;
	reg [0:0] ncnt;
	reg [15:0] i;
	reg [15:0] cnt;
	reg [15:0] line;
	reg [15:0] acline;
	reg [15:0] L;
	reg [15:0] COL;
	reg [15:0] ROW;
	
	reg [7:0] buffer;
	reg [31:0] img_buffer;

	integer iter;
	//Memory Output
	assign tm_dla=img_buffer;
	always @(posedge clk_11MHz)
	begin
		if(~resetn)
		begin
			N<=0; M<=0; ROW<=0; COL<=0; 
			mm_ena<=0; mm_wea<=0; buffer<=0;
			mm_addra<=0; mm_dla<=0;
			for(iter=0;iter<8;iter=iter+1)
			begin
				wm_ena[iter]<=0; wm_wea[iter]<=0;
				wm_addra[iter]<=0; wm_dla[iter]<=0;
			end
			tm_ena<=0; tm_wea<=0;
			tm_addra<=0;
			img_buffer<=0;
		end
		else if(valid)
		begin
			case(state)
			//Model
			Nnum:
			begin
				N<=RxData;
			end
			S1:
			begin
				if(ncnt==0)
				begin
					mm_ena<=0; mm_wea<=0;
					buffer<=RxData;
				end
				else
				begin
					mm_ena<=1; mm_wea<=1;
					mm_addra<=i*4; mm_dla<={1'b0, 1'b0, buffer, RxData};
				end
			end
			S2:
			begin
				if(ncnt==0)
				begin
					mm_ena<=0; mm_wea<=0;
					buffer<=RxData;
				end
				else
				begin
					mm_ena<=1; mm_wea<=1;
					mm_addra<=i*4+1; mm_dla<={1'b0, 1'b0, buffer, RxData};
				end
			end
			WN:
			begin
				if(ncnt==0)
				begin
					mm_ena<=0; mm_wea<=0;
					buffer<=RxData;
				end
				else
				begin
					mm_ena<=1; mm_wea<=1;
					mm_addra<=i*4+2; mm_dla<={1'b0, 1'b0, buffer, RxData};
				end
			end
			//Weight
			Mnum:
			begin
				M<=RxData;
			end
			MS1:
			begin
				if(ncnt==0) begin buffer<=RxData; end
				else begin ROW<={buffer, RxData}; end
			end
			MS2:
			begin
				if(ncnt==0) begin buffer<=RxData; end
				else begin COL<={buffer, RxData}; end
			end
			ReadW:
			begin
				for(iter=0;iter<8;iter=iter+1)
				begin
					if(iter==L[2:0]) begin
						wm_ena[iter]<=1; wm_wea[iter]<=1;
						wm_addra[iter]<=acline[WEIGHT_ADDR_WIDTH-1:0]; wm_dla[iter]<={1'b0, RxData};
					end
					else begin
						wm_ena[iter]<=0; wm_wea[iter]<=0;
					end
				end
			end
			//Image
			ReadImage:
			begin
				tm_ena<=(i[1:0]==3)?(1):(0); tm_wea<=(i[1:0]==3)?(1):(0); tm_addra<=i/4;
				img_buffer<={RxData[7:0], img_buffer[31:8]};
			end
			Last:
			begin
				mm_ena<=0; mm_wea<=0;
				for(iter=0;iter<8;iter=iter+1)
				begin
					wm_ena[iter]<=0; wm_wea[iter]<=0;
				end
				tm_ena<=0; tm_wea<=0;
			end
			default:
			begin
				mm_ena<=0; mm_wea<=0;
				end
			endcase
		end
		else
		begin
			mm_ena<=0; mm_wea<=0;
			for(iter=0;iter<8;iter=iter+1)
			begin
				wm_ena[iter]<=0; wm_wea[iter]<=0;
			end
			tm_ena<=0; tm_wea<=0;
		end
	end
	
	//Count
	always @(posedge clk_11MHz)
	begin
		if(~resetn)
		begin
			cnt <= 0; ncnt <= 0;
			L<=0;
			line<=0; acline<=0;
			start_sig<=0;
		end
		else if(valid)
		begin
			case(state)
			Waiting:
			begin
				cnt <= 0; ncnt <= 0;
				start_sig <= 0;
			end
			FType:
			begin
				cnt <= (RxData==8'h03)?(IMG_SIZE-1):(0); ncnt <= 0;
				i<=0;
				end
			//Model
			Nnum:
			begin
				cnt <= RxData-1; ncnt <= 0;
				i<=0;
			end
			S1:
			begin
				cnt <= cnt; ncnt <= (ncnt==0)?(1):(0);
			end
			S2:
			begin
				cnt <= cnt; ncnt <= (ncnt==0)?(1):(0);
			end
			WN:
			begin
				cnt <= (ncnt==1 && cnt>0)?(cnt-1):(cnt);
				ncnt <= (ncnt==0)?(1):(0);
				i<=(ncnt==1 && cnt>0)?(i+1):(i);
			end
			//Weight
			Mnum:
			begin
				cnt <= RxData-1; ncnt <= 0;
				i<=0;
				acline <= 0;
			end
			MS1:
			begin
				cnt <= cnt; ncnt <= (ncnt==0)?(1):(0);
			end
			MS2:
			begin
				cnt <= cnt; ncnt <= (ncnt==0)?(1):(0);
				L <= 0;
				line <= 0;
			end
			ReadW:
			begin
				cnt <= (L==COL-1 && line==ROW-1 && cnt>0)?(cnt-1):(cnt);
				ncnt <= 0;
				L <= (L==COL-1)?(0):(L+1);
				line <= (L==COL-1)?(line+1):(line);
				acline <= (L[2:0]==3'h7 || L==COL-1)?(acline+1):(acline);
			end
			//Image
			ReadImage:
			begin
				cnt <= cnt-1; ncnt <= 0;
				i<=i+1;
				start_sig <= (cnt==0)?(1):(0);
			end
			
			Last:
			begin
				cnt <= 0; ncnt <= 0;
				start_sig<=0;
			end
			default:
			begin
				cnt <= cnt; ncnt <= ncnt;
				start_sig<=0;
			end
			endcase
		end
		else
		begin
			cnt <= cnt; ncnt <= ncnt;
			start_sig <= 0;
		end
	end

	//Next State
	always @(*) begin
		case(state)
		Waiting: next_state = (RxData==8'hFF) ? (FType) : (Waiting);
		FType: next_state = (RxData==8'h01) ? (Nnum) : ((RxData==8'h02) ? (Mnum) : ((RxData==8'h03) ? (ReadImage) : (Error)));
		//Model
		Nnum: next_state = S1;
		S1: next_state = (ncnt==0)?(S1):(S2);
		S2: next_state = (ncnt==0)?(S2):(WN);
		WN: next_state = (ncnt==0)?(WN):((cnt>0) ? (S1) : (Last));
		//Weight
		Mnum: next_state = MS1;
		MS1: next_state = (ncnt==0)?(MS1):(MS2);
		MS2: next_state = (ncnt==0)?(MS2):(ReadW);
		ReadW: next_state = (L!=COL-1 || line!=ROW-1)?(ReadW):((cnt>0)?(MS1):(Last));
		//Image
		ReadImage: next_state = (cnt>0) ? (ReadImage) : (Last);
		
		Last: next_state = (RxData==8'hFF) ? (Waiting) : (Error);
		default: next_state = Waiting;
		endcase
	end

	//State Transition
	always @(posedge clk_11MHz) begin
		if(~resetn) begin state <= Waiting; end
		else if(valid) begin state <= next_state; end
		else begin state <= state; end
	end
	
	//State LED
	reg [2:0] instage;
	always @(posedge clk_11MHz) begin
		if(~resetn) begin instage<=0; StateLED <= 0; end
		else if(valid) begin
			case(state)
			FType: begin
				instage<=(next_state==Nnum)?(1):((next_state==Mnum)?(2):((next_state==ReadImage)?(3):(0)));
				StateLED[3]<=0;
			end
			Nnum: StateLED[0]<=1;
			Mnum: StateLED[1]<=1;
			ReadImage: StateLED[2]<=1;
			Last: begin
					StateLED[3]<=(next_state!=Error && instage==3)?(1):(StateLED[3]);
					StateLED[2]<=(next_state!=Error && instage==3)?(0):(StateLED[2]);
					StateLED[1]<=(next_state!=Error && instage==2)?(0):(StateLED[1]);
					StateLED[0]<=(next_state!=Error && instage==1)?(0):(StateLED[0]);
			end
			endcase
		end
	end

endmodule
