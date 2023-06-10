//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Bemjamin Smith
// 
// Create Date:    09:56 05/30/2023 
// Design Name: 
// Module Name:    flash_driver
// Project Name: 
// Target Devices: W25Q128BV
// Tool versions: 
// Description:    flash driver, including erase, read and write
//                 sector erase (4KB): command 06h enable WEL, command 20h erase,
//                     then command 05h read status register 1 continuously, unitl BUSY (bit0) == 0.
//                     cs fall, 06h, cs rise; cs fall, 20h, addr[23:0], cs rise; cs fall, 05h, continuous data, cs rise
//                 32 KB block erase: command 06h enable WEL, command 52h erase, then command 05h ...
//                 64 KB block erase: command 06h enable WEL, command D8h erase, then command 05h ...
//                 chip erase: command 06h enable WEL, command C7h or 60h erase, then command 05h ...
//                     cs fall, 06h, cs rise; cs fall, C7h or 60h, cs rise; cs fall, 05h, continuous data, cs rise
//                 read flash data using command 0Bh:
//                     0Bh, addr[23:0], 8 dummy clocks, continuous data: limit to 256 bytes ( a page ) manually
//                 page program: command 06h enable WEL, command 02h page program, then command 05h ...
//                     02h, addr[23:0], write 256 bytes data
//                 priority: chip erase > 64 KB block erase > 32 KB block erase > sector erase > page program > read flash
// Dependencies: 
//
// Revision: 1.02
// Revision 1.00 - read status
// Revision 1.01 - read data
// Revision 1.02 - erase, read and write. File Completed 13:09 06/01/2023
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////

module flash_driver (
	input	wire								sys_clk,
	input	wire								sys_rst_n,
	output	wire								flash_cs_n_o,
	output	wire								flash_sck_o,
	output	wire								flash_mosi_o,
	input	wire								flash_miso_i,
	
	input	wire								flash_erase_4k_i,
	input	wire								flash_erase_32k_i,
	input	wire								flash_erase_64k_i,					// when erase && !busy, erase the corresponding address and size of the flash
	input	wire								flash_erase_all_i,
	input	wire	[23:0]						flash_addr_i,
	output	wire								flash_busy_o,						// when it's high, ignore all inputs but wr_data
	input	wire								flash_rd_en_i,						// when rd_en && !busy, read 256 bytes data from the corresponding address
	output	wire	[7:0]						flash_rd_data_o,
	output	wire								flash_rd_data_valid_o,
	input	wire								flash_wr_en_i,						// when wr_en && !busy, page program 256 bytes data to the corresponding address
	output	reg									flash_wr_req_o,						// request a byte data to write, repeat 256 times after wr_en && !busy
	input	wire	[7:0]						flash_wr_data_i,
	output	reg									flash_erase_done_o,					// one clock signal, indicate the erase operation completed
	output	reg									flash_wr_done_o,					// one clock signal, indicate the page program operation completed
	output	reg									flash_rd_done_o						// one clock signal, indicate the fast read operation has done
);
	
	reg											spi_tx_en;
	reg		[7:0]								spi_tx_data;
	wire										spi_busy;
	wire										spi_rx_valid;
	wire	[7:0]								spi_rx_data;
	reg											spi_rd_en;

