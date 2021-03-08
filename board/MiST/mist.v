//  Проект DVK-FPGA
//
//  Интерфейсный модуль для платы MiST
//=================================================================
//

`include "config.v"

module mist(
   input          CLK_27,       // clock input 27 MHz
//   output [3:0]   led,          // индикаторные светодиоды   
   
   // Интерфейс SDRAM
   inout  [15:0]  DRAM_DQ,      //   SDRAM Data bus 16 Bits
   output [12:0]  DRAM_ADDR,    //   SDRAM Address bus 12 Bits
   output         DRAM_LDQM,    //   SDRAM Low-byte Data Mask 
   output         DRAM_UDQM,    //   SDRAM High-byte Data Mask
   output         DRAM_WE_N,    //   SDRAM Write Enable
   output         DRAM_CAS_N,   //   SDRAM Column Address Strobe
   output         DRAM_RAS_N,   //   SDRAM Row Address Strobe
   output         DRAM_CS_N,    //   SDRAM Chip Select
   output         DRAM_BA_0,    //   SDRAM Bank Address 0
   output         DRAM_BA_1,    //   SDRAM Bank Address 0
   output         DRAM_CLK,     //   SDRAM Clock
   output         DRAM_CKE,     //   SDRAM Clock Enable
   
   // VGA
   output         vgah,         // горизонтальная синхронизация
   output         vgav,         // вертикакльная синхронизация
   output         [4:0]vgar,    // красный видеосигнал
   output         [5:0]vgag,    // зеленый видеосигнал
   output         [4:0]vgab,    // синий видеосигнал

   // пищалка    
   output         buzzer,
//   output         AUDIO_L,
//   output         AUDIO_R,
    
   // дополнительный UART 
   output         irps_txd,
   input          irps_rxd,
   
// SPI interface to arm io controller
   output			SPI_DO,
   input          SPI_DI,
   input          SPI_SCK,
   input          SPI_SS2,
   input          SPI_SS3,
//	input          SPI_SS4,
   input          CONF_DATA0

);
//--------------------------------------------
   wire			[3:0] button = 0;        // кнопки
   wire			[3:0] sw;        // переключатели конфигурации
   wire        [3:0] led;           // индикаторные светодиоды
	
   assign      sw[1:0] = 2'b00;
   assign      sw[2] = 1'b0;
   assign      sw[3] = 1'b0;
	
	// интерфейс SD-карты
   wire           sdcard_cs;
   wire           sdcard_mosi;
   wire           sdcard_sclk;
   wire			   sdcard_miso;

	// LPT - принтер
	wire [7:0]     lp_data;    // данные для передачи к принтеру
	wire           lp_stb_n;   // строб записи в принтер
	wire           lp_init_n;  // строб сброса
	wire           lp_busy;    // сигнал занятости принтера
	wire           lp_err_n;   // сигнал ошибки

   // PS/2
   wire			  ps2_clk;
   wire			  ps2_data;

	// VGA RGB
   wire [5:0] video_r, video_g, video_b;

//********************************************
//* Светодиоды
//********************************************
wire rk_led, dw_led, my_led, dx_led, timer_led;

assign led[0]=rk_led;        // запрос обмена диска RK
assign led[1]=dw_led;        // запрос обмена диска DW
assign led[2]=my_led|dx_led; // запрос обмена диска MY или DX
assign led[3]=timer_led;     // индикация включения таймера

//************************************************
//* тактовый генератор 
//************************************************
wire clk_p;
wire clk_n;
wire sdclock;
wire clkrdy;
wire clk50;

pll pll1 (
   .inclk0(CLK_27),
   .c0(clk_p),     // 100МГц прямая фаза, основная тактовая частота
   .c1(clk_n),     // 100МГц инверсная фаза
   .c2(sdclock),   // 12.5 МГц тактовый сигнал SD-карты
   .c3(clk50),     // 50 МГц, тактовый сигнал терминальной подсистемы
   .locked(clkrdy) // флаг готовности PLL
);

//**********************************
//* Модуль динамической памяти
//**********************************

wire sdram_reset;
wire sdram_we;
wire sdram_stb;
wire [1:0] sdram_sel;
wire sdram_ack;
wire [21:1] sdram_adr;
wire [15:0] sdram_out;
wire [15:0] sdram_dat;
wire sdram_ready;
wire sdram_wr;
wire sdram_rd;

reg [1:0] dreset;
reg [1:0] dr_cnt;
reg drs;

// формирователь сброса
always @(posedge clk_p)
begin
   dreset[0] <= sdram_reset; // 1 - сброс
   dreset[1] <= dreset[0];
   if (dreset[1] == 1) begin
     // системный сброс активен
     drs<=0;         // активируем сброс DRAM
     dr_cnt<=2'b0;   // запускаем счетчик задержки
   end  
   else 
     // системный сброс снят
     if (dr_cnt != 2'd3) dr_cnt<=dr_cnt+1'b1; // счетчик задержки ++
     else drs<=1'b1;                          // задержка окончена - снимаем сигнал сброса DRAM
end


// стробы подтверждения
wire sdr_wr_ack,sdr_rd_ack;
// тактовый сигнал на память - инверсия синхросигнала шины
assign DRAM_CLK=clk_n;

// стробы чтения и записи в sdram
assign sdram_wr=sdram_we & sdram_stb;
assign sdram_rd=(~sdram_we) & sdram_stb;

// Сигналы выбора старших-младших байтов
reg dram_h,dram_l;

always @ (posedge sdram_stb) begin
  if (sdram_we == 1'b0) begin
   // чтение - всегда словное
   dram_h<=1'b0;
   dram_l<=1'b0;
  end
  else begin
   // определение записываемых байтов
   dram_h<=~sdram_sel[1];  // старший
   dram_l<=~sdram_sel[0];  // младший
  end
end  

assign DRAM_UDQM=dram_h; 
assign DRAM_LDQM=dram_l; 

// контроллер SDRAM

sdram_top sdram(
    .clk(clk_p),
    .rst_n(drs), // запускаем модуль, как только pll выйдет в рабочий режим, запуска процессора не ждем
    .sdram_wr_req(sdram_wr),
    .sdram_rd_req(sdram_rd),
    .sdram_wr_ack(sdr_wr_ack),
    .sdram_rd_ack(sdr_rd_ack),
    .sdram_byteenable(sdram_sel),
    .sys_wraddr({1'b0,sdram_adr[21:1]}),
    .sys_rdaddr({1'b0,sdram_adr[21:1]}),
    .sys_data_in(sdram_out),
    .sys_data_out(sdram_dat),
    .sdwr_byte(1),
    .sdrd_byte(4),
    .sdram_cke(DRAM_CKE),
    .sdram_cs_n(DRAM_CS_N),
    .sdram_ras_n(DRAM_RAS_N),
    .sdram_cas_n(DRAM_CAS_N),
    .sdram_we_n(DRAM_WE_N),
    .sdram_ba({DRAM_BA_1,DRAM_BA_0}),
    .sdram_addr(DRAM_ADDR[12:0]),
    .sdram_data(DRAM_DQ),
    .sdram_init_done(sdram_ready)     // выход готовности SDRAM
);
         
// формирователь сигнала подверждения транзакции
reg [1:0]dack;

assign sdram_ack = sdram_stb & (dack[1]);

// задержка сигнала подтверждения на 1 такт clk
always @ (posedge clk_p)  begin
   dack[0] <= sdram_stb & (sdr_rd_ack | sdr_wr_ack);
   dack[1] <= sdram_stb & dack[0];
end

//************************************
//*  Управление VGA DAC
//************************************
wire vgagreen,vgared,vgablue;
// выбор яркости каждого цвета  - сигнал, подаваемый на видео-ЦАП для светящейся и темной точки.   
assign video_g = (vgagreen == 1'b1) ? 6'b111111 : 6'b000000 ;
assign video_b = (vgablue == 1'b1)  ? 5'b11111  : 5'b00000 ;
assign video_r = (vgared == 1'b1)   ? 5'b11110  : 5'b00000 ;

//************************************
//* Соединительная плата
//************************************
topboard kernel(

   .clk50(clk50),                   // 50 МГц
   .clk_p(clk_p),                   // тактовая частота процессора, прямая фаза
   .clk_n(clk_n),                   // тактовая частота процессора, инверсная фаза
   .sdclock(sdclock),               // тактовая частота SD-карты
   .clkrdy(clkrdy),                 // готовность PLL
   
   .bt_reset(~button[0]),            // общий сброс
   .bt_halt(~button[1]),             // режим программа-пульт
   .bt_terminal_rst(~button[2]),     // сброс терминальной подсистемы
   .bt_timer(~button[3]),            // выключатель таймера
   
   .sw_diskbank({2'b00,sw[1:0]}),   // выбор дискового банка
   .sw_console(sw[2]),              // выбор консольного порта: 0 - терминальный модуль, 1 - ИРПС 2
   .sw_cpuslow(sw[3]),              // режим замедления процессора
   
   // индикаторные светодиоды      
   .rk_led(rk_led),               // запрос обмена диска RK
   .dw_led(dw_led),               // запрос обмена диска DW
   .my_led(my_led),               // запрос обмена диска MY
   .dx_led(dx_led),               // запрос обмена диска DX
   .timer_led(timer_led),         // индикация включения таймера
   
   // Интерфейс SDRAM
   .sdram_reset(sdram_reset),     // сброс
   .sdram_stb(sdram_stb),         // строб начала транзакции
   .sdram_we(sdram_we),           // разрешение записи
   .sdram_sel(sdram_sel),         // выбор байтов
   .sdram_ack(sdram_ack),         // подтверждение транзакции
   .sdram_adr(sdram_adr),         // шина адреса
   .sdram_out(sdram_out),         // выход шины данных
   .sdram_dat(sdram_dat),         // вход шины данных
   .sdram_ready(sdram_ready),     // флаг готовности SDRAM
   
   // интерфейс SD-карты
   .sdcard_cs(sdcard_cs), 
   .sdcard_mosi(sdcard_mosi), 
   .sdcard_sclk(sdcard_sclk), 
   .sdcard_miso(sdcard_miso), 

   // VGA
   .vgah(vgah),         // горизонтальная синхронизация
   .vgav(vgav),         // вертикакльная синхронизация
   .vgared(vgared),     // красный видеосигнал
   .vgagreen(vgagreen), // зеленый видеосигнал
   .vgablue(vgablue),   // синий видеосигнал

   // PS/2
   .ps2_clk(ps2_clk), 
   .ps2_data(ps2_data),
   
   // пищалка    
   .buzzer(buzzer), 
    
   // дополнительный UART 
   .irps_txd(irps_txd),
   .irps_rxd(irps_rxd),
   
   // LPT
   .lp_data(lp_data),    // данные для передачи к принтеру
   .lp_stb_n(lp_stb_n),  // строб записи в принтер
   .lp_init_n(lp_init_n),// строб сброса
   .lp_busy(lp_busy),    // сигнал занятости принтера
   .lp_err_n(lp_err_n)   // сигнал ошибки
);

//**********************************
//*  MIST
//**********************************

// the configuration string is returned to the io controller to allow
// it to control the menu on the OSD 
parameter CONF_STR = {
			"MC1201_02;;",
			"S0,DSKIMG,Drive 1;",
			"O4,Timer,On,Off;",
			"T3,ODT;",
			"T2,Reset"
};

// the status register is controlled by the on screen display (OSD)
wire [7:0] status;

wire  [31:0] sd_lba;
wire         sd_rd;
wire         sd_wr;
//reg  [31:0] sd_lba;
//reg         sd_rd = 0;
//reg         sd_wr = 0;
wire        sd_conf;
wire        sd_ack;
wire        sd_ack_conf;
wire        sd_sdhc;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din;
wire        sd_buff_wr;
wire        img_mounted;
wire        img_readonly;
wire [31:0] img_size;

parameter CONF_STR_LEN = 9+18+16+7+8;

parameter PS2DIV = 14'd3332;

user_io #(.STRLEN(CONF_STR_LEN),.PS2DIV(PS2DIV)) user_io ( 

		.conf_str   ( CONF_STR ),
		.clk_sys		( clk50 ),
		.clk_sd		( clk50 ),
		.SPI_CLK    ( SPI_SCK    ),
      .SPI_SS_IO  ( CONF_DATA0 ),
      .SPI_MISO   ( SPI_DO     ),
      .SPI_MOSI   ( SPI_DI     ),

		.status     ( status     ),

		.sd_conf(sd_conf),
		.sd_ack(sd_ack),
		.sd_ack_conf(sd_ack_conf),
		.sd_sdhc(sd_sdhc),
		.sd_rd(sd_rd),
		.sd_wr(sd_wr),
		.sd_lba(sd_lba),
		.sd_buff_addr(sd_buff_addr),
		.sd_din(sd_buff_din),
		.sd_dout(sd_buff_dout),
		.sd_dout_strobe(sd_buff_wr),
		
		// ps2 interface
		.ps2_kbd_clk    ( ps2_clk    ),
		.ps2_kbd_data   ( ps2_data   )
);

sd_card sd_card
(
        .clk_sys( clk50 ),
        .img_mounted(img_mounted),
        .img_size(img_size),
        .sd_conf(sd_conf),
        .sd_ack(sd_ack),
        .sd_ack_conf(sd_ack_conf),
        .sd_sdhc(sd_sdhc),
        .sd_rd(sd_rd),
        .sd_wr(sd_wr),
        .sd_lba(sd_lba),
        .sd_buff_addr(sd_buff_addr),
        .sd_buff_din(sd_buff_din),
        .sd_buff_dout(sd_buff_dout),
        .sd_buff_wr(sd_buff_wr),
        .allow_sdhc(1),
        .sd_sck(sdcard_sclk),
        .sd_cs(sdcard_cs),
        .sd_sdi(sdcard_mosi),
        .sd_sdo(sdcard_miso)
);

osd  osd ( 	

		.clk_sys		( clk50 ),
		.ce			(0),
		.rotate		(0),
      .SPI_SCK    ( SPI_SCK  ),
      .SPI_SS3    ( SPI_SS3  ),
      .SPI_DI		( SPI_DI   ),

		.R_in			( video_r  ),
		.G_in			( video_g  ),
		.B_in			( video_b  ),
		.HSync		(vgah),
		.VSync		(vgav),

		.R_out		(vgar),
		.G_out		(vgag),
		.B_out		(vgab)
);

endmodule
