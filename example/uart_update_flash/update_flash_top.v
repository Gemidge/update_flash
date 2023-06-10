//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Bemjamin Smith
// 
// Create Date:    13:21 6/10/2023
// Design Name: 
// Module Name:    update_flash_top
// Project Name: 
// Target Devices: W25Q128BV
// Tool versions: 
// Description:    update flash via uart
//
// Dependencies: 
//
// Revision: 
// Revision 1.00 - File Completed 16:10 2023/06/10
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////

module update_flash_top (
	input	wire							board_clk,
	input	wire							sys_rst_n,
	output	wire							flash_cs_n_o,
	output	wire							flash_sck_o,
	output	wire							flash_mosi_o,
	input	wire							flash_miso_i,
	input	wire							uart_rxd_i,
	output	wire							uart_txd_o,
	output	wire							led
);

	wire									sys_clk;
	
	wire									flash_erase_en;
	wire	[23:0]							flash_prog_size;
	wire									flash_erase_busy;
	wire									flash_wr_en;
	wire									flash_wr_ready;
	wire									flash_writing;
	wire	[7:0]							flash_wr_data;
	wire									flash_wr_req;
	wire									flash_wr_done;
	
	wire									uart_rx_valid;
	wire	[7:0]							uart_rxdata;
	wire									uart_tx_en;
	wire	[7:0]							uart_txdata;
	wire									uart_tx_busy;

assign		led		=	1'b1;

clk_wiz										u1_clk_wiz (
	.CLK_IN1								( board_clk			),			// 50 MHz
	.CLK_OUT1								( sys_clk			),			// 100 MHz
	.RESET									( ~sys_rst_n		),
	.LOCKED									( 					)
);

update_flash								u2_update_flash (
	.sys_clk								( sys_clk			),
	.sys_rst_n								( sys_rst_n			),
	.flash_cs_n_o							( flash_cs_n_o		),
	.flash_sck_o							( flash_sck_o		),
	.flash_mosi_o							( flash_mosi_o		),
	.flash_miso_i							( flash_miso_i		),
	
	.flash_erase_en_i						( flash_erase_en	),
	.flash_prog_size_i						( flash_prog_size	),
	.flash_erase_busy_o						( flash_erase_busy	),
	.flash_wr_en_i							( flash_wr_en		),
	.flash_wr_ready_o						( flash_wr_ready	),
	.flash_writing_o						( flash_writing		),
	.flash_wr_data_i						( flash_wr_data		),
	.flash_wr_req_o							( flash_wr_req		),
	.flash_wr_done_i						( flash_wr_done		)
);

uart										# (
	.CLK_FREQ								( 'd100_000_000		),
	.BPS									( 'd115200			)
)											u3_uart (
	.sys_clk								( sys_clk			),
	.sys_rst_n								( sys_rst_n			),
	.uart_rxd_i								( uart_rxd_i		),
	.uart_txd_o								( uart_txd_o		),
	.uart_rx_valid_o						( uart_rx_valid		),
	.uart_rxdata_o							( uart_rxdata		),
	.uart_tx_en_i							( uart_tx_en		),
	.uart_txdata_i							( uart_txdata		),
	.uart_tx_busy_o							( uart_tx_busy		)
);

uart_decoder								u4_uart_decoder (
	.sys_clk								( sys_clk			),
	.sys_rst_n								( sys_rst_n			),
	.uart_rx_valid_i						( uart_rx_valid		),
	.uart_rxdata_i							( uart_rxdata		),
	.uart_tx_en_o							( uart_tx_en		),
	.uart_txdata_o							( uart_txdata		),
	.uart_tx_busy_i							( uart_tx_busy		),
	.flash_erase_en_o						( flash_erase_en	),
	.flash_prog_size_o						( flash_prog_size	),
	.flash_erase_busy_i						( flash_erase_busy	),
	.flash_wr_en_o							( flash_wr_en		),
	.flash_wr_ready_i						( flash_wr_ready	),
	.flash_writing_i						( flash_writing		),
	.flash_wr_data_o						( flash_wr_data		),
	.flash_wr_req_i							( flash_wr_req		),
	.flash_wr_done_o						( flash_wr_done		)
);

endmodule