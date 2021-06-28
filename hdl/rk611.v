//
// Реализация дискового контроллера DEC RK611  с дисками RK06/07
//
// Советский аналог - контроллер СМ5408.5112, диск  СМ5408.01(RK06), CM5408.02(RK07)

module rk611 (

// шина wishbone
   input                  wb_clk_i,   // тактовая частота шины
   input                  wb_rst_i,   // сброс
   input    [4:0]         wb_adr_i,   // адрес 
   input    [15:0]        wb_dat_i,   // входные данные
   output reg [15:0]      wb_dat_o,   // выходные данные
   input                  wb_cyc_i,   // начало цикла шины
   input                  wb_we_i,    // разрешение записи (0 - чтение)
   input                  wb_stb_i,   // строб цикла шины
   input    [1:0]         wb_sel_i,   // выбор конкретных байтов для записи - старший, младший или оба
   output reg             wb_ack_o,   // подтверждение выбора устройства

// обработка прерывания   
   output reg             irq,         // запрос
   input                  iack,        // подтверждение
   
// DMA
   output reg             dma_req,    // запрос DMA
   input                  dma_gnt,    // подтверждение DMA
   output reg[17:0]       dma_adr_o,  // выходной адрес при DMA-обмене
   input[15:0]            dma_dat_i,  // входная шина данных DMA
   output reg[15:0]       dma_dat_o,  // выходная шина данных DMA
   output reg             dma_stb_o,  // строб цикла шины DMA
   output reg             dma_we_o,   // направление передачи DMA (0 - память->диск, 1 - диск->память) 
   input                  dma_ack_i,  // Ответ от устройства, с которым идет DMA-обмен
   
// интерфейс SD-карты
   output                 sdcard_cs, 
   output                 sdcard_mosi, 
   output                 sdcard_sclk, 
   input                  sdcard_miso, 
   output reg             sdreq,      // запрос доступа к карте
   input                  sdack,      // подтверждение доступа к карте
   input                  sdmode,     // режим SDSPI
   
// тактирование SD-карты
   input                  sdclock,   

// Адрес начала банка на карте
   input [26:0]           start_offset,
   
// отладочные сигналы
   output [3:0]           sdcard_debug
   ); 
//------------------------------------------------------
// Геометрия диска:
// 815 цилиндров
// 3 головки
// 22 сектора на дорожку
//
//
// Регистры устройства
// 
// 777440  rkcs1 - регистр управления/состояния 1
//           0  R/W GO         запуск команды
//         1-4  R/W FUNC       код команды
//           5  0
//           6  R/W IE         разрешение прерывания
//           7  R/O RDY        готовность контроллера
//         8-9  R/W BA16-BA17  расширение адреса для DMA
//          10  R/W CDT        тип устройства: 0-RK06, 1-RK07
//          11  R/O CTO        таймаут выполнения команды         
//          12  R/W CFMT       формат сектора (16, 18 бит). У на всегда будет 0, 16 бит. 
//          13  R/O DCT PAR    ошибка четности при передааче от устройства к контроллеру      
//          14  R/O DI         0 - прерывание от контроллера, 1 - от устройства       
//          15  R/W CERR/OCLR      чтение - 1- признак ошибки, запись 1 - сброс контроллера
//
// 777442  RKWC - счетчик слов для обмена данными
//
// 777444  RKBA - биты 0-15 адреса общей шины для DMA
//
// 777446  RKDA - адрес дорожки и сектора
//         0-4   SA  адрес сектора
//         8-10  TA  номер дорожки (головки)
// 
// 777450  rkcs2 - регистр управления/состояния 2
//          0-2  R/W DS    выбор номер привода
//            3  R/W RLS   разрешение отключения привода от шины после начала операции
//            4  R/W BAI   1 - адрес на шине не  увеличивается после каждой транзакции обмена данными
//            5  W/O SCLR  1 - сброс контроллера и всех устройств
//            6  R/O IR    1 - буфер silo готов к приему данных
//            7  R/O OR    1 - буфер silo готов к выдаче данных  
//            8  R/O UPE   ошибка протокола обмена данными между контроллером и устройством
//            9  R/O MDS   ошибка множественно выбора активного устройства
//           10  R/O PGE   попытка записи регистра в процессе выполнения команды
//           11  R/O NEM   таймаут шины при DMA
//           12  R/O NED   выбранное устройство отсутствует
//           13  R/O UPE   ошибка четности при обмене по шине
//           14  R/O WCE   ошибка при верификации записи
//           15  R/O DLT   ошибка переполнения/переопустошения буфера
//
// 777452  RKDS (R/O) - регистр состояния устройства
//            0  DRA    доступность устройства
//            1  0  
//            2  OFST   признак включенного режима смещения
//            3  ACLO   авария источника питания привода
//            4  SPLS   низкая скорость шпинделя
//            5  DROT   off track - попытка записи, когда головка не находится по центрк дорожки 
//            6  VV     не было замены дискового картриджа
//            7  DRDY   готовность устройства
//            8  DDT    0 - RK06, 1 - RK07
//            9  0
//           10  0
//           11  WRL    диск аппаратно защищен от записи
//           12  0
//           13  PIP    устройство находится в состоянии позиционирования
//           14  CDA    выбранное устройство подняло сигнал "внимание"
//           15  SVAL   достоверность состояния устройства

