`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    15:09:29 11/11/2020 
// Design Name: 
// Module Name:    ddp_sram 
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
module ddp_bram #(parameter DWIDTH=0, parameter LEN=0, parameter LOG_LEN=0) (clk, ena, enb, wea, web, addra, addrb, dla, dlb, doa, dob);	//!!!!!!!a: inpout, b: output!!!!
	input clk;
	input ena;
	input enb;
	input wea;
	input web;
	input [LOG_LEN-1:0]	addra;
	input [LOG_LEN-1:0]	addrb;
	input [DWIDTH-1:0]	dla;
	input [DWIDTH-1:0]	dlb;
	output [DWIDTH-1:0]	doa;
	output [DWIDTH-1:0]	dob;
	//wire dlap;
	//wire [DWIDTH:0] dla_tmp;
	
	(*ram_style="block" *)
	reg [DWIDTH-1:0]	ram[LEN-1:0];
	reg [DWIDTH-1:0]	doa;
	reg [DWIDTH-1:0]	dob;
	
	//assign dlap = ^(dla);
	//assign dob = dob_tmp[DWIDTH:1];
	//assign dla_tmp[DWIDTH-1:0] = dla;
	//assign dla_tmp[DWIDTH] = dlap;
	
	always @(negedge clk) begin
		if(ena) begin
			if(wea) ram[addra] <= dla;
			doa <= ram[addra];
		end
	end
	always @(negedge clk) begin
		if(enb) begin
			if(web) ram[addrb] <= dlb;
			dob <= ram[addrb];
		end
	end

endmodule
