`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    11:13:11 11/13/2020 
// Design Name: 
// Module Name:    ModelMemoryUnit 
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
module ModelMemoryUnit
	#(parameter MODEL_ADDR_WIDTH=10, MODEL_DATA_WIDTH=18, MODEL_LOC_SIZE=1024,
					WEIGHT_ADDR_WIDTH=11, WEIGHT_DATA_WIDTH=9, WEIGHT_LOC_SIZE=2048,
					TENSOR_ADDR_WIDTH=9, TENSOR_DATA_WIDTH=36, TENSOR_LOC_SIZE=512)
	(
	input clk,
	input mm_ena, mm_enb,
	input mm_wea,
	input [MODEL_ADDR_WIDTH-1:0] mm_addra,
	input [MODEL_ADDR_WIDTH-1:0] mm_addrb,
	input [MODEL_DATA_WIDTH-1:0] mm_dla,
	output [MODEL_DATA_WIDTH-1:0] mm_doa,
	output [MODEL_DATA_WIDTH-1:0] mm_dob
    );

	sdp_bram #(MODEL_DATA_WIDTH, MODEL_LOC_SIZE, MODEL_ADDR_WIDTH) model_memory(clk, mm_ena, mm_enb, mm_wea, mm_addra, mm_addrb, mm_dla, mm_doa, mm_dob);

endmodule