//
// 777454  RKER (R/O) - регистр ошибок
//            0  ILF    недопустимый код функции 
//            1  SKI    позиционирование не завершено - неправильно задан CHS
//            2  NXF    невыполнимая функция, попытка выполнить позиционирование при VV=0
//            3  DRPAR  ошибка четности при обмене контроллера и устройства
//            4  FMTE   установлен диск неправильного формата
//            5  DTYPE  несоответствие типа устройства
//            6  ECH    неисправимая ошибка ЕСС
//            7  BSE    попытка обмена с плохим блоком
//            8  HRVC   ошибка в заголовке сектора
//            9  COE    выход за границу диска в процессе передачи данных
//           10  IDAE   неправильно задан CHS
//           11  WLE    попытка записи на защищенный диск
//           12  DTE    потеря синхронизации устройством
//           13  OPI    ошибка позиционирования, не найден ни один заголовок сектора
//           14  DNS    устройство находится в нестабильном состоянии
//           15  DCK    ошибка чтения сектора
//
// 777456  RKAS/OF - регистр сигналов "внимание" приводов и смещения
//           0-7   смещение головки от центра дорожки
//           8-15  сигнал "внимание" для каждого привода
//
// 777460  RKDC - регистр номера цилиндра
//          0-9 номер цилиндра
//
// 777464  RKDB - регистр буфера данных
//
// 777466  RKMR1 - диагностический регистр 1
//          0-3  R/W MS0-MS3, выбор номера линии сообщения Message A или B  
//            4  R/W PAT      принудительная генерация четного режима при обмене с устройством
//            5  R/W DMD      включение диагностического режима
//            6  R/W MSP      эмуляция секторного импульса
//            7  R/W MIND     эмуляция индексного импульса
//            8  R/W MCLK     импульсы синхронизации, в диагностическом режиме заменяют основной клок контроллера
//            9  R/W MERD     эмуляция последовательности читаемых данных
//           10  R/W MEWD     эмуляция последовательности записываемых данных
//           11  R/O PCA      предкомпенсация включена
//           12  R/O PCD      задержка предкомпенсации
//           13  R/O ECCW
//           14  R/O WRTGT    включен усилитель записи
//           15  R/O RDGT     включен усилитель чтения
//
// 777470  RKECPS (R/O)- регистр позиции ECC
//
// 777472  RKECPT (R/O) - регистр образца ЕСС
// 
// 777474  RKMR2 (R/O) - диагностический регистр 2
//
// 777476   RKMR3 (R/O) - диагностический регистр 3
//
//
//  Коды функций
// 0000  выбор устройства
// 0001  подтверждение установки тома
// 0010  очистка ошибок устройства
// 0011  разгрузка тома
// 0100  запуск шпинделя
// 0101  рекалибровка - уход в CHS=0
// 0110  установка смещения
// 0111  позиционирование
// 1000  чтение данных
// 1001  запись данных
// 1010  чтение заголовков
// 1011  запись заголовков
// 1100  верификация записи
//


// Сигналы упраления обменом с шиной

wire bus_strobe = wb_cyc_i & wb_stb_i;         // строб цикла шины
wire bus_read_req = bus_strobe & ~wb_we_i;     // запрос чтения
wire bus_write_req = bus_strobe & wb_we_i;     // запрос записи
wire reset=wb_rst_i;

// состояние машины обработки прерывания
parameter[1:0] i_idle = 0; 
parameter[1:0] i_req = 1; 
parameter[1:0] i_wait = 2; 
reg[1:0] interrupt_state; 
reg int_req; 

// регистр управления/состояния 1 - rkcs1 - 177440
reg rkcs1_go;             // запуск команды
reg[3:0] rkcs1_fu;        // код функции
reg rkcs1_ie;             // разрешение прерывания
wire rkcs1_rdy=~start;    // готовность контроллера
reg[1:0] rkcs1_mex;       // расширение адреса
reg rkcs1_cdt;            // тип устройства - 0=RK-6, 1=RK07
reg rkcs1_di;             // источник прерывания
wire rkcs1_cerr;          // сборная линия ошибок
// счетчик пересылаемых слов - rkwc - 777442
reg[15:0] rkwc; 

// физический адрес буфера в памяти - rkba - 177444
reg[15:0] rkba; 

// 777446  RKDA - адрес дорожки и сектора
reg [2:0] rkda_hd;             // головка
reg[4:0] rkda_sc;        // сектор


// 777450  rkcs2 - регистр управления/состояния 2
reg [2:0] devnum;
reg rkcs2_bai;
reg rkcs2_sclr;
reg rkcs2_pge;
reg rkcs2_nem;

// 777452  RKDS (R/O) - регистр состояния устройства
reg [7:0] rkds_vv;
reg [7:0] rkds_cda;

// регистр ошибок - rker - 777454
reg rker_ilf;
reg rker_ski;
reg rker_nxf;
reg rker_coe;
reg rker_idae;
reg rker_dck;
reg rker_dtype;

// 777456  RKAS/OF - регистр сигналов "внимание" приводов и смещения
reg [7:0] rkas;

// 777460  RKDC - регистр номера цилиндра
//          0-9 номер цилиндра
reg [9:0] rkdc;

// регистр данных - rkdb - 777464
reg[15:0] rkdb; 

reg start;               // флаг запуска команды
reg update_rkwc;         // признак обновления счетчика слов
reg[15:0] wcp;           // счетчик читаемых слов, положительный (не инверсия)
reg[17:1] ram_phys_addr; // адрес для DMA-обмена
reg write_start;         // запуск записи
reg read_start;          // запуск чтения
reg iocomplete;          // признак завершения работы DMA-контроллера
reg [5:0] reply_count;   // таймер ожидания ответа при DMA-обмене
reg start_latch; 

