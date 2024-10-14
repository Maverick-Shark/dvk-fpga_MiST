//
//  Файл конфигурации собираемой ЭВМ
//
//======================================================================================================
// Тип процессорной платы. 
//
//  Плата       Процессор     ЭВМ           Тактовая частота
//-------------------------------------------------------------
//  МС1201.01   К1801ВМ1     ДВК-1,ДВК-2        75 Мгц
//  МС1201.02   К1801ВМ2     ДВК-3              75 Мгц
//  МС1260      М2 (LSI-11)  Электроника-60     50 Мгц
//  МС1280      М4 (LSI-11M)                    50 МГц
//------------------------------------------------------------
// Раскомментируйте одну из строк для включения выбранной платы в схему

//`define mc1201_01_board
`define mc1201_02_board
//`define mc1260_board
//`define mc1280_board

//======================================================================================================
//
//  Включаемые компоненты
//  Закомментируйте ненужные модули, если хотите исключить их из схемы.
//

`define KSM_module        // текстовый контроллер КСМ
`define KGD_module        // графический контроллер КГД
`define IRPS2_module      // второй последовательный порт ИРПС
`define IRPR_module       // параллельный порт ИРПР
`define RK_module         // диск RK-11/RK05
`define DM_module         // диск RK611/RK07
`define DW_module         // жесткий диск DW
`define DX_module         // гибкий диск RX01
`define MY_module         // гибкий диск двойной плотности MY
`define bootrom_module    // монитор-загрузчик M9312

//======================================================================================================
//
// Пзу пользователя в пространстве 140000-157776
// Для включения ПЗУ в схему раскомментируйте строку, и укажите имя mif-файла, загружаемого в ПЗУ.
// Размер загружаемого дампа не должен превышать 8Кб

//`define userrom "../../rom/013-basic.mif"
//`define userrom "../../rom/058-focal.mif"

//======================================================================================================
//
// Выбор файла шрифта текстового терминала КСМ
// Раскомментируйте одну из строк, указывающих на нужный файл шрифта

//   * font-main - шрифт 8*12, ровный и хорошо читаемый на LCD-мониторах
`define fontrom_file "../../ksm-firmware/font/font-main.mif"

//   * font-ksm - шрифт 8*8, из ПЗУ знакогенератора КСМ. С ним экран будет выглядеть в точности как оригинальный КСМ.
//     Шрифт довольно корявый, интересный только с исторической точки зрения.
//`define fontrom_file "../../ksm-firmware/font/font-ksm.mif"

//======================================================================================================
// Выбор начальных скоростей последовательных портов
// 
//  Индексы скорости последовательного порта:
//  0 - 1200
//  1 - 2400
//  2 - 4800
//  3 - 9600
//  4 - 19200
//  5 - 38400
//  6 - 57600
//  7 - 115200

// начальная скорость терминала
`define TERMINAL_SPEED 3'd5

// скорость второго последовательного интерфейса
`define UART2SPEED 3'd5

//======================================================================================================
//
//  Сдвиг фазы строчного синхроимпульса, выдаваемого модулем КСМ на VGA.
//  Если на вашем мониторе или устройстве видеозахвата картинка уезжает за левый край экрана, то раскомментируйте эту строку и
//  укажите величину горизонтального сдвига в пикселях.
//  Если картинка выглядит нормально без коррекции, оставьте строку закомметированной.
//
//`define hsync_shift 11'd27

//======================================================================================================
//
// DRAM CAS Latency
// Этот параметр может принимать значение 2 или 3. 
// При CL=2 обмен идет быстрее, но не все типы DRAM его поддерживают.
`define cas_latency 2

//======================================================================================================
//
// Индивидуальные настройки процессорных плат
//--------------------------------------------------

`ifdef mc1280_board
//****************************************
//*   МС1280
//****************************************
 `define BOARD mc1280        // имя подключаемого модуля процессорной платы
 `define clkref 50000000     // тактовая частота процессора в герцах
 `define PLL_MUL 1           // умножитель PLL
 `define PLL_DIV 1           // делитель PLL
 
