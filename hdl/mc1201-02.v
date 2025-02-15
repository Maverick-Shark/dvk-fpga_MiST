//
//  Процессорный модуль - плата МС1201.02 (ДВК-3)
//
//  Центральный процессор - 1801ВМ2
//  Теневое ПЗУ - 276 или 055
// 
// ======================================================================================

// Содержимое регистра начального пуска. 
//
//  000 - пуск через вектор 24
//  001 - выход в пульт
//  010 - загрузка с DX
//  011 - пуск с 140000
//  100 - пуск с ПЗУ пользователя
//  101 - выход в пульт
//  110 - пуск c 173000
//  111 - запуск теста
//
`define STARTUP 3'b001


module mc1201_02 (
// Синхросигналы  
   input  clk_p,               // синхросигнал прмой фазы
   input  clk_n,               // синхросигнал инверсной фазы
   input  cpuslow,             // Режим замедления процессора

// Шина Wishbone                                       
   input  cpu_gnt_i,           // 1 - разрешение cpu работать с шиной
                               // 0 - DMA с внешними устройствами, cpu отключен от шины и бесконечно ждет ответа wb_ack
   output [15:0] cpu_adr_o,    // выход шины адреса
   output [15:0] cpu_dat_o,    // выход шины данных
   input  [15:0] cpu_dat_i,    // вход шины данных
   output cpu_cyc_o,           // Строб цила wishbone
   output cpu_we_o,            // разрешение записи
   output [1:0] cpu_sel_o,     // выбор байтов для передачи
   output cpu_stb_o,           // строб данных

   output sysram_stb,          // строб обращения к системной памяти
   input  global_ack,          // подтверждение обмена от памяти и устройств страницы ввода-вывода
   
// Сбросы и прерывания
   output vm_init,             // Выход сброса для периферии
   input  dclo,                // Вход сброса процессора
   input  aclo,                // Сигнал аварии питания
   input  halt,                // Прерывание входа в пультовоый режим
   input  virq,                // Векторное прерывание

// Шины обработки прерываний                                       
   input  [15:0] ivec,         // Шина приема вектора прерывания
   output istb,                // Строб приема вектора прерывания
   input  iack,                // Подтверждение приема вектора прерывания

// Таймер
   input  timer_button,        // кнопка включения-отключения таймера
   output reg timer_status     // линия индикатора состояния таймера
);

// Локальная шина процессора
wire [15:0] local_dat_i;    // локальная входная шина данных
wire [16:0] full_adr;       // полный адрес, вместе с SEL
wire local_stb;             // локальный сигнал начала транзацкии
wire cpu_ack;               // вход REPLY процессора
wire una;                   // строб безадресного чтения
wire [15:0] vector;         // вход вектора прерывания/стартового регистра
wire cpu_istb;              // локальный выход подтверждения приема вектора IACK

// Размещение ROM с монитором 055/279 в теневой области с адреса 140000         
assign rom_stb = local_stb & (full_adr[16:13] == 4'b1110);

// Размещение системной теневой памяти :  160000 - 177776 - в режиме пульта
assign sysram_stb = local_stb & (full_adr[16:13] == 4'b1111);

// Сигнал подтвреждения обмена - от общей шины и модуля ROM
assign cpu_ack = global_ack | rom_ack | bootrom_ack;

// мультиплексор входной шины данных - подключается к общей шине и к локальным источникам
assign local_dat_i = (rom_stb     ? rom_dat    : 16'o0) 
                  |  (bootrom_stb ? bootrom_dat: 16'o0) 
                  |  cpu_dat_i;

// В оригинальном процессоре сигнал adr[16] называется SEL и управляет картой памяти. 
// Признак активной транзакции на общей шине - если адрес [16]==0. 
// При adr[16]==1 транзакция локальная - с теневым ПЗУ или ОЗУ.
assign cpu_stb_o=local_stb & (~full_adr[16]);

// Выход адреса на общую шину 
assign cpu_adr_o=full_adr[15:0];

// cyc - формальный сигнал, не имеющий смысла в нашей схеме
assign cpu_cyc_o=cpu_stb_o;

//***********************************************
//*   Обработка процедуры безадресного чтения
//***********************************************
wire [15:0] startup_reg = {13'o14000, `STARTUP};        // регистр начального пуска
assign vector=(una)? startup_reg : ivec ;  // коммутатор вектора прерывания/регистра начального пуска
assign istb=(una)? 1'b0: cpu_istb;         // блокировка выдача подверждения контроллеру прерываний
                                           // при выполнении безадресного чтения
//*************************************
// счетчик замедления процессора
//*************************************
reg [4:0] cpudelay;
reg cpu_clk_enable;

