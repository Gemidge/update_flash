# update_flash

 Update the program of FPGA in a SPI flash.

## test platform

XC6SLX16-FTG256 and W25Q128BV

## documents struction

rtl: The main verilog design.

example: Including 2 examples to instantiate files in the rtl folder.

----uart_flash: An example to instantiate "flash_driver.v". Read, write and erase flash through uart.

----uart_update_flash: An example to instantiate "update_flash.v". Update the program of FPGA in a SPI flash through uart.

## instantiation

When instantiating "update_flash.v", give flash_prog_size_i and pull up flash_erase_en_i. 

Then wait for flash_wr_ready_o to be high. 

After that, pull up flash_wr_en_i whenever receiving 256 bytes data. And ( flash_wr_en_i && flash_wr_ready_o ) means the module is going to ask for 256 bytes data to write.

Give the right data after flash_wr_req_o.

## instructions in examples

### uart_flash:

command form: command head + command order + parameters ( optional )

command head: `$flash$`('h36_66_6C_61_73_68_36)
chip erase: 'h00
64 KB block erase: 'h01 + 3 bytes address ( MSB first )
32 KB block erase: 'h02 + 3 bytes address
sector erase: 'h03 + 3 bytes address
page program: 'h10 + 3 bytes address + 256 bytes data
read flash: 'h20 + 3 bytes address
Answer erase and write after that it's completed, command head and order.
Answer error command order with "command head + 'hFF".

### uart_update_flash

`$update$` ( 'h24_75_70_64_61_74_65_24 ) + 3 bytes file size ( MSB first, unit: byte )

after erase done, send bin file
feedback: "erase done" ( 'h65_72_61_73_65_20_64_6F_6E_65 ), "write done" ( 'h77_72_69_74_65_20_64_6F_6E_65 )
