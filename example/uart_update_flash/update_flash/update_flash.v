//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Bemjamin Smith
// 
// Create Date:    08:34 06/07/2023
// Design Name: 
// Module Name:    update_flash
// Project Name: 
// Target Devices: W25Q128BV
// Tool versions: 
// Description:    update the program in the flash
//
// Dependencies: 
//
// Revision: 
// Revision 1.00 - File Completed  10:26 06/07/2023
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////

module update_flash (
	input	wire								sys_clk,
	input	wire								sys_rst_n,
	output	wire								flash_cs_n_o,
	output	wire								flash_sck_o,
	output	wire								flash_mosi_o,
	input	wire								flash_miso_i,
	
	input	wire								flash_erase_en_i,
	input	wire	[23:0]						flash_prog_size_i,					// size of the program
	output	wire								flash_erase_busy_o,
	input	wire								flash_wr_en_i,						// wr_en && wr_ready, going to write 256 bytes data
	output	wire								flash_wr_ready_o,					// after erase, the flash is ready to write data
	output	wire								flash_writing_o,					// after erase and before all data write done, it's high
	input	wire	[7:0]						flash_wr_data_i,
	output	wire								flash_wr_req_o,						// request for next byte data to write
	input	wire								flash_wr_done_i						// manually early termination
);

	parameter		BASEADDR					= 24'h0;
	localparam		IDLE						= 'h1,
					ERASE						= 'h2,
					WRITE						= 'h4;
	
	reg		[2:0]								state;
	reg		[23:0]								prog_byte;
	reg											flash_erase_64k;
	reg		[23:0]								flash_addr;
	wire										flash_busy;
	wire										flash_wr_en;
	wire										flash_erase_done;

flash_driver									u1_flash_driver (
	.sys_clk									( sys_clk			),
	.sys_rst_n									( sys_rst_n			),
	.flash_cs_n_o								( flash_cs_n_o		),
	.flash_sck_o								( flash_sck_o		),
	.flash_mosi_o								( flash_mosi_o		),
	.flash_miso_i								( flash_miso_i		),
	.flash_erase_4k_i							( 1'b0				),
	.flash_erase_32k_i							( 1'b0				),
	.flash_erase_64k_i							( flash_erase_64k	),
	.flash_erase_all_i							( 1'b0				),
	.flash_addr_i								( flash_addr		),
	.flash_busy_o								( flash_busy		),
	.flash_rd_en_i								( 1'b0				),
	.flash_rd_data_o							( 					),
	.flash_rd_data_valid_o						( 					),
	.flash_wr_en_i								( flash_wr_en		),
	.flash_wr_req_o								( flash_wr_req_o	),
	.flash_wr_data_i							( flash_wr_data_i	),
	.flash_erase_done_o							( flash_erase_done	),
	.flash_wr_done_o							( 					),
	.flash_rd_done_o							( 					 )
);

assign	flash_wr_en			=	flash_wr_en_i && flash_wr_ready_o;
assign	flash_erase_busy_o	=	( state == ERASE );
assign	flash_wr_ready_o	=	( state == WRITE ) && !flash_busy;
assign	flash_writing_o		=	( state == WRITE );

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		state <= IDLE;
	end else case ( state )
		IDLE: begin
			if ( flash_erase_en_i ) begin
				state <= ERASE;
			end else begin
				state <= IDLE;
			end
		end
		ERASE: begin
			if ( flash_addr - BASEADDR >= prog_byte && flash_erase_done ) begin
				state <= WRITE;
			end else begin
				state <= ERASE;
			end
		end
		WRITE: begin
			if ( prog_byte == 'd0 || flash_wr_done_i ) begin
				state <= IDLE;
			end else begin
				state <= WRITE;
			end
		end
		default: state <= IDLE;
	endcase
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		prog_byte <= 24'd0;
	end else if ( state == IDLE ) begin
		prog_byte <= flash_prog_size_i;
	end else if ( state == WRITE ) begin
		if ( flash_wr_req_o ) begin
			prog_byte <= prog_byte - 24'd1;
		end else begin
			prog_byte <= prog_byte;
		end
	end else begin
		prog_byte <= prog_byte;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		flash_erase_64k <= 1'b0;
	end else if ( state == ERASE && flash_addr - BASEADDR < prog_byte ) begin
		flash_erase_64k <= 1'b1;
	end else begin
		flash_erase_64k <= 1'b0;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		flash_addr <= BASEADDR;
	end else if ( state == ERASE ) begin
		if ( flash_erase_64k && !flash_busy ) begin
			flash_addr <= flash_addr + 24'h1_0000;
		end else if ( flash_addr - BASEADDR >= prog_byte && flash_erase_done ) begin
			flash_addr <= BASEADDR;
		end else begin
			flash_addr <= flash_addr;
		end
	end else if ( state == WRITE ) begin
		if ( flash_wr_en ) begin
			flash_addr <= flash_addr + 24'd256;
		end else begin
			flash_addr <= flash_addr;
		end
	end else begin
		flash_addr <= BASEADDR;
	end
end

endmodule