always @ (posedge clk_p) begin
    if (cpudelay != 5'd`CPUSLOW) begin
        cpudelay <= cpudelay + 1'b1;  // считаем от 0 до 22
        cpu_clk_enable <= 1'b0;
    end     
    else begin
        cpudelay <= 5'd0;
        cpu_clk_enable <= 1'b1;
    end     
end    

//*************************************
//*  Процессор К1801ВМ2
//*************************************
vm2_wb #(.VM2_CORE_FIX_PREFETCH(0)) cpu
(
// Синхросигналы  
   .vm_clk_p(clk_p),                // Положительный синхросигнал
   .vm_clk_n(clk_n),                // Отрицательный синхросигнал
   .vm_clk_slow(cpuslow),           // Режим замедления процессора - определяется переключателем 3
   .vm_clk_ena(cpu_clk_enable),     // счетчик замедления

// Шина Wishbone                                       
   .wbm_gnt_i(cpu_gnt_i),           // 1 - разрешение cpu работать с шиной
                                    // 0 - DMA с внешними устройствами, cpu отключен от шины и бесконечно ждет ответа wb_ack
   .wbm_adr_o(full_adr),            // выход шины адреса
   .wbm_dat_o(cpu_dat_o),           // выход шины данных
   .wbm_dat_i(local_dat_i),         // вход шины данных
//   .wbm_cyc_o(local_cyc),           // Строб цила wishbone
   .wbm_we_o(cpu_we_o),             // разрешение записи
   .wbm_sel_o(cpu_sel_o),           // выбор байтов для передачи
   .wbm_stb_o(local_stb),           // строб данных
   .wbm_ack_i(cpu_ack),             // вход подтверждения данных

// Сбросы и прерывания
   .vm_init(vm_init),               // Выход сброса для периферии
   .vm_dclo(dclo),                  // Вход сброса процессора
   .vm_aclo(aclo),                  // Сигнал аварии питания
   .vm_halt(halt),                  // Прерывание входа в пультовоый режим
   .vm_evnt(timer_50&timer_status), // Прерывание от таймера 
   .vm_virq(virq),                  // Векторное прерывание

// Шины обработки прерываний                                       
   .wbi_dat_i(vector),              // Шина приема вектора прерывания
   .wbi_stb_o(cpu_istb),            // Строб приема вектора прерывания
   .wbi_ack_i(iack|una),            // Подтверждение приема вектора прерывания
   .wbi_una_o(una)                  // Строб безадресного чтения
);

//******************************************************************
//* Модуль ROM с теневым ПЗУ 055/276
//******************************************************************
wire [15:0] rom_dat;
wire rom_stb;
reg rom_ack;
reg rom_ack0;

rom055 hrom(
   .address(full_adr[12:1]),
   .clock(clk_p),
   .q(rom_dat)
);

// формирователь cигнала подверждения транзакции с задержкой на 1 такт
always @ (posedge clk_p) begin
   rom_ack0 <= rom_stb;         
   rom_ack  <= local_stb & rom_ack0;
end

//*******************************************
//* ПЗУ монитора-загрузчика
//*******************************************
wire bootrom_stb;
wire bootrom_ack;
wire [15:0] bootrom_dat;
reg [1:0]bootrom_ack_reg;

`ifdef bootrom_module
// эмулятор пульта и набор загрузчиков - ПЗУ  165000-166777
boot_rom bootrom(
   .address(full_adr[9:1]),
   .clock(clk_p),
   .q(bootrom_dat));

always @ (posedge clk_p) begin
   bootrom_ack_reg[0] <= bootrom_stb & ~cpu_we_o;
   bootrom_ack_reg[1] <= bootrom_stb & ~cpu_we_o & bootrom_ack_reg[0];
end
assign bootrom_ack = cpu_stb_o & bootrom_ack_reg[1];

// сигнал выбора
assign bootrom_stb   = cpu_stb_o & (full_adr[15:10] == 6'o72); // 164000-165776  

`else 
assign bootrom_ack=1'b0;
assign bootrom_stb=1'b0;
`endif

//*************************************************************************
//* Генератор прерываний от таймера
//* Сигнал имеет частоту 50 Гц и ширину импульса в 1 такт
//*************************************************************************
reg timer_50;
reg [20:0] timercnt;

wire [20:0] timer_limit=31'd`clkref/6'd50-1'b1;

always @ (posedge clk_p) begin
  if (timercnt == timer_limit) begin
     timercnt <= 21'd0;
     timer_50 <= 1'b1;
  end  
  else begin
     timercnt <= timercnt + 1'b1;
     timer_50 <= 1'b0;
  end     
end


//**********************************
//* Сигнал разрешения таймера
//**********************************

// начальное состояние таймера
`ifdef timer_init
initial timer_status=`timer_init;  
`else
initial timer_status=1'b1;  
`endif
reg [1:0] tbshift;
reg tbevent;

// подавление дребезга кнопки
always @ (posedge timer_50) begin
  // вводим кнопку в сдвиговый регистр
  tbshift[0] <= timer_button;
  tbshift[1] <= tbshift[0];
  // регистр заполнен - кнопка стабильно нажата
  if (&tbshift == 1'b1) begin
      if (tbevent == 1'b0) begin
        timer_status <= ~timer_status;            // переключаем состояние таймера
        tbevent <= 1'b1;                          // запрещаем дальнейшие изменения состояния таймиера
      end
  end
  // регистр очищен - кнопка стабильно отпущена
  else if (|tbshift == 1'b0) tbevent <= 1'b0;     // разрешаем изменения состояния таймера
end  

endmodule
