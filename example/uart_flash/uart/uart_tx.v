//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Benjamin Smith
// 
// Create Date:    10:32 05/29/2023 
// Design Name: 
// Module Name:    uart_tx
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: uart sending data module
//
// Dependencies: 
//
// Revision: 
// Revision 1.00 - File Completed  10:59 05/29/2023 
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////

module uart_tx (
	input	wire								sys_clk,
	input	wire								sys_rst_n,
	input	wire								uart_tx_en_i,
	input	wire	[7:0]						uart_txdata_i,
	output	reg									uart_tx_busy_o,
	output	reg									uart_txd_o					// output to board
);

	parameter		CLK_FREQ					= 'd50_000_000;
	parameter		BPS							= 'd115200;
	localparam		COUNT						= CLK_FREQ / BPS;
	
	reg		[7:0]								uart_txdata;
	reg		[15:0]								cnt_bps;
	reg		[3:0]								cnt_data;					// 0: start, 1~8: data, 9: stop
	
always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		uart_txdata <= 8'h0;
	end else if ( uart_tx_en_i && !uart_tx_busy_o ) begin
		uart_txdata <= uart_txdata_i;
	end else begin
		uart_txdata <= uart_txdata;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		cnt_bps <= 16'd0;
	end else if ( uart_tx_en_i && !uart_tx_busy_o ) begin
		cnt_bps <= 16'd1;
	end else if ( cnt_bps >= COUNT && cnt_data < 'd9 ) begin
		cnt_bps <= 16'd1;
	end else if ( cnt_bps >= COUNT ) begin
		cnt_bps <= 16'd0;
	end else if ( uart_tx_busy_o ) begin
		cnt_bps <= cnt_bps + 16'd1;
	end else begin
		cnt_bps <= 16'd0;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		cnt_data <= 4'd0;
	end else if ( cnt_bps >= COUNT && cnt_data < 'd9 ) begin
		cnt_data <= cnt_data + 4'd1;
	end else if ( cnt_bps >= COUNT ) begin
		cnt_data <= 4'd0;
	end else begin
		cnt_data <= cnt_data;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		uart_tx_busy_o <= 1'b0;
	end else if ( uart_tx_en_i && !uart_tx_busy_o ) begin				// start
		uart_tx_busy_o <= 1'b1;
	end else if ( cnt_bps >= COUNT && cnt_data >= 'd9 ) begin			// stop
		uart_tx_busy_o <= 1'b0;
	end else begin
		uart_tx_busy_o <= uart_tx_busy_o;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		uart_txd_o <= 1'b1;
	end else if ( uart_tx_busy_o ) begin
		case ( cnt_data )
			'd0: uart_txd_o <= 1'b0;
			'd1: uart_txd_o <= uart_txdata[0];
			'd2: uart_txd_o <= uart_txdata[1];
			'd3: uart_txd_o <= uart_txdata[2];
			'd4: uart_txd_o <= uart_txdata[3];
			'd5: uart_txd_o <= uart_txdata[4];
			'd6: uart_txd_o <= uart_txdata[5];
			'd7: uart_txd_o <= uart_txdata[6];
			'd8: uart_txd_o <= uart_txdata[7];
			'd9: uart_txd_o <= 1'b1;
			default: uart_txd_o <= 1'b1;
		endcase
	end else begin
		uart_txd_o <= 1'b1;
	end
end

endmodule