assign rkcs1_cerr=rker_ilf | rker_ski | rker_nxf | rker_coe | rker_idae | rker_dck | rker_dtype;
 
// регистры контроллера DMA
reg nxm;                    // признак таймаута шины
reg[8:0] sector_data_index; // указатель текущего слова в секторном буфере
// машина состояний контроллера
parameter[3:0] DMA_idle = 0; 
parameter[3:0] DMA_read = 1; 
parameter[3:0] DMA_preparebus = 4; 
parameter[3:0] DMA_read_done = 5; 
parameter[3:0] DMA_write1 = 6; 
parameter[3:0] DMA_write = 7; 
parameter[3:0] DMA_write_fill = 8; 
parameter[3:0] DMA_write_wait = 9; 
parameter[3:0] DMA_write_done = 10; 
parameter[3:0] DMA_wait = 11; 
parameter[3:0] DMA_write_delay = 12; 
parameter[3:0] DMA_readsector = 13; 

reg[3:0] DMA_state; 

reg [8:0] dma_datacounter;

// интерфейс к SDSPI
wire [26:0] sdaddr;            // адрес сектора карты 
reg  [26:0] sdcard_addr;       // буфер для хранения вычисленного адреса
wire sdcard_error;             // флаг ошибки
wire [15:0] sdbuf_dataout;     // слово; читаемое из буфера чтения
wire sdcard_idle;              // признак готовности контроллера
reg [7:0] sdbuf_addr;          // адрес в буфере чтния/записи
reg sdbuf_we;                  // строб записи буфера
reg [15:0] sdbuf_datain;       // слово; записываемое в буфер записи
reg sdspi_start;               // строб запуска sdspi
reg sdspi_write_mode;          // 0-чтение, 1-запись
wire sdspi_io_done;            // флаг заверщение операции обмена с картой

//***********************************************
//*  Контроллер SD-карты
//***********************************************
sdspi sd1 (
      // интерфейс к карте
      .sdcard_cs(sdcard_cs), 
      .sdcard_mosi(sdcard_mosi), 
      .sdcard_miso(sdcard_miso),
      .sdcard_sclk(sdcard_sclk),
      
      .sdcard_debug(sdcard_debug),                // информационные индикаторы   
   
      .sdcard_addr(sdcard_addr),                  // адрес блока на карте
      .sdcard_idle(sdcard_idle),                  // сигнал готовности модуля к обмену
      .sdcard_error(sdcard_error),                // флаг ошибки
      
      // сигналы управления чтением - записью
      .sdspi_start(sdspi_start),                // строб запуска ввода вывода
      .sdspi_io_done(sdspi_io_done),            // флаг окончания обмена данными
      .sdspi_write_mode(sdspi_write_mode),      // режим: 0 - чтение, 1 - запись

      // интерфейс к буферной памяти контроллера
      .sdbuf_addr(sdbuf_addr),                 // текущий адрес в буферах чтения и записи
      .sdbuf_dataout(sdbuf_dataout),           // слово, читаемое из буфера чтения
      .sdbuf_datain(sdbuf_datain),             // слово, записываемое в буфер записи
      .sdbuf_we(sdbuf_we),                     // строб записи буфера

      .mode(sdmode),                               // режим ведущего-ведомого контроллера
      .controller_clk(wb_clk_i),                   // синхросигнал общей шины
      .reset(reset),                               // сброс
      .sdclk(sdclock)                              // синхросигнал SD-карты
); 

 
//**************************************
//*  Сигнал ответа 
//**************************************
always @(posedge wb_clk_i or posedge wb_rst_i)
    if (wb_rst_i == 1) wb_ack_o <= 1'b0;
    else if (wb_stb_i) wb_ack_o <= 1'b1;
	 else wb_ack_o <= 1'b0;