spi_master										u1_spi_master (
	.sys_clk									( sys_clk		),
	.sys_rst_n									( sys_rst_n		),
	.spi_cs_n_o									( flash_cs_n_o	),
	.spi_sck_o									( flash_sck_o	),
	.spi_mosi_o									( flash_mosi_o	),
	.spi_miso_i									( flash_miso_i	),
	.spi_tx_en_i								( spi_tx_en		),
	.spi_tx_data_i								( spi_tx_data	),
	.spi_busy_o									( spi_busy		),
	.spi_rx_valid_o								( spi_rx_valid	),
	.spi_rx_data_o								( spi_rx_data	),
	.spi_rd_en_i								( spi_rd_en		)
);

	localparam		IDLE						= 8'h01,
					CS_WAIT						= 8'h02,							// after each command, cs need to be high for a while
					WEL							= 8'h04,							// set the write enable latch bit
					ERASE						= 8'h08,							// erase command, including chip erase, block erase and sector erase
					ERASE_CHIP					= 8'h10,							// erase command, including chip erase, block erase and sector erase
					BUSY						= 8'h20,							// read status register 1
					PROGRAM						= 8'h40,							// command 02h page program
					READ						= 8'h80;							// command 0Bh fast read
	reg		[7:0]								state;
	reg		[7:0]								state_next;							// the next state after CS_WAIT, but not next clock
	
	reg											erase_4k;
	reg											erase_32k;
	reg											erase_64k;
	reg											erase_all;
	reg											rd_en;
	reg											wr_en;
	reg		[23:0]								flash_addr;
	
	reg											cnt_cmd1;							// count bytes when transferring WEL set, chip erase, read status, 1 byte
	reg		[2:0]								cnt_cs_high;						// delay counter when state == CS_WAIT
	reg		[2:0]								cnt_cmd4;							// count bytes when transferring program, read, sector erase, block erase command, 4 bytes
	reg											streg_valid;						// after 1 byte clock, the status register read from flash is valid
	reg											busy_bit;							// busy bit read from flash
	reg		[8:0]								cnt_wr;								// write data count
	reg											flash_wr_req_d1;
	reg		[7:0]								flash_wr_data;
	reg		[8:0]								cnt_rd;								// read data count
	
