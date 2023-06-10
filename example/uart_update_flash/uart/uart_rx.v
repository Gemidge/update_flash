//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Bemjamin Smith
// 
// Create Date:    09:37 05/29/2023 
// Design Name: 
// Module Name:    uart_rx
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: uart receiving data module
//
// Dependencies: 
//
// Revision: 
// Revision 1.00 - File Completed 14:51 05/29/2023 
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////

module uart_rx (
	input	wire								sys_clk,
	input	wire								sys_rst_n,
	input	wire								uart_rxd_i,				// input from board
	output	reg									uart_rx_valid_o,
	output	reg		[7:0]						uart_rxdata_o
);
	parameter		CLK_FREQ					= 'd50_000_000;
	parameter		BPS							= 'd115200;
	localparam		COUNT						= CLK_FREQ / BPS;
	localparam		HALF_COUNT					= COUNT / 2;
	
	reg											uart_rxd_i_d1;
	reg											uart_rxd;
	reg											uart_rxd_d1;
	reg		[15:0]								cnt_bps;
	reg		[3:0]								cnt_data;				// 0: start, 1~8: data, 9: stop

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		uart_rxd_i_d1 <= 1'b1;
		uart_rxd <= 1'b1;
		uart_rxd_d1 <= 1'b1;
	end else begin
		uart_rxd_i_d1 <= uart_rxd_i;
		uart_rxd <= uart_rxd_i_d1;
		uart_rxd_d1 <= uart_rxd;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		cnt_bps <= 16'd0;
	end else if ( !uart_rxd && uart_rxd_d1 && cnt_bps == 0 ) begin		// start bit
		cnt_bps <= 16'd1;
	end else if ( cnt_bps >= COUNT && cnt_data < 'd9 ) begin
		cnt_bps <= 16'd1;
	end else if ( cnt_bps >= HALF_COUNT && cnt_data >= 'd9 ) begin		// stop bit, stop earlier in case of freqency deviation
		cnt_bps <= 16'd0;
	end else if ( cnt_bps > 0 ) begin
		cnt_bps <= cnt_bps + 16'd1;
	end else begin														// idle bus
		cnt_bps <= 16'd0;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		cnt_data <= 4'd0;
	end else if ( cnt_bps >= COUNT && cnt_data < 'd9 ) begin
		cnt_data <= cnt_data + 4'd1;
	end else if ( cnt_bps >= HALF_COUNT && cnt_data >= 'd9 ) begin
		cnt_data <= 4'd0;
	end else begin
		cnt_data <= cnt_data;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		uart_rxdata_o <= 8'h0;
	end else if ( cnt_bps == HALF_COUNT ) begin
		case ( cnt_data )
			'd1: uart_rxdata_o <= { uart_rxdata_o[7:1], uart_rxd };
			'd2: uart_rxdata_o <= { uart_rxdata_o[7:2], uart_rxd, uart_rxdata_o[0] };
			'd3: uart_rxdata_o <= { uart_rxdata_o[7:3], uart_rxd, uart_rxdata_o[1:0] };
			'd4: uart_rxdata_o <= { uart_rxdata_o[7:4], uart_rxd, uart_rxdata_o[2:0] };
			'd5: uart_rxdata_o <= { uart_rxdata_o[7:5], uart_rxd, uart_rxdata_o[3:0] };
			'd6: uart_rxdata_o <= { uart_rxdata_o[7:6], uart_rxd, uart_rxdata_o[4:0] };
			'd7: uart_rxdata_o <= { uart_rxdata_o[7], uart_rxd, uart_rxdata_o[5:0] };
			'd8: uart_rxdata_o <= { uart_rxd, uart_rxdata_o[6:0] };
			default: uart_rxdata_o <= uart_rxdata_o;
		endcase
	end else begin
		uart_rxdata_o <= uart_rxdata_o;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		uart_rx_valid_o <= 1'b0;
	end else if ( cnt_bps >= HALF_COUNT && cnt_data >= 'd9 ) begin		// sending data at the stop bit 
		uart_rx_valid_o <= 1'b1;
	end else begin
		uart_rx_valid_o <= 1'b0;
	end
end

endmodule