//**************************************************************
// Логика обработки прерываний и интерфейс к общей шине
//**************************************************************
always @(posedge wb_clk_i)  begin
	if (reset | rkcs2_sclr) begin

   	// сброс системы
		interrupt_state <= i_idle ; 
		int_req <= 1'b0 ; 
		start_latch <= 1'b0;

		rker_ski <= 1'b0 ; 
		rker_nxf <= 1'b0 ; 
		rker_coe <= 1'b0 ; 
		rker_ilf <= 1'b0 ; 
		rker_idae <= 1'b0 ; 
		rker_dck <= 1'b0;
		rker_dtype <= 1'b0;

		rkba <= {16{1'b0}} ; 

		rkcs1_ie <= 1'b0 ; 
		rkcs1_mex <= 2'b00 ; 
		rkcs1_fu <= 4'b0000 ; 
		rkcs1_go <= 1'b0 ; 
		rkcs1_di <= 1'b0;
      rkcs1_cdt <= 1'b1;    // тип привода по умолчанию - RK07
		
		rkda_hd <= 3'b000 ; 
		rkda_sc <= {4{1'b0}} ; 

		rkwc <= {16{1'b0}} ; 
		update_rkwc <= 1'b1 ; 

		devnum <= 3'b000;
		rkcs2_bai <= 1'b0;
		rkcs2_sclr <= 1'b0;
		rkcs2_pge <= 1'b0;
		rkcs2_nem <= 1'b0;

		rkds_vv <= 8'o0;
		rkds_cda <= 8'o0;

		rkas <= 8'o0;
		rkdc <= 10'o0;

		start <= 1'b0 ; 
		irq <= 1'b0 ;    // снимаем запрос на прерывания
		sdreq <= 1'b0;
		read_start <= 1'b0;
		write_start <= 1'b0;
	end
	
	// рабочие состояния
	else   begin
	  //******************************
	  //* обработка прерывания
	  //******************************
			case (interrupt_state)
				 // нет активного прерывания
			  i_idle :
							begin
								// Проверка флага запроса прерывания
								if (rkcs1_ie & int_req)  begin
									interrupt_state <= i_req ; 
									irq <= 1'b1 ;    // запрос на прерывание
									int_req <= 1'b0 ;  // снимаем флаг запроса прерывания
								end 
								else irq <= 1'b0 ;    // снимаем запрос на прерывания                           
							end
				// Формирование запроса на прерывание         
				i_req :
							begin
								if (rkcs1_ie == 1'b1) begin                           
									// если прерывания вообще разрешены
									if (iack == 1'b1) begin
										// если получено подтверждение прерывания от процессора
										irq <= 1'b0 ;               // снимаем запрос
										interrupt_state <= i_wait ; // переходим к ожиданию окончания обработки
									end 
								end
								
								else begin                           
								  // если прерывания запрещены
									interrupt_state <= i_idle ; 
								end 
							end
							
							
				// Ожидание окончания обработки прерывания         
				i_wait :   if (iack == 1'b0)  interrupt_state <= i_idle ; 
				endcase

		 //*********************************************
		 //* поиск источника прерывания
		 //*********************************************
		 // поднимаем запрос прерывания при переходе START из 0 в 1
		 if ((start_latch != start) & (start == 1'b0) & rkcs1_ie) int_req <= 1'b1;     // поднимаем запрос прерывания
		 start_latch <= start;   // сохраняем предыдущее значение START
																
		 //*********************************************
		 //* Обработка шинных транзакций 
		 //*********************************************            

		 // чтение регистров
		 if (bus_read_req == 1'b1)   begin
				case (wb_adr_i[4:1])
					// 777440  rkcs1 - регистр управления/состояния 1 
					//                            15       14       13   12     11          10       8-9         7        6         5     1-4        0
					4'b0000 :   wb_dat_o <= {rkcs1_cerr, rkcs1_di, 1'b0, 1'b0, 1'b0, rkcs1_cdt, rkcs1_mex, rkcs1_rdy, rkcs1_ie, 1'b0, rkcs1_fu, rkcs1_go} ;
					// 777442  RKWC - счетчик слов для обмена данными
					4'b0001 :   wb_dat_o <= ~(wcp-1'b1); //rkwc;
					// физический адрес буфера в памяти - rkba - 177444
					4'b0010 :   wb_dat_o <= rkba;
					// 777446  RKDA - адрес дорожки и сектора
					4'b0011 :   wb_dat_o <= {5'b00000, rkda_hd, 3'b000, rkda_sc};
					// 777450  rkcs2 - регистр управления/состояния 2
					4'b0100 :   wb_dat_o <= {4'b0000, rkcs2_nem, rkcs2_pge, 4'b0000, 1'b0, rkcs2_bai, 1'b0, devnum};
					// 777452  RKDS (R/O) - регистр состояния устройства
					4'b0101 :   wb_dat_o <= {1'b1, rkds_cda[devnum], 5'o0, 1'b1, 1'b1, rkds_vv[devnum], 5'o0, 1'b1};
					// 777454  RKER (R/O) - регистр ошибок
					4'b0110 :   wb_dat_o <= {rker_dck, 4'o0, rker_idae, rker_coe, 3'b000, rker_dtype, 2'b00, rker_nxf, rker_ski, rker_ilf};
					// 777456  RKAS/OF - регистр сигналов "внимание" приводов и смещения
					4'b0111 :   wb_dat_o <= {rkas, 8'o0};
					// 777460  RKDC - регистр номера цилиндра
					4'b1000 :   wb_dat_o <= {6'o0,rkdc};
					// регистр данных - rkdb - 777464
					4'b1010 :   wb_dat_o <= rkdb;
				 
					default :  wb_dat_o <= {16{1'b0}} ; 
				endcase 
			end
		
			// запись регистров   
			if (bus_write_req)  begin
			 // если контроллер не занят выполнением команды
          if (~start) begin 			
				// запись четных байтов
				if (wb_sel_i[0] == 1'b1)  begin
					case (wb_adr_i[4:1])
					// 777440  rkcs1 - регистр управления/состояния 1
					4'b0000 :  begin  
										rkcs1_go <= wb_dat_i[0] ;    // флаг запуска команды на выполнение
										if (wb_dat_i[0]) begin  
											 // снимаем флаги ошибок
											 rkcs2_pge <= 1'b0;
											 rkcs2_nem <= 1'b0;
											 rker_ilf <= 1'b0; 
										end	 
										rkcs1_fu <= wb_dat_i[4:1] ;      // код команды
										rkcs1_ie <= wb_dat_i[6] ;       // разрешение прерываний
										// программная симуляция прерывания - принудительная установка IE и RDY
										if (wb_dat_i[7:6] == 2'b11) int_req <= 1'b1;
									end
					// 777442  RKWC - счетчик слов для обмена данными
					4'b0001 :   begin 
										rkwc[7:0] <= wb_dat_i[7:0];
										update_rkwc <= 1'b1 ;  // поднимаем признак изменения RKWC 
									end
					// физический адрес буфера в памяти - rkba - 177444
					4'b0010 :   rkba[7:0] <= wb_dat_i[7:0];
					// 777446  RKDA - адрес дорожки и сектора
					4'b0011 :   rkda_sc <= wb_dat_i[4:0];
					// 777450  rkcs2 - регистр управления/состояния 2
					4'b0100 :   begin
									 devnum <= wb_dat_i[2:0];
									 rkcs2_bai <= wb_dat_i[4];
 									 rkcs2_sclr <= wb_dat_i[5] ; 
									end                              
					// 777460  RKDC - регистр номера цилиндра
					4'b1000 :   rkdc[7:0] <= wb_dat_i[7:0];
					// регистр данных - rkdb - 777464
					4'b1010 :   rkdb[7:0] <= wb_dat_i[7:0];
						
					endcase 
				end 
				
				// запись нечетных байтов
				if (wb_sel_i[1] == 1'b1) begin
				 case (wb_adr_i[4:1])
					// 777440  rkcs1 - регистр управления/состояния 1
					4'b0000 :  begin  
										rkcs1_mex <= wb_dat_i[9:8];
								//		rkcs1_cdt <= wb_dat_i[10];
										rkcs2_sclr <= wb_dat_i[15] ; 
								  end
									
					// 777442  RKWC - счетчик слов для обмена данными
					4'b0001 :   begin 
										rkwc[15:8] <= wb_dat_i[15:8];
										update_rkwc <= 1'b1 ;  // поднимаем признак изменения RKWC 
									end
					// физический адрес буфера в памяти - rkba - 177444
					4'b0010 :   rkba[15:8] <= wb_dat_i[15:8];
					// 777446  RKDA - адрес дорожки и сектора
					4'b0011 :   rkda_hd <= wb_dat_i[10:8];
					// 777460  RKDC - регистр номера цилиндра
					4'b1000 :   rkdc[9:8] <= wb_dat_i[9:8];
					// регистр данных - rkdb - 777464
					4'b1010 :   rkdb[15:8] <= wb_dat_i[15:8];
					endcase 
				end 
			 end
			
			 // запись во время выполнения команды
			 else begin
			   // разрешены только сбросы
			  if ((wb_adr_i[4:1] == 4'b0000 && wb_dat_i[15] == 1'b1) ||
			      (wb_adr_i[4:1] == 4'b0100 && wb_dat_i[5] == 1'b1) ) rkcs2_sclr <= 1'b1;
			  else rkcs2_pge <= 1'b1;
			 end
			end 
			
			// обновление RKWC 
			if (update_rkwc)  begin
				wcp <= (~rkwc) + 1'b1 ;  // вычисляем значение счетчика, обратное от  записанного в RKWC
				update_rkwc <= 1'b0 ;    // синмаем флаг запроса обновления RKWC
			end
			
			// запуск команды на выполнение            
			if (start == 1'b0 & rkcs1_go & ~wb_stb_i)  begin
					start <= 1'b1 ;  // запускаем команду в обработку
					rkcs1_go <= 1'b0;
			end 

		
			// запуск обработки команды
			  if (start == 1'b1)  begin
			   // проверка установленного типа устройства
			   if (rkcs1_cdt == 1'b0) begin 
				   rker_dtype <= 1'b1;
					start <= 1'b0;
				end	
				// выбор действия по коду функции 
				else case (rkcs1_fu)  
				//------------------------------------------------------------
					4'b0000,   // выбор устройства 
					4'b0100,   // запуск шпинделя
					4'b0101,   // рекалибровка
					4'b0110:   // установка смещения
								 begin
									start <= 1'b0 ;     // прекращаем обработку команды
								 end
							  
				//------------------------------------------------------------
				// подтверждение установки тома
					4'b0001:    begin   
										rkds_vv[devnum] <= 1'b1;
										start <= 1'b0;
									end	
				//------------------------------------------------------------
				// очистка ошибок
					4'b0010:    begin   
										rker_ski <= 1'b0 ; 
										rker_nxf <= 1'b0 ; 
										rker_coe <= 1'b0 ; 
										rker_idae <= 1'b0 ; 
										rker_dck <= 1'b0;
										rkds_cda[devnum] <= 1'b0;
										rkas[devnum] <= 1'b0;
										start <= 1'b0;
									end							  
				//------------------------------------------------------------
				// разгрузка тома
					4'b0011:    begin
										rkds_vv[devnum] <= 1'b0;
										start <= 1'b0;
									end				                 			
				//------------------------------------------------------------
				// позиционирование
					4'b0111:    begin
											if ((rkdc > 10'd814) |
												 (rkda_hd > 3'd2) |
												 (rkda_sc > 5'd21))   begin
													 rker_idae <= 1'b1 ; 
													 rker_ski <= 1'b1 ; 
											end
											start <= 1'b0 ;     // прекращаем обработку команды
										   rkds_cda[devnum] <= 1'b1;
										   rkas[devnum] <= 1'b1;
									end						
				//------------------------------------------------------------
				// запись         
					4'b1001:    begin   
					            // снимаем сигнал внимание
								   rkds_cda[devnum] <= 1'b0;
								   rkas[devnum] <= 1'b0;
									sdreq <= 1'b1;   // запрашиваем доступ к SD-карте
									// подтверждение доступа к карте получено
									if (sdack) begin
									// запись еще не запущена, SD-карта готова к  работе
										if (sdcard_idle == 1'b1 & write_start == 1'b0) begin
											
											// проверка параметров CHS
											if ((rkdc > 10'd814) |
												 (rkda_hd > 3'd2) |
												 (rkda_sc > 5'd21))   begin
													 rker_idae <= 1'b1 ; 
													 rker_ski <= 1'b1 ; 
													 start <= 1'b0 ;     // прекращаем обработку команды
											end

											// проверки окончены - запускаем запись
											else  begin
												write_start <= 1'b1 ; 
											end   
										end
										
										// запись сектора завершена
										else if (write_start == 1'b1 & iocomplete == 1'b1) begin
											write_start <= 1'b0 ;              // снимаем флаг запуска записи
											if (nxm == 1'b0 & sdcard_error == 1'b0)  begin
											
												// запись окончилась без ошибок 
												rkcs1_mex <= ram_phys_addr[17:16] ;  // адрес окончания записи - старшая часть, пока, увы, не нужна
												rkba <= {ram_phys_addr[15:1], 1'b0} ;  // младшая часть
												
												// ----- переход к следующему сектору -----
												if (rkda_sc != 5'd21)  rkda_sc <= rkda_sc + 1'b1 ; // увеличиваем # сектора 
												else  begin
													// переход на новую дорожку
													rkda_sc <= 5'd0 ; // обнуляем номер сектора
													if (rkda_hd != 3'd2) rkda_hd <= rkda_hd + 1'b1 ; // новая головка
													else  begin
														// переход на новый цилиндр
														if ((rkdc == 10'd815) & (wcp > 16'b0000000100000000))  begin
															// вышли за пределы диска 312 цилиндров
															rker_ski <= 1'b1 ;   // ошибка позиционирования
															rker_coe <= 1'b1 ;   // ошибка OVR
															start <= 1'b0 ; 
														end
														else  begin
															// до границы диска не доехали
															rkdc <= rkdc + 1'b1 ; // цилиндр++
															rkda_hd <= 3'd0 ; // переходим на головку 0
														end 
													end 
												end 
												 
												// переход к записи следующего сектора
												   wcp <= wcp - dma_datacounter;
													if ((wcp - dma_datacounter) == 16'o0) begin
														// запись завершена
														start <= 1'b0 ;       // прекращаем обработку команды
													end 
											end
											
											// обработка ошибок записи
											else begin
												rkcs1_mex <= ram_phys_addr[17:16] ; 
												rkba <= {ram_phys_addr[15:1], 1'b0} ; 
												if (nxm == 1'b1)  rkcs2_nem <= 1'b1 ; // ошибка NXM - запись в несуществующую память
												if (sdcard_error == 1'b1) rker_dck <= 1'b1 ;   // ошибка SD-карты
												start <= 1'b0;  // завершаем обработку команды
											end 
										end 
									end 
								end
								
				//------------------------------------------------------------
				// чтение        
					4'b1000 :
								begin
					            // снимаем сигнал внимание
								   rkds_cda[devnum] <= 1'b0;
								   rkas[devnum] <= 1'b0;
									sdreq <= 1'b1;    // запрашиваем доступ к карте
									if (sdack) begin   // разрешение на доступ к карте получено
										//-------------------------------------------------------------------  
										// если SD-модуль свободен, чтение еще не запущено и не завершено
										if (iocomplete == 1'b0 & read_start == 1'b0) begin
											// проверка параметров CHS
											if ((rkdc > 10'd814) |
												 (rkda_hd > 3'd2) |
												 (rkda_sc > 5'd21))   begin
													 rker_idae <= 1'b1 ; 
													 rker_ski <= 1'b1 ; 
													 start <= 1'b0 ;     // прекращаем обработку команды
											end
											// проверка окончена - запускаем чтение SD
											else  begin
												 read_start <= 1'b1;         // запускаем sdspi
											end    
										end
										
										//-------------------------------------------------------------------  
										// sdspi закончил свою работу
										else if (read_start == 1'b1 & iocomplete == 1'b1) begin
											read_start <= 1'b0;
											if (nxm == 1'b0 & sdcard_error == 1'b0)   begin
												// чтение завершено без ошибок
												rkcs1_mex <= ram_phys_addr[17:16] ; 
												rkba <= {ram_phys_addr[15:1], 1'b0} ; // адрес буфера к ОЗУ хоста
												  
												// ----- переход к следующему сектору -----
												if (rkda_sc != 5'd21)  rkda_sc <= rkda_sc + 1'b1 ; // увеличиваем # сектора 
												else  begin
													// переход на новую дорожку
													rkda_sc <= 5'd0 ; // обнуляем номер сектора
													if (rkda_hd != 3'd2) rkda_hd <= rkda_hd + 1'b1 ; // новая головка
													else  begin
														// переход на новый цилиндр
														if ((rkdc == 10'd815) & (wcp > 16'b0000000100000000))  begin
															// вышли за пределы диска 312 цилиндров
															rker_ski <= 1'b1 ;   // ошибка позиционирования
															rker_coe <= 1'b1 ;   // ошибка OVR
															start <= 1'b0 ; 
														end
														else  begin
															// до границы диска не доехали
															rkdc <= rkdc + 1'b1 ; // цилиндр++
															rkda_hd <= 3'd0 ; // переходим на головку 0
														end 
													end 
												end 
												
												// чтение сектора завершено - переходим к новому сектору
												   wcp <= wcp - dma_datacounter;
													if ((wcp - dma_datacounter) == 16'o0) begin
														// чтение завершено
														start <= 1'b0 ;       // прекращаем обработку команды
													end 
											end 
											
											else  begin
												// обработка ошибок чтения
												rkcs1_mex <= ram_phys_addr[17:16] ; 
												rkba <= {ram_phys_addr[15:1], 1'b0} ; 
												if (nxm == 1'b1)  rkcs2_nem <= 1'b1 ; // ошибка NXM - запись в несуществующую память
												if (sdcard_error == 1'b1) rker_dck <= 1'b1 ;   // ошибка SD-карты
												start <= 1'b0;
											end 
										 end
									end 
								end  
								
								
				//------------------------------------------------------------
				// проверка читаемости
					4'b1100 :
								begin
								// проверка параметров CHS
								 if ((rkdc > 10'd814) |
									  (rkda_hd > 3'd2) |
									  (rkda_sc > 5'd21))   begin
													 rker_idae <= 1'b1 ; 
													 rker_ski <= 1'b1 ; 
													 start <= 1'b0 ;     // прекращаем обработку команды
								  end

								  if (wcp > 16'o400)   wcp <= wcp - 16'o400; 
								  else   begin
										wcp <= {16{1'b0}} ; 
										rkwc <= {16{1'b0}} ; 
										start <= 1'b0 ; 
								  end 
								end
								
				//------------------------------------------------------------
				// неподдерживаемые команды
					default :
								begin
									start <= 1'b0 ; 
									rker_ilf <= 1'b1; // ошибка - недопустимый код функции
								end
				endcase 
			end

			// Активной команды нет - переход в начальное состояние
			else  begin
				sdreq <= 1'b0;            // снимаем запрос доступа к SD-карте
			end 
	end  
end 


// DMA и работа с картой памяти
//---------------------------------------
always @(posedge wb_clk_i)  begin
    if (reset == 1'b1)  begin
        // сброс
        DMA_state <= DMA_idle ; 
        dma_req <= 1'b0 ; 
        sdspi_write_mode <= 1'b0 ; 
        sdspi_start <= 1'b0;
        nxm <= 1'b0 ; 
        iocomplete <= 1'b0;
    end
    
    // рабочие состояния
    else  begin
            case (DMA_state)
            // ожидание запроса
            DMA_idle :
                        begin
                        nxm <= 1'b0 ; //  снимаем флаг ошибки nxm
                        // старт процедуры записи
                        if (write_start == 1'b1) begin
									 sdcard_addr <= sdaddr;                   // получаем адрес SD-сектора                
                            dma_req <= 1'b1 ;                        // поднимаем запрос DMA
                            if (dma_gnt == 1'b1) begin               // ждем подтверждения DMA
                                DMA_state <= DMA_write1 ; // переходим к этапу 1 записи
                                ram_phys_addr <= {rkcs1_mex, rkba[15:1]};          // полный физический адрес памяти
                                
                                // вычисление количества байтов в текущем секторе (передача может быть неполной)
                                if (wcp >= 16'o400) begin
										     sector_data_index <= 9'o400;               // запрошен полный сектор или больше
											  dma_datacounter <= 9'o400;
										  end  
                                else begin
  										     sector_data_index <= {1'b0, wcp[7:0]} ;    // запрошено меньше сектора
											  dma_datacounter <=  {1'b0, wcp[7:0]} ;
										  end	  
                                sdbuf_addr <= 8'b11111111 ;                              // адрес в буфере sd-контроллера
                            end 
                        end
                        // старт процедуры чтения
                        else if (read_start == 1'b1) begin
									     sdcard_addr <= sdaddr;                       // получаем адрес SD-сектора   
                                DMA_state <= DMA_readsector;                 // переходим к чтению данных
                                // коррекция счетчика читаемых слов
                                if (wcp >= 16'o400)  sector_data_index <= 9'o400;             // запрошен сектор и больше
                                else                 sector_data_index <= {1'b0, wcp[7:0]} ;  // запрошено меньше сектора
                                sdbuf_addr <= 0 ;                                       // начальный адрес в буфере SD-контроллера
                        end 
                        else iocomplete <= 1'b0;
                        end
                                                
                        // чтение данных с карты в буфер SDSPI 
            DMA_readsector:         
                       begin
								dma_datacounter <= sector_data_index;
                        sdspi_start <= 1'b1;          // запускаем SDSPI
                        sdspi_write_mode <= 1'b0;     // режим чтения
                        if (sdspi_io_done == 1'b1) begin
                            dma_req <= 1'b1 ;                        // поднимаем запрос DMA
                            ram_phys_addr <= {rkcs1_mex, rkba[15:1]};  // полный физический адрес буфера в ОЗУ
                            if (dma_gnt == 1'b1)  begin              // ждем подтверждения DMA
                                    DMA_state <= DMA_preparebus; // sdspi закончил работу
                            end	
                        end 
                       end   
                        
                        // чтение данных - подготовка шины к DMA
            DMA_preparebus :
                        begin
                        sdspi_start <= 1'b0;
                        DMA_state <= DMA_read ; 
                        dma_adr_o <= {ram_phys_addr[17:1], 1'b0} ; // выставляем адрес на шину
                        dma_stb_o <= 1'b0 ;                        // снимаем строб данных 
                        dma_we_o <= 1'b0 ;                         // снимаем строб записи
                        reply_count <= 6'b111111;                  // взводим таймер ожидания шины
                                DMA_state <= DMA_read ; // переходим к чтению заголовков
                        end
                        // чтение данных - обмен по шине
            DMA_read :
                        begin
                        if (sector_data_index != 9'o0)  begin
                            // передача данных сектора
                            dma_dat_o <= sdbuf_dataout ;             // выставляем данные
                            dma_we_o <= 1'b1;               // режим записи
                            dma_stb_o <= 1'b1 ;             // строб записи на шину
                            reply_count <= reply_count - 1'b1; // таймер ожидания ответа
                            if (|reply_count == 1'b0) begin
                                // таймаут шины
                                nxm <= 1'b1;
                                DMA_state <= DMA_read_done ; 
                            end  
                            if (dma_ack_i == 1'b1) begin   // устройство подтвердило обмен
                                DMA_state <= DMA_preparebus; 
                                if (rkcs2_bai == 1'b0) ram_phys_addr <= ram_phys_addr + 1'b1 ; // если разрешено, увеличиваем физический адрес
                                sector_data_index <= sector_data_index - 1'b1 ;       // уменьшаем счетчик данных сектора
                                sdbuf_addr <= sdbuf_addr + 1'b1 ;         // увеличиваем адрес буфера SD
                            end    
                        end
                        else begin
                            // все сектора прочитаны 
                            DMA_state <= DMA_read_done ; 
                            dma_stb_o <= 1'b0 ; 
                            dma_we_o <= 1'b0 ; 
                        end 
                        end
            DMA_read_done :
                        begin
                        dma_req <= 1'b0 ;        // освобождаем шину
                        dma_stb_o <= 1'b0 ; 
                        dma_we_o <= 1'b0 ; 
                        if (read_start == 1'b0) begin
                            DMA_state <= DMA_idle ; // переходим в состояние ожидания команды
                            iocomplete <= 1'b0;                 // снимаем подтверждение окончания работы
                        end 
                        else iocomplete <= 1'b1;  // подтверждаем окончание обмена
                        end
                        
            // этап 1 записи - подготовка шины к DMA
            DMA_write1 :
                        begin
                            sector_data_index <= sector_data_index - 1'b1 ; // уменьшаем счетчик записанных данных
                            sdbuf_we <= 1'b1 ;         // поднимаем флаг режима записи sdspi
                            dma_we_o <= 1'b0 ; 
                            sdbuf_addr <= sdbuf_addr + 1'b1 ; // адрес буфера sdspi++
                            dma_stb_o <= 1'b1 ;  // поднимаем строб чтения
                            if (rkcs2_bai == 1'b0)  ram_phys_addr <= ram_phys_addr + 1'b1 ; // если разрешено, увеличиваем адрес
                            dma_adr_o <= {ram_phys_addr[17:1], 1'b0} ; // выставляем на шину адрес
                            DMA_state <= DMA_write ;  // 
                            reply_count <= 6'b111111;  // взводим таймер обменв
                        end
                        
            // перепись данных сектора из памяти в буфер контроллера через DMA         
            DMA_write :
                        begin
                            // еще есть данные для записи
                        reply_count <= reply_count - 1'b1;
                        if (|reply_count == 1'b0) begin
                                nxm <= 1'b1;
                                DMA_state <= DMA_write_done ; 
                        end  
                            if (dma_ack_i == 1'b1) begin   // устройство подтвердило обмен
                                sdbuf_datain <= dma_dat_i ; // передаем байт данные с шины на вход sdspi
                                dma_adr_o <= {ram_phys_addr[17:1], 1'b0} ; // выставляем на шину адрес
                                dma_stb_o <= 1'b0 ; 
                            if (sector_data_index == 9'o0) begin
                                        // конец данных - освобождаем шину
                                if (sdbuf_addr == 255) DMA_state <= DMA_write_wait ; 
                                else                         DMA_state <= DMA_write_fill; 
                                dma_req <= 1'b0 ;   
                            end 
                            else  DMA_state <= DMA_write_delay ;  
                        end   
                        end
            // задержка 1 такт между операциями DMA-чтения         
            DMA_write_delay: DMA_state <= DMA_write1;         
            // дописывание нулей в конец неполного сектора         
            DMA_write_fill :
                        begin
                        dma_req <= 1'b0 ; 
                        if (sdbuf_addr == 255)  DMA_state <= DMA_write_wait ; 
                        else   begin
                            sdbuf_datain <= {16{1'b0}} ; 
                            sdbuf_addr <= sdbuf_addr + 1'b1 ; 
                            sdbuf_we <= 1'b1 ; 
                        end 
                        end
                        
            DMA_write_wait :
                        begin
                        sdspi_start <= 1'b1 ; 
                        sdspi_write_mode <= 1'b1;
                        sdbuf_we <= 1'b0 ; 
                        if (sdspi_io_done == 1'b1)   begin
                            DMA_state <= DMA_write_done ; 
                            sdspi_start <= 1'b0 ; 
                                sdspi_write_mode <= 1'b0;
                            iocomplete <= 1'b1;
                        end 
                        end
            DMA_write_done :
                        begin
                        if (write_start == 1'b0)  begin
                            iocomplete <= 1'b0;
                            DMA_state <= DMA_idle ; 
                        end 
                        end
            endcase 
    end  
end 

//**********************************************
// Вычисление адреса блока на SD-карте
//**********************************************
// Геометрия диска:
// 815 цилиндров           814 = 11 0010 1110
// 3 головки                 2 =           10
// 22 сектора на дорожку    21 =       1 0101
//
//  66 секторов на цилиндр   cyl_offset cyl*64+cyl*2  (cyl<<6) + (cyl<<1)
//
//
//  всего 53790 секторов
//   D21E = 1101 0011 0001 1110 

wire[16:0] hd_offset; 
wire[16:0] cyl_offset; 
wire[18:0] drv_offset;
// 
// Цилиндр
assign cyl_offset = (rkdc<<6) + (rkdc<<1);
// Головка
assign hd_offset = (rkda_hd == 2'd0) ? 16'd0  :
                   (rkda_hd == 2'd1) ? 16'd22 :
                                       16'd44 ;
//
assign drv_offset = devnum << 16; // округляем размер устройства до 10000h секторов
// полный абсолютный адрес 
assign sdaddr = drv_offset + hd_offset + cyl_offset + rkda_sc + start_offset ;

endmodule