//-------------------------------------------------- 
`elsif mc1260_board
//****************************************
//*   МС1260
//****************************************
 `define BOARD mc1260        // имя подключаемого модуля процессорной платы
 `define clkref 50000000     // тактовая частота процессора в герцах
 `define PLL_MUL 1           // умножитель PLL
 `define PLL_DIV 1           // делитель PLL
 `define CPUSLOW 10          // число тактов, пропускаемых процессором в режиме замедления
 
//--------------------------------------------------
`elsif mc1201_02_board
//****************************************
//*   МС1201.02
//****************************************
 `define BOARD mc1201_02     // имя подключаемого модуля процессорной платы
 `define clkref 75000000    // тактовая частота процессора в герцах
 `define PLL_MUL 3           // умножитель PLL
 `define PLL_DIV 2           // делитель PLL
 `define CPUSLOW 15          // число тактов, пропускаемых процессором в режиме замедления
 `define timer_init 1'b1     // Начальное состояние таймера: 0 - выключен, 1 - включен

  // Выбор версии теневого ПЗУ - 055 или 279
  
  //`define mc1201_02_rom "../../rom/055.mif"
 `define mc1201_02_rom "../../rom/279.mif"

//--------------------------------------------------
`elsif mc1201_01_board
//****************************************
//*   МС1201.01
//****************************************
 `define BOARD mc1201_01     // имя подключаемого модуля процессорной платы
 `define clkref 75000000    // тактовая частота процессора в герцах
 `define PLL_MUL 3           // умножитель PLL
 `define PLL_DIV 2           // делитель PLL
 `define CPUSLOW 15          // число тактов, пропускаемых процессором в режиме замедления
 `define timer_init 1'b1     // Начальное состояние таймера: 0 - выключен, 1 - включен 
  
`endif  


//==========================================================================================================================================
//------------------ конец списка настраиваемых параметров -------------------------------------------------------------
//==========================================================================================================================================

// удаление графического модуля при отсутствии текcтового терминала
`ifndef KSM_module
`undef KGD_module
`endif

// Выбор ведущего и ведомых SDSPI
`ifdef RK_module
  `define RK_sdmode 1'b1  
  `define DM_sdmode 1'b0  
  `define MY_sdmode 1'b0
  `define DX_sdmode 1'b0
  `define DW_sdmode 1'b0
  `define def_mosi  rk_mosi
  `define def_cs    rk_cs
  `define def_sclk  rk_sclk

  `elsif DM_module
  `define DM_sdmode 1'b1  
  `define RK_sdmode 1'b0  
  `define MY_sdmode 1'b0
  `define DX_sdmode 1'b0
  `define DW_sdmode 1'b0
  `define def_mosi  dm_mosi
  `define def_cs    dm_cs
  `define def_sclk  dm_sclk
  
`elsif MY_module
  `define MY_sdmode 1'b1
  `define RK_sdmode 1'b0  
  `define DM_sdmode 1'b0  
  `define DX_sdmode 1'b0
  `define DW_sdmode 1'b0
  `define def_mosi  my_mosi
  `define def_cs    my_cs
  `define def_sclk  my_sclk

`elsif DX_module
  `define DX_sdmode 1'b1
  `define MY_sdmode 1'b0
  `define DM_sdmode 1'b0  
  `define RK_sdmode 1'b0  
  `define DW_sdmode 1'b0
  `define def_mosi  dx_mosi
  `define def_cs    dx_cs
  `define def_sclk  dx_sclk
  
`else
  `define DW_sdmode 1'b1
  `define DX_sdmode 1'b0
  `define DM_sdmode 1'b0  
  `define MY_sdmode 1'b0
  `define RK_sdmode 1'b0  
  `define def_mosi  dw_mosi
  `define def_cs    dw_cs
  `define def_sclk  dw_sclk
  
`endif  
  
  
  
