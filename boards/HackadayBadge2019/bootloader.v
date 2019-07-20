module hadbadgebl (
  input clk,
  output [27:0] genio,

  inout usb_dp,
  inout usb_dm,
  output usb_pu,
  input usb_vdet,

  output [5:0] led,

  input  flash_miso,
  output flash_cs,
  output flash_mosi,
  output flash_wp,
  output flash_hold,
  
  output programn
);
  wire clk_48mhz;

	pll_8_48 pll(
		.clki(clk),
		.clko(clk_48mhz)
	);

  ////////////////////////////////////////////////////////////////////////////////
  ////////////////////////////////////////////////////////////////////////////////
  ////////
  //////// instantiate tinyfpga bootloader
  ////////
  ////////////////////////////////////////////////////////////////////////////////
  ////////////////////////////////////////////////////////////////////////////////
  wire reset;
  wire usb_p_tx;
  wire usb_n_tx;
  wire usb_p_rx;
  wire usb_n_rx;
  wire usb_tx_en;

  assign flash_wp = 1;
  assign flash_hold = 1;
  assign led[5] = usb_p_rx;
  assign led[4] = usb_n_rx;
  assign led[3] = usb_p_tx;
  assign led[2] = usb_n_tx;
  assign led[1] = usb_tx_en;

  assign genio[0] = clk_48mhz;
  assign genio[1] = 0;
  assign genio[2] = usb_tx_en?usb_n_tx:usb_n_rx;
  assign genio[3] = usb_tx_en?usb_p_tx:usb_p_rx;
  assign genio[4] = flash_sck;
  assign genio[5] = flash_cs_i;
  assign genio[6] = flash_mosi;
  assign genio[7] = flash_miso;
  assign genio[27:8] = 'h0;

  wire flash_sck;
  wire flash_cs_i;
  assign flash_cs = flash_cs_i;

  wire boot;
  
  tinyfpga_bootloader tinyfpga_bootloader_inst (
    .clk_48mhz(clk_48mhz),
    .reset(reset),
    .usb_p_tx(usb_p_tx),
    .usb_n_tx(usb_n_tx),
    .usb_p_rx(usb_p_rx),
    .usb_n_rx(usb_n_rx),
    .usb_tx_en(usb_tx_en),
    .led(led[0]),
    .spi_miso(flash_miso),
    .spi_cs(flash_cs_i),
    .spi_mosi(flash_mosi),
    .spi_sck(flash_sck),
    .boot(boot)
  );
  
  reg initiate_boot = 0;
  reg [8:0] boot_delay = 0;
  assign programn = ~boot_delay[8];
 
  //Note: if usb_vdet is low, usb is not plugged in and we start the boot countdown timer immediately. We cancel
  //it again if usb_vdet suddenly goes high.
  always @(posedge clk) begin
    if (boot) initiate_boot <= 1;

    if (initiate_boot || usb_vdet==0) begin
      boot_delay <= boot_delay + 1'b1;
    end
    if (usb_vdet==1 && initiate_boot==0) begin
      boot_delay <= 0;
    end
  end

  assign usb_pu = 1'b1;

  wire usb_p_rx_in;
  wire usb_n_rx_in;
  TRELLIS_IO #(.DIR("BIDIR")) usb_dp_tristate (.I(usb_p_tx),.T(!usb_tx_en),.B(usb_dp),.O(usb_p_rx_in));
  TRELLIS_IO #(.DIR("BIDIR")) usb_dm_tristate (.I(usb_n_tx),.T(!usb_tx_en),.B(usb_dm),.O(usb_n_rx_in));


  assign usb_p_rx = usb_tx_en ? 1'b1 : usb_p_rx_in;
  assign usb_n_rx = usb_tx_en ? 1'b0 : usb_n_rx_in;


  USRMCLK usrmclk_inst (
    .USRMCLKI(flash_sck),
	.USRMCLKTS(flash_cs)
  ) /* synthesis syn_noprune=1 */;

  assign reset = 0;
endmodule
