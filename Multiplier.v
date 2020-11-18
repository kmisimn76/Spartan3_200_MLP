`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    17:28:43 11/11/2020 
// Design Name: 
// Module Name:    Multiplier 
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
module Multiplier #(parameter	Waiting=3'h0,
					Multiplying=3'h1,
					Accumulating=3'h2,
					Activating=3'h3,
					MultWithoutAcc=3'h4)
	(
	input clk,
	input resetn,
	input [2:0] step,
	input [7:0] shift,
	input signed [7:0] A,
	input signed [7:0] B0,
	input signed [7:0] B1,
	input signed [7:0] B2,
	input signed [7:0] B3,
	input signed [7:0] B4,
	input signed [7:0] B5,
	input signed [7:0] B6,
	input signed [7:0] B7,
	output [7:0] Y0,
	output [7:0] Y1,
	output [7:0] Y2,
	output [7:0] Y3,
	output [7:0] Y4,
	output [7:0] Y5,
	output [7:0] Y6,
	output [7:0] Y7,
	output reg overflow
	);
	
	reg [2:0] state;
	
	wire signed [17:0] extA;
	wire signed [17:0] extB[7:0];
	wire signed [35:0] AB[7:0];
	reg signed [27:0] AB_Dly[7:0];
	reg signed [27:0] AB_acc[7:0];
	reg signed [27:0] extY[7:0];
	
	assign extA={ A[7:0], 10'b0 };
	assign extB[0]={ B0, 10'b0 };
	assign extB[1]={ B1, 10'b0 };
	assign extB[2]={ B2, 10'b0 };
	assign extB[3]={ B3, 10'b0 };
	assign extB[4]={ B4, 10'b0 };
	assign extB[5]={ B5, 10'b0 };
	assign extB[6]={ B6, 10'b0 };
	assign extB[7]={ B7, 10'b0 };
	
	/*MULT18X18 MULT18X18_inst0 (.P(AB[0]), .A(extA), .B(extB[0]));
	MULT18X18 MULT18X18_inst1 (.P(AB[1]), .A(extA), .B(extB[1]));
	MULT18X18 MULT18X18_inst2 (.P(AB[2]), .A(extA), .B(extB[2]));
	MULT18X18 MULT18X18_inst3 (.P(AB[3]), .A(extA), .B(extB[3]));
	MULT18X18 MULT18X18_inst4 (.P(AB[4]), .A(extA), .B(extB[4]));
	MULT18X18 MULT18X18_inst5 (.P(AB[5]), .A(extA), .B(extB[5]));
	MULT18X18 MULT18X18_inst6 (.P(AB[6]), .A(extA), .B(extB[6]));
	MULT18X18 MULT18X18_inst7 (.P(AB[7]), .A(extA), .B(extB[7]));*/
	
	
	assign AB[0] = extA  * extB[0];
	assign AB[1] = extA  * extB[1];
	assign AB[2] = extA  * extB[2];
	assign AB[3] = extA  * extB[3];
	assign AB[4] = extA  * extB[4];
	
	reg now_ov[7:0];
	always @(posedge clk) begin
		if(~resetn) begin	overflow <= 0; end
		else begin overflow <= overflow
			| (now_ov[0] | now_ov[1] | now_ov[2] | now_ov[3] | now_ov[4] | now_ov[5] | now_ov[6] | now_ov[7]); end
	end
	
	always @(posedge clk) begin
		state <= step;
	end
	integer i;
	always @(posedge clk) begin
	for(i=0; i<8; i=i+1) begin //Macro
		if(~resetn) begin
			AB_Dly[i] <= 0;
			AB_acc[i] <= 0;
			extY[i] <= 0;
		end
		else begin
			if(state==Waiting) begin
				AB_Dly[i] <= AB_Dly[i];
				AB_acc[i] <= AB_acc[i];
			end
			else if(state==Multiplying) begin //multiplication
				AB_Dly[i] <= { {12{AB[i][35]}}, AB[i][35:20]};
			end
			else if(state==MultWithoutAcc) begin //reset and multiplication
				AB_acc[i] <= 0;
				AB_Dly[i] <= { {12{AB[i][35]}}, AB[i][35:20]};
			end
			else if(state==Accumulating) begin //accumulation
				AB_acc[i] <= AB_acc[i] + AB_Dly[i];
				now_ov[i] <= (AB_acc[i][26] ^ AB_acc[i][27]);
			end
			else if(state==Activating) begin //relu + shift
				extY[i] <= (AB_acc[i][27]) ? (0): ( AB_acc[i]>>shift );
			end
			else begin
				AB_Dly[i] <= 0;
				AB_acc[i] <= 0;
			end
		end
	end
	end

	assign Y0 = (extY[0] > 28'sd127)?(8'sd127):(extY[0][7:0]); // Saturation
	assign Y1 = (extY[1] > 28'sd127)?(8'sd127):(extY[1][7:0]);
	assign Y2 = (extY[2] > 28'sd127)?(8'sd127):(extY[2][7:0]);
	assign Y3 = (extY[3] > 28'sd127)?(8'sd127):(extY[3][7:0]);
	assign Y4 = (extY[4] > 28'sd127)?(8'sd127):(extY[4][7:0]);
	assign Y5 = (extY[5] > 28'sd127)?(8'sd127):(extY[5][7:0]);
	assign Y6 = (extY[6] > 28'sd127)?(8'sd127):(extY[6][7:0]);
	assign Y7 = (extY[7] > 28'sd127)?(8'sd127):(extY[7][7:0]);
endmodule
