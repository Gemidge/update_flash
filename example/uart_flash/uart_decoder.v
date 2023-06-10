//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Benjamin Smith
// 
// Create Date:    13:24 06/01/2023 
// Design Name: 
// Module Name:    uart_decoder 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: decode the self-defined command to control the flash
//              command head: $flash$ ('h36_66_6C_61_73_68_36)
//              chip erase: 'h00
//              64 KB block erase: 'h01 + 3 bytes address ( MSB first )
//              32 KB block erase: 'h02 + 3 bytes address
//              sector erase: 'h03 + 3 bytes address
//              page program: 'h10 + 3 bytes address + 256 bytes data
//              read flash: 'h20 + 3 bytes address
//              Answer erase and write after that it's completed, command head and order.
//              Answer error command order with "command head + 'hFF".
//              During command operation, input signals are ignored.
// Dependencies: 
//
// Revision: 
// Revision 1.00 - File Completed 10:27 06/02/2023
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////

module uart_decoder(
	input	wire								sys_clk,
	input	wire								sys_rst_n,
	
	input	wire								uart_rx_valid_i,
	input	wire	[7:0]						uart_rxdata_i,
	output	reg									uart_tx_en_o,
	output	wire	[7:0]						uart_txdata_o,
	input	wire								uart_tx_busy_i,
	
	output	reg									flash_erase_4k_o,
	output	reg									flash_erase_32k_o,
	output	reg									flash_erase_64k_o,
	output	reg									flash_erase_all_o,
	output	reg		[23:0]						flash_addr_o,
	input	wire								flash_busy_i,
	output	reg									flash_rd_en_o,
	input	wire	[7:0]						flash_rd_data_i,
	input	wire								flash_rd_data_valid_i,
	output	reg									flash_wr_en_o,
	input	wire								flash_wr_req_i,
	output	wire 	[7:0]						flash_wr_data_o,
	input	wire								flash_erase_done_i,
	input	wire								flash_wr_done_i,
	input	wire								flash_rd_done_i
);

	parameter		CMD_HEAD					= 56'h36_66_6C_61_73_68_36;
	parameter		IDLE						= 7'h01,
					CMD							= 7'h02,
					ADDR						= 7'h04,
					WRITE						= 7'h08,
					READ						= 7'h10,
					BUSY						= 7'h20,
					ANSWER						= 7'h40;
	reg		[6:0]								state;

	reg		[55:0]								cmd_head;
	reg		[1:0]								cnt_addr;
	reg		[5:0]								cmd;
	wire										erase_all;
	wire										erase_64k;
	wire										erase_32k;
	wire										erase_4k;
	wire										wr_en;
	wire										rd_en;
	
	reg		[8:0]								cnt_wr;
	reg		[8:0]								cnt_rd;
	wire										fifo_read_empty;
	reg											cmd_done;
	reg											flash_rd_done;
	wire	[7:0]								flash_data;
	reg		[7:0]								answer_data;
	reg		[3:0]								cnt_answer;

