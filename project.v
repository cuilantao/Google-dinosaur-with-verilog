// Part 2 skeleton

module Project
	(
		CLOCK_50,						//	On Board 50 MHz
		// Your inputs and outputs here
        KEY,
        SW,
		// The ports below are for the VGA output.  Do not change.
		VGA_CLK,   						//	VGA Clock
		VGA_HS,							//	VGA H_SYNC
		VGA_VS,							//	VGA V_SYNC
		VGA_BLANK_N,						//	VGA BLANK
		VGA_SYNC_N,						//	VGA SYNC
		VGA_R,   						//	VGA Red[9:0]
		VGA_G,	 						//	VGA Green[9:0]
		VGA_B   						//	VGA Blue[9:0]
	);

	input			CLOCK_50;				//	50 MHz
	input   [9:0]   SW;
	input   [3:0]   KEY;

	// Declare your inputs and outputs here
	// Do not change the following outputs
	output			VGA_CLK;   				//	VGA Clock
	output			VGA_HS;					//	VGA H_SYNC
	output			VGA_VS;					//	VGA V_SYNC
	output			VGA_BLANK_N;				//	VGA BLANK
	output			VGA_SYNC_N;				//	VGA SYNC
	output	[9:0]	VGA_R;   				//	VGA Red[9:0]
	output	[9:0]	VGA_G;	 				//	VGA Green[9:0]
	output	[9:0]	VGA_B;   				//	VGA Blue[9:0]
	
	wire resetn;
	assign resetn = KEY[0];
	
	// Create the colour, x, y and writeEn wires that are inputs to the controller.
	wire [2:0] colour;
	wire [7:0] x;
	wire [6:0] y;
	wire ldx;
	wire ldy;
	wire writeEn;
	wire finish_dino;
	wire draw;
	wire count_enable;
	wire erase;
	wire is_jump;
	wire change;
	wire finish_erase;
	wire frame_updated;
	wire frame_counter;

	// Create an Instance of a VGA controller - there can be only one!
	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.
	vga_adapter VGA(
			.resetn(resetn),
			.clock(CLOCK_50),
			.colour(colour),
			.x(x),
			.y(y),
			.plot(writeEn),
			/* Signals for the DAC to drive the monitor. */
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
		defparam VGA.RESOLUTION = "160x120";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
		defparam VGA.BACKGROUND_IMAGE = "black.mif";
			
	// Put your code here. Your code should produce signals x,y,colour and writeEn/plot
	// for the VGA controller, in addition to any other functionality your design may require.
	
	datapath d0(
					.clk(CLOCK_50),
					.ld_x(ldx),
					.ld_y(ldy),
					.reset_n(resetn),
					.is_erase(erase),
					.is_change(change),
					.x_out(x),
					.y_out(y),
					.jump(KEY[2]),
					.color_out(colour),
					.is_jump(is_jump),
					.finish_dino(finish_dino),
					.finish_erase(finish_erase),
					.draw(draw),
					.count_enable(count_enable),
					.frame_counter(frame_counter),
					.frame_updated(frame_updated));

    control c0(
				.clk(CLOCK_50),
				.reset_n(resetn),
				.go(KEY[1]),
				.finish_erase(finish_erase),
				.ld_x(ldx),
				.ld_y(ldy),
				.writeEn(writeEn),
				.draw(draw),
				.finish_dino(finish_dino),
				.count_enable(count_enable),
				.is_erase(erase),
				.is_change(change),
				.is_jump(is_jump),
				.frame_counter(frame_counter),
				.frame_updated(frame_updated));
    
endmodule


module datapath
	(
		input clk,
		input ld_x, ld_y,
		input draw,
		input count_enable,
		input frame_counter,
		input reset_n,
		input jump,
		input is_erase,
		input is_change,
		output [7:0] x_out,
		output [6:0] y_out,
		output [2:0] color_out,
		output finish_dino,
		output reg finish_erase,
		output reg frame_updated,
		output reg is_jump
	);
	reg [4:0] count;
	wire enable_frame;
	reg [2:0] frame_count;
	reg [27:0] frame_counter_value;
	reg [2:0] count_x, count_y;
	reg [7:0] x;
	reg [6:0] y;
	reg [7:0] x_orig;
	reg [6:0] y_orig;
	reg [2:0] color;
	reg dir;
	//frame counter
	always @(posedge clk) begin
		if (!reset_n)
			frame_counter_value <= 28'd0;
		else if(frame_counter_value == 28'd1000000)
			frame_counter_value <= 28'd0;
		else if(frame_counter == 1'b1)
			frame_counter_value <= frame_counter_value + 1'b1;
	end
	
	assign finish_dino = (frame_counter_value == 28'd1000000) ? 1 : 0;
	
	//detect whether is jumping
		always @(posedge clk) begin
		if (!reset_n)
			is_jump <= 1'b0;
		else if (!jump)
			is_jump <= 1'b1;
	end
	
	//drawing dino
	always @(posedge clk) begin
		if (!reset_n) begin
			finish_erase <= 1'b0;
			count <= 5'd0;
		end
		else begin
		if (finish_erase)begin
			count <= 5'd0;
			finish_erase <= 1'b0;
		end
		if (count_enable)
			count <= count + 1;
		if (ld_x)
				x_orig <= {1'b0, 7'b0001111};
		if (ld_y)
				y_orig <= 7'b1100100;
		if (y_orig == 7'b1101010)
				dir <= 1'b0;
		else if (y_orig == 7'b0111100)
				dir <= 1'b1;
		if (is_change)
			if (!dir)
				y_orig <= y_orig - 1;
			else
				y_orig <= y_orig + 1;
		if (draw || is_erase) begin
			if (draw)
				color <= 3'b111;
			else if(is_erase)
				color <= 3'b000;
			if (count == 0) begin
				x <= x_orig;
				y <= y_orig;
			end
			if (count == 1) begin
				x <= x_orig-1'b1;
				y <= y_orig;
			end
			if (count == 2) begin
				x <= x_orig-2'd2;
				y <= y_orig;
			end
			if (count == 3) begin
				x <= x_orig+1'b1;
				y <= y_orig;
			end
			if (count == 4) begin
				x <= x_orig+2'd2;
				y <= y_orig;
			end
			if (count == 5) begin
				x <= x_orig;
				y <= y_orig+1'b1;
			end
			if (count == 6) begin
				x <= x_orig;
				y <= y_orig + 2'd2;
			end
			if (count == 7) begin
				x <= x_orig;
				y <= y_orig - 1'b1;
			end
			if (count == 8) begin
				x <= x_orig;
				y <= y_orig - 2'd2;
			end
			if (count == 9) begin
				x <= x_orig - 1'b1;
				y <= y_orig + 2'd3;
			end
			if (count == 10) begin
				x <= x_orig + 1'b1;
				y <= y_orig + 2'd3;
			end
			if (count == 11) begin
				x <= x_orig + 2'd2;
				y <= y_orig + 3'd4;
			end
			if (count == 12) begin
				x <= x_orig - 2'd2;
				y <= y_orig + 3'd4;
			end
			if (count == 13) begin
				x <= x_orig + 2'd3;
				y <= y_orig + 3'd5;
			end
			if (count == 14) begin
				x <= x_orig - 2'd3;
				y <= y_orig + 3'd5;
			end
			if (count == 15) begin
				x <= x_orig - 2'd2;
				y <= y_orig - 3'd6;
			end
			if (count == 16) begin
				x <= x_orig - 2'd2;
				y <= y_orig - 3'd5;
			end
			if (count == 17) begin
				x <= x_orig - 2'd2;
				y <= y_orig - 3'd4;
			end
			if (count == 18) begin
				x <= x_orig - 2'd2;
				y <= y_orig - 3'd3;
			end
			if (count == 19) begin
				x <= x_orig - 1'b1;
				y <= y_orig - 3'd6;
			end
			if (count == 20) begin
				x <= x_orig - 1'b1;
				y <= y_orig - 3'd5;

			end
			if (count == 21) begin
				x <= x_orig - 1'b1;
				y <= y_orig - 3'd4;
			end
			if (count == 22) begin
				x <= x_orig - 1'b1;
				y <= y_orig - 3'd3;
			end
			if (count == 23) begin
				x <= x_orig;
				y <= y_orig - 3'd6;
			end
			if (count == 24) begin
				x <= x_orig;
				y <= y_orig - 3'd5;
			end
			if (count == 25) begin
				x <= x_orig;
				y <= y_orig - 3'd4;
			end
			if (count == 26) begin
				x <= x_orig;
				y <= y_orig - 3'd3;
			end
			if (count == 27) begin
				x <= x_orig + 1'b1;
				y <= y_orig - 3'd6;
			end
			if (count == 28) begin
				x <= x_orig + 1'b1;
				y <= y_orig - 3'd5;
			end
			if (count == 29) begin
				x <= x_orig + 1'b1;
				y <= y_orig - 3'd4;
			end
			if (count == 30) begin
				x <= x_orig + 1'b1;
				y <= y_orig - 3'd3;
				if(is_erase) begin
					finish_erase <= 1'b1;
				end
			end
		end
		end
	end
	
	assign x_out = x; 
	assign y_out = y;
   assign color_out = color;
endmodule

module control
	(
		input clk,
		input reset_n,
		input go,
		input finish_dino,
		input is_jump,
		input frame_updated,
		input finish_erase,
		output reg ld_x, ld_y, writeEn, draw, count_enable, is_erase, is_change, frame_counter
	);
	
	reg [2:0] current_state, next_state;
	
	localparam 	start = 3'd0,
					start_wait = 3'd1,
					draw_dino = 3'd2,
					wait_jump = 3'd3,
					erase = 3'd4,
					change_x_y = 3'd5;
							
	always @(*) begin
		case (current_state)
			start: next_state = go ? start : start_wait;
			start_wait: next_state = go ? draw_dino : start_wait;
			draw_dino: next_state = finish_dino ? wait_jump : draw_dino;
			wait_jump: next_state = is_jump  ? erase: wait_jump;
			erase : next_state = finish_erase ? change_x_y : erase;
			change_x_y : next_state = draw_dino;
			default : next_state = start;
		endcase
	end

	always @(*) begin
		ld_x = 1'b0;
		ld_y = 1'b0;
		writeEn = 1'b0;
		draw = 1'b0;
		count_enable = 1'b0;
		is_erase = 1'b0;
		is_change = 1'b0;
		frame_counter = 1'b0;
		case (current_state)
			start: begin
				ld_x = 1'b1;
				ld_y = 1'b1;
			end
			start_wait: begin
				ld_x = 1'b1;
				ld_y = 1'b1;
			end
			draw_dino: begin
				writeEn = 1'b1;
				draw = 1'b1;
				count_enable = 1'b1;
				frame_counter = 1'b1;
			end
			erase: begin
				writeEn = 1'b1;
				is_erase = 1'b1;
				count_enable = 1'b1;
			end
				change_x_y: begin
				is_change = 1'b1;
			end
		endcase
	end
	
	always @(posedge clk) begin
		if (!reset_n)
			current_state <= start;
		else
			current_state <= next_state;
	end

endmodule


