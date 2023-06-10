//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Bemjamin Smith
// 
// Create Date:    10:22 05/30/2023
// Design Name: 
// Module Name:    uart_flash_top
// Project Name: 
// Target Devices: W25Q128BV
// Tool versions: 
// Description:    a temp module, read and write flash via uart
//
// Dependencies: 
//
// Revision: 
// Revision 1.00 - File Completed 10:41 06/02/2023
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////

module uart_flash_top (
	input	wire							board_clk,
	input	wire							sys_rst_n,
	output	wire							flash_cs_n_o,
	output	wire							flash_sck_o,
	output	wire							flash_mosi_o,
	input	wire							flash_miso_i,
	input	wire							uart_rxd_i,
	output	wire							uart_txd_o
);

	wire									sys_clk;
	
	wire									flash_erase_4k;
	wire									flash_erase_32k;
	wire									flash_erase_64k;
	wire									flash_erase_all;
	wire	[23:0]							flash_addr;
	wire									flash_busy;
	wire									flash_rd_en;
	wire	[7:0]							flash_rd_data;
	wire									flash_rd_data_valid;
	wire									flash_wr_en;
	wire									flash_wr_req;
	wire	[7:0]							flash_wr_data;
	wire									flash_erase_done;
	wire									flash_wr_done;
	wire									flash_rd_done;
	
	wire									uart_rx_valid;
	wire	[7:0]							uart_rxdata;
	wire									uart_tx_en;
	wire	[7:0]							uart_txdata;
	wire									uart_tx_busy;

clk_wiz										u1_clk_wiz (
	.CLK_IN1								( board_clk			),			// 50 MHz
	.CLK_OUT1								( sys_clk			),			// 100 MHz
	.RESET									( ~sys_rst_n		),
	.LOCKED									( 					)
);

flash_driver								u2_flash_driver (
	.sys_clk								( sys_clk			),
	.sys_rst_n								( sys_rst_n			),
	.flash_cs_n_o							( flash_cs_n_o		),
	.flash_sck_o							( flash_sck_o		),
	.flash_mosi_o							( flash_mosi_o		),
	.flash_miso_i							( flash_miso_i		),
	.flash_erase_4k_i						( flash_erase_4k	),
	.flash_erase_32k_i						( flash_erase_32k	),
	.flash_erase_64k_i						( flash_erase_64k	),
	.flash_erase_all_i						( flash_erase_all	),
	.flash_addr_i							( flash_addr		),
	.flash_busy_o							( flash_busy		),
	.flash_rd_en_i							( flash_rd_en		),
	.flash_rd_data_o						( flash_rd_data		),
	.flash_rd_data_valid_o					( flash_rd_data_valid	),
	.flash_wr_en_i							( flash_wr_en		),
	.flash_wr_req_o							( flash_wr_req		),
	.flash_wr_data_i						( flash_wr_data		),
	.flash_erase_done_o						( flash_erase_done	),
	.flash_wr_done_o						( flash_wr_done		),
	.flash_rd_done_o						( flash_rd_done		)
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
	.flash_erase_4k_o						( flash_erase_4k	),
	.flash_erase_32k_o						( flash_erase_32k	),
	.flash_erase_64k_o						( flash_erase_64k	),
	.flash_erase_all_o						( flash_erase_all	),
	.flash_addr_o							( flash_addr		),
	.flash_busy_i							( flash_busy		),
	.flash_rd_en_o							( flash_rd_en		),
	.flash_rd_data_i						( flash_rd_data		),
	.flash_rd_data_valid_i					( flash_rd_data_valid	),
	.flash_wr_en_o							( flash_wr_en		),
	.flash_wr_req_i							( flash_wr_req		),
	.flash_wr_data_o						( flash_wr_data		),
	.flash_erase_done_i						( flash_erase_done	),
	.flash_wr_done_i						( flash_wr_done		),
	.flash_rd_done_i						( flash_rd_done		)
);

endmodule