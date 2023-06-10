//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Benjamin Smith
// 
// Create Date:    15:04 05/29/2023 
// Design Name: 
// Module Name:    uart
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: uart top module, including receiving data and sending data
//
// Dependencies: 
//
// Revision: 
// Revision 1.00 - File Completed  15:13 05/29/2023 
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////

module uart (
	input	wire								sys_clk,
	input	wire								sys_rst_n,
	input	wire								uart_rxd_i,
	output	wire								uart_txd_o,
	// control signals
	output	wire								uart_rx_valid_o,
	output	wire	[7:0]						uart_rxdata_o,
	input	wire								uart_tx_en_i,
	input	wire	[7:0]						uart_txdata_i,
	output	wire								uart_tx_busy_o
);

	parameter		CLK_FREQ					= 'd50_000_000;
	parameter		BPS							= 'd115200;

uart_rx											# (
	.CLK_FREQ									( CLK_FREQ		),
	.BPS										( BPS			)
	)											u1_uart_rx (
	.sys_clk									( sys_clk		),
	.sys_rst_n									( sys_rst_n		),
	.uart_rxd_i									( uart_rxd_i	),
	.uart_rx_valid_o							( uart_rx_valid_o	),
	.uart_rxdata_o								( uart_rxdata_o	)
);

uart_tx 										# (
	.CLK_FREQ									( CLK_FREQ		),
	.BPS										( BPS			)
	)											u2_uart_tx (
	.sys_clk									( sys_clk		),
	.sys_rst_n									( sys_rst_n		),
	.uart_tx_en_i								( uart_tx_en_i	),
	.uart_txdata_i								( uart_txdata_i	),
	.uart_tx_busy_o								( uart_tx_busy_o),
	.uart_txd_o									( uart_txd_o	)
);

endmodule