always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		state <= IDLE;
	end else case ( state )
		IDLE: begin
			if ( flash_erase_all_i || flash_erase_64k_i || flash_erase_32k_i || flash_erase_4k_i || flash_wr_en_i ) begin
				state <= WEL;
			end else if ( flash_rd_en_i ) begin
				state <= READ;
			end else begin
				state <= IDLE;
			end
		end
		CS_WAIT: begin
			if ( cnt_cs_high >= 'd4 ) begin
				state <= state_next;
			end else begin
				state <= CS_WAIT;
			end
		end
		WEL: begin
			if ( cnt_cmd1 && !spi_busy ) begin
				state <= CS_WAIT;
			end else begin
				state <= WEL;
			end
		end
		ERASE: begin
			if ( cnt_cmd4 >= 'd4 && !spi_busy ) begin
				state <= CS_WAIT;
			end else begin
				state <= ERASE;
			end
		end
		ERASE_CHIP: begin
			if ( cnt_cmd1 && !spi_busy ) begin
				state <= CS_WAIT;
			end else begin
				state <= ERASE_CHIP;
			end
		end
		BUSY: begin
			if ( cnt_cmd1 && !spi_rd_en && !spi_busy ) begin
				state <= CS_WAIT;
			end else begin
				state <= BUSY;
			end
		end
		PROGRAM: begin
			if ( cnt_wr >= 'd260 && !spi_busy ) begin
				 state <= CS_WAIT;
			end else begin
				state <= PROGRAM;
			end
		end
		READ: begin
			if ( cnt_rd >= 'd261 ) begin
				state <= CS_WAIT;
			end else begin
				state <= READ;
			end
		end
		default: state <= IDLE;
	endcase
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		state_next <= IDLE;
	end else case ( state )
		CS_WAIT: begin
			state_next <= state_next;
		end
		WEL: begin
			if ( erase_all ) begin
				state_next <= ERASE_CHIP;
			end else if ( erase_64k || erase_32k || erase_4k ) begin
				state_next <= ERASE;
			end else begin
				state_next <= PROGRAM;
			end
		end
		ERASE: begin
			state_next <= BUSY;
		end
		ERASE_CHIP: begin
			state_next <= BUSY;
		end
		BUSY: begin
			state_next <= IDLE;
		end
		PROGRAM: begin
			state_next <= BUSY;
		end
		READ: begin
			state_next <= IDLE;
		end
		default: state_next <= IDLE;
	endcase
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		erase_4k <= 1'b0;
		erase_32k <= 1'b0;
		erase_64k <= 1'b0;
		erase_all <= 1'b0;
		rd_en <= 1'b0;
		wr_en <= 1'b0;
		flash_addr <= 24'h0;
	end else if ( state == IDLE ) begin
		erase_4k <= flash_erase_4k_i;
		erase_32k <= flash_erase_32k_i;
		erase_64k <= flash_erase_64k_i;
		erase_all <= flash_erase_all_i;
		rd_en <= flash_rd_en_i;
		wr_en <= flash_wr_en_i;
		flash_addr <= flash_addr_i;
	end else begin
		erase_4k <= erase_4k;
		erase_32k <= erase_32k;
		erase_64k <= erase_64k;
		erase_all <= erase_all;
		rd_en <= rd_en;
		wr_en <= wr_en;
		flash_addr <= flash_addr;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		spi_tx_en <= 1'b0;
	end else case ( state )
		WEL: begin
			if ( cnt_cmd1 ) begin
				spi_tx_en <= 1'b0;
			end else begin
				spi_tx_en <= 1'b1;
			end
		end
		CS_WAIT: spi_tx_en <= 1'b0;
		ERASE: begin
			if ( cnt_cmd4 >= 'd4 ) begin
				spi_tx_en <= 1'b0;
			end else begin
				spi_tx_en <= 1'b1;
			end
		end
		ERASE_CHIP: begin
			if ( cnt_cmd1 ) begin
				spi_tx_en <= 1'b0;
			end else begin
				spi_tx_en <= 1'b1;
			end
		end
		BUSY: begin
			if ( cnt_cmd1 ) begin
				spi_tx_en <= 1'b0;
			end else begin
				spi_tx_en <= 1'b1;
			end
		end
		PROGRAM: begin
			if ( cnt_wr >= 'd260 ) begin
				spi_tx_en <= 1'b0;
			end else begin
				spi_tx_en <= 1'b1;
			end
		end
		READ: begin
			if ( cnt_cmd4 >= 'd4 ) begin
				spi_tx_en <= 1'b0;
			end else begin
				spi_tx_en <= 1'b1;
			end
		end
		default: spi_tx_en <= 1'b0;
	endcase
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		spi_tx_data <= 8'hFF;
	end else case ( state )
		WEL: spi_tx_data <= 8'h06;
		ERASE: begin
			case ( cnt_cmd4 )
				'd0: if ( erase_64k ) spi_tx_data <= 8'hD8;
					else if ( erase_32k ) spi_tx_data <= 8'h52;
					else spi_tx_data <= 8'h20;
				'd1: spi_tx_data <= flash_addr[23:16];
				'd2: spi_tx_data <= flash_addr[15:8];
				'd3: spi_tx_data <= flash_addr[7:0];
				default: spi_tx_data <= 8'hFF;
			endcase
		end
		ERASE_CHIP: spi_tx_data <= 8'h60;
		BUSY: spi_tx_data <= 8'h05;
		PROGRAM: begin
			case ( cnt_cmd4 )
				'd0: spi_tx_data <= 8'h02;
				'd1: spi_tx_data <= flash_addr[23:16];
				'd2: spi_tx_data <= flash_addr[15:8];
				'd3: spi_tx_data <= flash_addr[7:0];
				default: spi_tx_data <= flash_wr_data;
			endcase
		end
		READ: begin
			case ( cnt_cmd4 )
				'd0: spi_tx_data <= 8'h0B;
				'd1: spi_tx_data <= flash_addr[23:16];
				'd2: spi_tx_data <= flash_addr[15:8];
				'd3: spi_tx_data <= flash_addr[7:0];
				default: spi_tx_data <= 8'hFF;
			endcase
		end
		default: spi_tx_data <= 8'hFF;
	endcase
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		spi_rd_en <= 1'b0;
	end else case ( state )
		BUSY: begin
			spi_rd_en <= busy_bit;
		end
		READ: begin
			if ( cnt_rd == 'd0 ) begin
				spi_rd_en <= 1'b1;
			end else if ( cnt_rd >= 'd259 && !spi_busy ) begin
				spi_rd_en <= 1'b0;
			end else begin
				spi_rd_en <= spi_rd_en;
			end
		end
		default: spi_rd_en <= 1'b0;
	endcase
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		cnt_cmd1 <= 1'b0;
	end else if ( state == WEL || state == ERASE_CHIP || state == BUSY ) begin
		if ( spi_tx_en && !spi_busy ) begin
			cnt_cmd1 <= 1'b1;
		end else begin
			cnt_cmd1 <= cnt_cmd1;
		end
	end else begin
		cnt_cmd1 <= 1'b0;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		cnt_cs_high <= 3'd0;
	end else if ( state == CS_WAIT ) begin
		cnt_cs_high <= cnt_cs_high + 3'd1;
	end else begin
		cnt_cs_high <= 3'd0;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		cnt_cmd4 <= 3'd0;
	end else if ( state == ERASE || state == PROGRAM || state == READ ) begin
		if ( cnt_cmd4 < 'd4 && spi_tx_en && !spi_busy ) begin
			cnt_cmd4 <= cnt_cmd4 + 3'd1;
		end else begin
			cnt_cmd4 <= cnt_cmd4;
		end
	end else begin
		cnt_cmd4 <= 3'd0;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		streg_valid <= 1'b0;
	end else if ( state == BUSY ) begin
		if ( spi_rx_valid ) begin
			streg_valid <= 1'b1;
		end else begin
			streg_valid <= streg_valid;
		end
	end else begin
		streg_valid <= 1'b0;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		busy_bit <= 1'b1;
	end else if ( state == BUSY ) begin
		if ( streg_valid && spi_rx_valid ) begin
			busy_bit <= spi_rx_data[0];
		end else begin
			busy_bit <= busy_bit;
		end
	end else begin
		busy_bit <= 1'b1;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		cnt_wr <= 9'd0;
	end else if ( state == PROGRAM ) begin
		if ( spi_tx_en && !spi_busy ) begin
			cnt_wr <= cnt_wr + 9'd1;
		end else begin
			cnt_wr <= cnt_wr;
		end
	end else begin
		cnt_wr <= 9'd0;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		flash_wr_req_o <= 1'b0;
	end else if ( state == PROGRAM ) begin
		if ( cnt_wr >= 'd3 && cnt_wr <= 'd258 && spi_tx_en && !spi_busy ) begin
			flash_wr_req_o <= 1'b1;
		end else begin
			flash_wr_req_o <= 1'b0;
		end
	end else begin
		flash_wr_req_o <= 1'b0;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		flash_wr_req_d1 <= 1'b0;
	end else begin
		flash_wr_req_d1 <= flash_wr_req_o;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		flash_wr_data <= 8'h0;
	end else if ( flash_wr_req_d1 ) begin
		flash_wr_data <= flash_wr_data_i;
	end else begin
		flash_wr_data <= flash_wr_data;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		cnt_rd <= 9'd0;
	end else if ( state == READ ) begin
		if ( spi_rx_valid ) begin
			cnt_rd <= cnt_rd + 9'd1;
		end else begin
			cnt_rd <= cnt_rd;
		end
	end else begin
		cnt_rd <= 9'd0;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		flash_erase_done_o <= 1'b0;
		flash_wr_done_o <= 1'b0;
		flash_rd_done_o <= 1'b0;
	end else if ( state == IDLE && ( erase_all || erase_64k || erase_32k || erase_4k ) ) begin
		flash_erase_done_o <= 1'b1;
		flash_wr_done_o <= 1'b0;
		flash_rd_done_o <= 1'b0;
	end else if ( state == IDLE && wr_en ) begin
		flash_erase_done_o <= 1'b0;
		flash_wr_done_o <= 1'b1;
		flash_rd_done_o <= 1'b0;
	end else if ( state == IDLE && rd_en ) begin
		flash_erase_done_o <= 1'b0;
		flash_wr_done_o <= 1'b0;
		flash_rd_done_o <= 1'b1;
	end else begin
		flash_erase_done_o <= 1'b0;
		flash_wr_done_o <= 1'b0;
		flash_rd_done_o <= 1'b0;
	end
end

assign	flash_busy_o			=	( state != IDLE );
assign	flash_rd_data_o			=	spi_rx_data;
assign	flash_rd_data_valid_o	=	( cnt_rd >= 'd5 ) && spi_rx_valid;

endmodule