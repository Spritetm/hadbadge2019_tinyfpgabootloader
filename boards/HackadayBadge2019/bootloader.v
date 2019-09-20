module hadbadgebl (
  input clk,
  output [27:0] genio,

  inout usb_dp,
  inout usb_dm,
  output usb_pu,
  input usb_vdet,

  output [10:0] ledc,
  output [2:0] leda,
  input [7:0] btn,
  input  flash_miso,
  output flash_cs,
  output flash_mosi,
  output flash_wp,
  output flash_hold,
  output reg fsel_d,
  output reg fsel_c,

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
  assign ledc[10] = 0;
  assign ledc[9] = 0;
  assign ledc[8] = fsel_d;
  assign ledc[7] = 0;
  assign ledc[6] = 0;
  assign ledc[5] = usb_p_rx;
  assign ledc[4] = usb_n_rx;
  assign ledc[3] = usb_p_tx;
  assign ledc[2] = usb_n_tx;
  assign ledc[1] = usb_tx_en;
  assign leda = 'b001;
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
    .clk(clk_48mhz),
    .reset(reset),
    .usb_p_tx(usb_p_tx),
    .usb_n_tx(usb_n_tx),
    .usb_p_rx(usb_p_rx),
    .usb_n_rx(usb_n_rx),
    .usb_tx_en(usb_tx_en),
    .led(ledc[0]),
    .spi_miso(flash_miso),
    .spi_cs(flash_cs_i),
    .spi_mosi(flash_mosi),
    .spi_sck(flash_sck),
    .boot(boot)
  );
  

  reg initiate_boot = 0;
  reg [7:0] boot_delay = 0;

  parameter STATE_WAIT = 0;
  parameter STATE_CARTFLASH = 1;
  parameter STATE_WAIT_TINYBOOT = 2;
  parameter STATE_DOBOOT = 3;
  reg [1:0] state = STATE_WAIT;
  reg do_tinyboot;
  reg trigger_boot = 0;
  assign programn=~trigger_boot;

//  assign fsel_c = ((state==START_CARTFLASH) && boot_delay[6]) ? 1 : 0;

  always @(posedge clk) begin
	boot_delay <= boot_delay + 1;
	if (boot) initiate_boot <= 1;
//	if (state==START_CARTFLASH) begin
		if (boot_delay==31) fsel_c <= 1;
		if (boot_delay==127) fsel_c <= 0;
//	end else begin
//		fsel_c <= 0;
//	end
	if (boot_delay=='hff) begin
		if (state == STATE_WAIT) begin
			do_tinyboot <= ~btn[2];
			if (!btn[0]) begin
				//up pressed
				fsel_d <= 1;
				state <= STATE_CARTFLASH;
			end else begin
				fsel_d <= 0;
				state <= STATE_WAIT_TINYBOOT;
			end
		end else if (state == STATE_CARTFLASH) begin
			state <= STATE_WAIT_TINYBOOT;
		end else if (state == STATE_WAIT_TINYBOOT) begin
			if (btn[2]) begin //never boot if up is pressed
				if (usb_vdet==0 || do_tinyboot==0 || initiate_boot) begin
					state <= STATE_DOBOOT;
				end
			end
		end else begin //STATE_DOBOOT
			trigger_boot <= 1;
		end
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
