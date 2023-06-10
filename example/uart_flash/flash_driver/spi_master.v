//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Bemjamin Smith
// 
// Create Date:    15:24 05/29/2023 
// Design Name: 
// Module Name:    spi_master
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: spi master driver, only support mode 3, CPOL = 1, CPHA = 1
//              use tiwce frequency clock instead of the sys_clk, avoid FPGA clock resource output directly
//              note: sck is a signal depend on sys_clk, and miso appears at negative edge of sck, later than theoretical data.
//                    if using code in annotation, it's at risk of reading elder data
// Dependencies: 
//
// Revision: 2.00 File Completed 15:57 06/02/2023
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////

module spi_master (
	input	wire								sys_clk,					// twice the clock frequency of spi_sck_o
	input	wire								sys_rst_n,
	output	reg									spi_cs_n_o,
	output	reg									spi_sck_o,
	output	reg									spi_mosi_o,
	input	wire								spi_miso_i,
	// control signals
	input	wire								spi_tx_en_i,				// When tx_en is low but rd_en is high, read next data and send 'hFF
	input	wire	[7:0]						spi_tx_data_i,				// It's valid when < spi_tx_en_i && !spi_busy_o >
	output	reg									spi_busy_o,					// When it is high, all inputs are ignored. User should keep "enable" and "data" untill "busy" goes low.
	output	reg									spi_rx_valid_o,
	output	reg		[7:0]						spi_rx_data_o,
	input	wire								spi_rd_en_i					// Read next data while < ( spi_rd_en_i || spi_tx_en_i ) && !spi_busy_o >
);
	
	reg		[4:0]								cnt_spi;
	reg		[7:0]								spi_tx_data;
	reg		[7:0]								spi_rx_data;
	reg											spi_rx_valid;

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		cnt_spi <= 5'd0;
	end else if ( ( spi_tx_en_i || spi_rd_en_i ) && !spi_busy_o ) begin
		cnt_spi <= 5'd1;
	end else if ( cnt_spi > 'd0 && cnt_spi < 'd17 ) begin
		cnt_spi <= cnt_spi + 5'd1;
	end else begin
		cnt_spi <= 5'd0;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		spi_cs_n_o <= 1'b1;
	end else if ( ( spi_tx_en_i || spi_rd_en_i ) && !spi_busy_o ) begin
		spi_cs_n_o <= 1'b0;
	end else if ( cnt_spi >= 'd17 ) begin
		spi_cs_n_o <= 1'b1;
	end else begin
		spi_cs_n_o <= spi_cs_n_o;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		spi_sck_o <= 1'b1;
	end else if ( cnt_spi > 'd0 && cnt_spi < 'd17 ) begin
		spi_sck_o <= ~cnt_spi[0];
	end else begin
		spi_sck_o <= 1'b0;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		spi_busy_o <= 1'b0;
	end else if ( ( spi_tx_en_i || spi_rd_en_i ) && !spi_busy_o ) begin
		spi_busy_o <= 1'b1;
	end else if ( cnt_spi == 'd15 ) begin
		spi_busy_o <= 1'b0;
	end else begin
		spi_busy_o <= spi_busy_o;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		spi_tx_data <= 8'hFF;
	end else if ( spi_tx_en_i && !spi_busy_o ) begin
		spi_tx_data <= spi_tx_data_i;
	end else if ( !spi_busy_o ) begin
		spi_tx_data <= 8'hFF;
	end else begin
		spi_tx_data <= spi_tx_data;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		spi_mosi_o <= 1'b1;
	end else case ( cnt_spi )
		'd0: spi_mosi_o <= 1'b1;
		'd17: spi_mosi_o <= 1'b1;
		'd1: spi_mosi_o <= spi_tx_data[7];
		'd3: spi_mosi_o <= spi_tx_data[6];
		'd5: spi_mosi_o <= spi_tx_data[5];
		'd7: spi_mosi_o <= spi_tx_data[4];
		'd9: spi_mosi_o <= spi_tx_data[3];
		'd11: spi_mosi_o <= spi_tx_data[2];
		'd13: spi_mosi_o <= spi_tx_data[1];
		'd15: spi_mosi_o <= spi_tx_data[0];
		default: spi_mosi_o <= spi_mosi_o;
	endcase
end

// always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	// if ( !sys_rst_n ) begin
		// spi_rx_data <= 8'h0;
	// end else if (cnt_spi > 'd0 && !cnt_spi[0] ) begin
		// spi_rx_data <= { spi_rx_data[6:0], spi_miso_i };
	// end else begin
		// spi_rx_data <= spi_rx_data;
	// end
// end

// always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	// if ( !sys_rst_n ) begin
		// spi_rx_data_o <= 8'h0;
	// end else if ( cnt_spi == 'd1 || cnt_spi == 'd17 ) begin
		// spi_rx_data_o <= spi_rx_data;
	// end else begin
		// spi_rx_data_o <= spi_rx_data_o;
	// end
// end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		spi_rx_data_o <= 8'h0;
	end else if ( cnt_spi[0] ) begin
		spi_rx_data_o <= { spi_rx_data_o[6:0], spi_miso_i };
	end else begin
		spi_rx_data_o <= spi_rx_data_o;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		spi_rx_valid <= 1'b0;
	end else if ( cnt_spi == 'd16 ) begin
		spi_rx_valid <= 1'b1;
	end else begin
		spi_rx_valid <= 1'b0;
	end
end

always @ ( posedge sys_clk or negedge sys_rst_n ) begin
	if ( !sys_rst_n ) begin
		spi_rx_valid_o <= 1'b0;
	end else begin
		spi_rx_valid_o <= spi_rx_valid;
	end
end

endmodule