assign	erase_all	=	cmd[0];
assign	erase_64k	=	cmd[1];
assign	erase_32k	=	cmd[2];
assign	erase_4k	=	cmd[3];
assign	wr_en		=	cmd[4];
assign	rd_en		=	cmd[5];

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		state <= IDLE;
	end else case ( state )
		IDLE: begin
			if ( cmd_head == CMD_HEAD ) begin
				state <= CMD;
			end else begin
				state <= IDLE;
			end
		end
		CMD: begin
			if ( uart_rx_valid_i ) begin
				if ( uart_rxdata_i == 'h00 ) begin
					state <= BUSY;
				end else if ( uart_rxdata_i <= 'h03 || uart_rxdata_i == 'h10 || uart_rxdata_i == 'h20 ) begin
					state <= ADDR;
				end else begin
					state <= IDLE;
				end
			end else begin
				state <= CMD;
			end
		end
		ADDR: begin
			if ( cnt_addr >= 'd3 ) begin
				if ( erase_64k || erase_32k || erase_4k ) begin
					state <= BUSY;
				end else if ( wr_en ) begin
					state <= WRITE;
				end else begin
					state <= READ;
				end
			end else begin
				state <= ADDR;
			end
		end
		WRITE: begin
			if ( cnt_wr >= 'd256 ) begin
				state <= BUSY;
			end else begin
				state <= WRITE;
			end
		end
		READ: begin
			if ( flash_rd_done && cnt_rd == 'd0 && !uart_tx_busy_i ) begin
				state <= IDLE;
			end else begin
				state <= READ;
			end
		end
		BUSY: begin
			if ( flash_erase_done_i || flash_wr_done_i ) begin
				state <= ANSWER;
			end else begin
				state <= BUSY;
			end
		end
		ANSWER: begin
			if ( cnt_answer >= 'd8 && !uart_tx_busy_i ) begin
				state <= IDLE;
			end else begin
				state <= ANSWER;
			end
		end
		default: state <= IDLE;
	endcase
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		cmd_head <= 56'h0;
	end else if ( state == IDLE ) begin
		if ( uart_rx_valid_i ) begin
			cmd_head <= { cmd_head[47:0], uart_rxdata_i };
		end else begin
			cmd_head <= cmd_head;
		end
	end else begin
		cmd_head <= 56'h0;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		flash_addr_o <= 24'h0;
	end else if ( state == ADDR && uart_rx_valid_i ) begin
		flash_addr_o <= { flash_addr_o[15:0], uart_rxdata_i };
	end else begin
		flash_addr_o <= flash_addr_o;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		cnt_addr <= 2'd0;
	end else if ( state == ADDR ) begin
		if ( uart_rx_valid_i ) begin
			cnt_addr <= cnt_addr + 2'd1;
		end else begin
			cnt_addr <= cnt_addr;
		end
	end else begin
		cnt_addr <= 2'd0;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		cmd <= 6'h00;
	end else if ( state == IDLE ) begin
		cmd <= 6'h00;
	end else if ( state == CMD && uart_rx_valid_i ) begin
		case ( uart_rxdata_i )
			'h00: cmd <= 6'h01;
			'h01: cmd <= 6'h02;
			'h02: cmd <= 6'h04;
			'h03: cmd <= 6'h08;
			'h10: cmd <= 6'h10;
			'h20: cmd <= 6'h20;
			default: cmd <= 6'h00;
		endcase
	end else begin
		cmd <= cmd;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		cnt_wr <= 9'd0;
	end else if ( state == WRITE && uart_rx_valid_i ) begin
		cnt_wr <= cnt_wr + 9'd1;
	end else if ( state == BUSY && flash_wr_req_i ) begin
		cnt_wr <= cnt_wr - 9'd1;
	end else if ( state == WRITE || state == BUSY ) begin
		cnt_wr <= cnt_wr;
	end else begin
		cnt_wr <= 9'd0;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		cnt_rd <= 9'd0;
	end else if ( state == READ ) begin
		if ( flash_rd_data_valid_i ) begin
			cnt_rd <= cnt_rd + 9'd1;
		end else if ( uart_tx_en_o && !uart_tx_busy_i ) begin
			cnt_rd <= cnt_rd - 9'd1;
		end else begin
			cnt_rd <= cnt_rd;
		end
	end else begin
		cnt_rd <= 9'd0;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		cmd_done <= 1'b0;
	end else if ( state == READ ) begin
		if ( flash_rd_en_o && !flash_busy_i ) begin
			cmd_done <= 1'b1;
		end else begin
			cmd_done <= cmd_done;
		end
	end else if ( state == BUSY ) begin
		if ( ( flash_erase_all_o || flash_erase_64k_o || flash_erase_32k_o || flash_erase_4k_o || flash_wr_en_o ) && !flash_busy_i ) begin
			cmd_done <= 1'b1;
		end else begin
			cmd_done <= cmd_done;
		end
	end else begin
		cmd_done <= 1'b0;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		flash_rd_done <= 1'b0;
	end else if ( state == READ ) begin
		if ( flash_rd_done_i ) begin
			flash_rd_done <= 1'b1;
		end else begin
			flash_rd_done <= flash_rd_done;
		end
	end else begin
		flash_rd_done <= 1'b0;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		flash_rd_en_o <= 1'b0;
	end else if ( state == READ ) begin
		flash_rd_en_o <= ~cmd_done;
	end else begin
		flash_rd_en_o <= 1'b0;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		flash_erase_all_o <= 1'b0;
		flash_erase_64k_o <= 1'b0;
		flash_erase_32k_o <= 1'b0;
		flash_erase_4k_o <= 1'b0;
		flash_wr_en_o <= 1'b0;
	end else begin
		flash_erase_all_o <= ( state == BUSY ) && ( !cmd_done ) && ( erase_all );
		flash_erase_64k_o <= ( state == BUSY ) && ( !cmd_done ) && ( erase_64k );
		flash_erase_32k_o <= ( state == BUSY ) && ( !cmd_done ) && ( erase_32k );
		flash_erase_4k_o <= ( state == BUSY ) && ( !cmd_done ) && ( erase_4k );
		flash_wr_en_o <= ( state == BUSY ) && ( !cmd_done ) && ( wr_en );
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		cnt_answer <= 4'd0;
	end else if ( state == ANSWER ) begin
		if ( uart_tx_en_o && !uart_tx_busy_i ) begin
			cnt_answer <= cnt_answer + 4'd1;
		end else begin
			cnt_answer <= cnt_answer;
		end
	end else begin
		cnt_answer <= 4'd0;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		uart_tx_en_o <= 1'b0;
	end else if ( state == READ ) begin
		uart_tx_en_o <= !fifo_read_empty;
	end else if ( state == ANSWER ) begin
		uart_tx_en_o <= ( cnt_answer < 'd8 );
	end else begin
		uart_tx_en_o <= 1'b0;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		answer_data <= 8'h0;
	end else if ( state == ANSWER ) begin
		case ( cnt_answer )
			'd0: answer_data <= 8'h36;
			'd1: answer_data <= 8'h66;
			'd2: answer_data <= 8'h6C;
			'd3: answer_data <= 8'h61;
			'd4: answer_data <= 8'h73;
			'd5: answer_data <= 8'h68;
			'd6: answer_data <= 8'h36;
			'd7: begin
				if ( erase_all ) answer_data <= 8'h00;
				else if ( erase_64k ) answer_data <= 8'h01;
				else if ( erase_32k ) answer_data <= 8'h02;
				else if ( erase_4k ) answer_data <= 8'h03;
				else if ( wr_en ) answer_data <= 8'h10;
				else answer_data <= 8'hFF;
			end
			default: answer_data <= 8'h0;
		endcase
	end else begin
		answer_data <= 8'h0;
	end
end

assign	uart_txdata_o	=	( state == READ ) ? flash_data : answer_data;

fifo_8x256										fifo_write (
	.clk										( sys_clk		),
	.rst										( ~sys_rst_n	),
	.din										( uart_rxdata_i	),
	.wr_en										( state == WRITE && uart_rx_valid_i ),
	.rd_en										( state == BUSY && flash_wr_req_i	),
	.dout										( flash_wr_data_o	),
	.full										(				),
	.empty										(				)
);

fifo_8x256_fwft									fifo_read (
	.clk										( sys_clk		),
	.rst										( ~sys_rst_n	),
	.din										( flash_rd_data_i	),
	.wr_en										( state == READ && flash_rd_data_valid_i ),
	.rd_en										( state ==READ && uart_tx_en_o && !uart_tx_busy_i ),
	.dout										( flash_data	),
	.full										( 				),
	.empty										( fifo_read_empty	)
);

endmodule
