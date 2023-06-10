//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Bemjamin Smith
// 
// Create Date:    08:44 06/10/2023
// Design Name: 
// Module Name:    uart_decoder
// Project Name: 
// Target Devices: W25Q128BV
// Tool versions: 
// Description:    update flash via uart, decode message from uart
//                 $update$ ( 'h24_75_70_64_61_74_65_24 ), 3 bytes file size ( MSB first, unit: byte ), bin file
//                 feedback: "erase done" ( 'h65_72_61_73_65_20_64_6F_6E_65 ), "write done" ( 'h77_72_69_74_65_20_64_6F_6E_65 )
// Dependencies: 
//
// Revision: 
// Revision 1.00 - File Completed 16:10 2023/06/10
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////

module uart_decoder (
	input	wire								sys_clk,
	input	wire								sys_rst_n,
	
	input	wire								uart_rx_valid_i,
	input	wire	[7:0]						uart_rxdata_i,
	output	reg									uart_tx_en_o,
	output	wire	[7:0]						uart_txdata_o,
	input	wire								uart_tx_busy_i,
	
	output	reg									flash_erase_en_o,
	output	reg		[23:0]						flash_prog_size_o,					// size of the program
	input	wire								flash_erase_busy_i,
	output	reg									flash_wr_en_o,						// wr_en && wr_ready, going to write 256 bytes data
	input	wire								flash_wr_ready_i,					// after erase, the flash is ready to write data
	input	wire								flash_writing_i,					// after erase and before all data write done, it's high
	output	wire	[7:0]						flash_wr_data_o,
	input	wire								flash_wr_req_i,						// request for next byte data to write
	output	wire								flash_wr_done_o						// manually early termination
);

	parameter		IDLE						= 4'h1,
					SIZE						= 4'h2,
					ERASE						= 4'h4,
					WRITE						= 4'h8;
	parameter		UPDATE_HEAD					= 64'h24_75_70_64_61_74_65_24;
	parameter		FDBK_ERASE					= 79'h65_72_61_73_65_20_64_6F_6E_65;
	parameter		FDBK_WRITE					= 79'h77_72_69_74_65_20_64_6F_6E_65;
	
	reg		[3:0]								state;
	reg		[63:0]								update_head;
	reg		[1:0]								cnt_size;
	reg		[3:0]								cnt_fdbk;
	reg		[79:0]								fdbk_data;
	reg		[8:0]								cnt_write;
	reg		[23:0]								cnt_bin;
	
assign		flash_wr_done_o		=	1'b0;
assign		uart_txdata_o		=	fdbk_data[79:72];
	
always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		state <= IDLE;
	end else case ( state )
		IDLE: begin
			if ( update_head == UPDATE_HEAD ) begin
				state <= SIZE;
			end else begin
				state <= IDLE;
			end
		end
		SIZE: begin
			if ( cnt_size >= 'd3 ) begin
				state <= ERASE;
			end else begin
				state <= SIZE;
			end
		end
		ERASE: begin
			if ( flash_writing_i ) begin
				state <= WRITE;
			end else begin
				state <= ERASE;
			end
		end
		WRITE: begin
			if ( !flash_writing_i ) begin
				state <= IDLE;
			end else begin
				state <= WRITE;
			end
		end
		default: begin
			state <= IDLE;
		end
	endcase
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		update_head <= 64'h0;
	end else if ( state == IDLE ) begin
		if ( uart_rx_valid_i ) begin
			update_head <= { update_head[55:0], uart_rxdata_i };
		end else begin 
			update_head <= update_head;
		end
	end else begin
		update_head <= 64'h0;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		cnt_size <= 2'd0;
	end else if ( state == SIZE ) begin
		if ( uart_rx_valid_i ) begin
			cnt_size <= cnt_size + 2'd1;
		end else begin
			cnt_size <= cnt_size;
		end
	end else begin
		cnt_size <= 2'd0;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		flash_erase_en_o <= 1'b0;
	end else if ( cnt_size >= 2'd3 ) begin
		flash_erase_en_o <= 1'b1;
	end else begin
		flash_erase_en_o <= 1'b0;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		flash_prog_size_o <= 24'd0;
	end else if ( state == SIZE && uart_rx_valid_i ) begin
		flash_prog_size_o <= { flash_prog_size_o[15:0], uart_rxdata_i };
	end else begin
		flash_prog_size_o <= flash_prog_size_o;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		uart_tx_en_o <= 1'b0;
	end else if ( state == ERASE && flash_writing_i ) begin
		uart_tx_en_o <= 1'b1;
	end else if ( state == WRITE && !flash_writing_i ) begin
		uart_tx_en_o <= 1'b1;
	end else if ( cnt_fdbk >= 'd10 ) begin
		uart_tx_en_o <= 1'b0;
	end else begin
		uart_tx_en_o <= uart_tx_en_o;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		fdbk_data <= 80'h0;
	end else if ( state == ERASE ) begin
		fdbk_data <= FDBK_ERASE;
	end else if ( state == WRITE && !flash_writing_i ) begin
		fdbk_data <= FDBK_WRITE;
	end else if ( uart_tx_en_o && !uart_tx_busy_i ) begin
		fdbk_data <= { fdbk_data[71:0], 8'h0 };
	end else begin
		fdbk_data <= fdbk_data;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		cnt_fdbk <= 4'd0;
	end else if ( uart_tx_en_o && !uart_tx_busy_i ) begin
		cnt_fdbk <= cnt_fdbk + 4'd1;
	end else if ( uart_tx_en_o ) begin
		cnt_fdbk <= cnt_fdbk;
	end else begin
		cnt_fdbk <= 4'd0;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		cnt_write <= 9'd0;
	end else if ( state == WRITE ) begin
		if ( uart_rx_valid_i && flash_wr_req_i ) begin
			cnt_write <= cnt_write;
		end else if ( uart_rx_valid_i ) begin
			cnt_write <= cnt_write + 'd1;
		end else if ( flash_wr_req_i && cnt_write > 'd0 ) begin
			cnt_write <= cnt_write - 'd1;
		end else begin
			cnt_write <= cnt_write;
		end
	end else begin
		cnt_write <= 9'd0;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		cnt_bin <= 24'd0;
	end else if ( state == WRITE ) begin
		if ( uart_rx_valid_i ) begin
			cnt_bin <= cnt_bin + 24'd1;
		end else begin
			cnt_bin <= cnt_bin;
		end
	end else begin
		cnt_bin <= 24'd0;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		flash_wr_en_o <= 1'b0;
	end else if ( cnt_write >= 'd256 || cnt_bin >= flash_prog_size_o ) begin
		flash_wr_en_o <= 1'b1;
	end else begin
		flash_wr_en_o <= 1'b0;
	end
end

fifo_8x256										u1_bin_fifo (
	.clk										( sys_clk			),
	.rst										( !sys_rst_n		),
	.din										( uart_rxdata_i		),
	.wr_en										( ( state == WRITE ) && uart_rx_valid_i ),
	.rd_en										( flash_wr_req_i	),
	.dout										( flash_wr_data_o	),
	.full										( 					),
	.empty										( 					)
);

endmodule