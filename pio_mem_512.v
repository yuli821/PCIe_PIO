//-----------------------------------------------------------------------------
//
// PIO Memory Module for 512-bit Interface
// Simple Dual-Port BRAM: Port A (Write/RX) + Port B (Read/TX)
// Memory: 128 x 512-bit = 8KB
// Read Latency: 1 cycle
//
// Address Format:
//   - Input addresses are 13-bit BYTE addresses
//   - bits [12:6] = word address (128 words)
//   - bits [5:0]  = byte offset (handled by TX/RX engines, ignored here)
//
//-----------------------------------------------------------------------------

`timescale 1ps/1ps

(* DowngradeIPIdentifiedWarnings = "yes" *)
module pio_mem_512 #(
  parameter BYTE_ADDR_WIDTH = 13,      // Byte address width (8KB space)
  parameter DATA_WIDTH = 512,          // 512-bit data width
  parameter WORD_ADDR_WIDTH = 7,       // Word address width (128 words)
  parameter DEPTH = 128                // 128 words × 512 bits = 8KB
)(
  input  wire                          clk,
  input  wire                          rst_n,
  
  // TX Engine Read Port (Port B) - takes byte addresses
  input  wire [BYTE_ADDR_WIDTH-1:0]   rd_addr,     // 13-bit byte address
  input  wire                          rd_en,
  output wire [DATA_WIDTH-1:0]         rd_data,     // Returns full 512-bit word
  
  // RX Engine Write Port (Port A) - takes byte addresses
  input  wire [BYTE_ADDR_WIDTH-1:0]   wr_addr,     // 13-bit byte address
  input  wire [DATA_WIDTH/8-1:0]       wr_be,       // 64-bit byte enable
  input  wire [DATA_WIDTH-1:0]         wr_data,     // Pre-aligned by RX engine
  input  wire                          wr_en
);

  // Extract word addresses from byte addresses
  // Byte addr [12:6] = word address, [5:0] = byte offset (ignored)
  wire [WORD_ADDR_WIDTH-1:0] rd_word_addr = rd_addr[12:6];
  wire [WORD_ADDR_WIDTH-1:0] wr_word_addr = wr_addr[12:6];

  // XPM Simple Dual-Port RAM
  xpm_memory_sdpram #(
    .ADDR_WIDTH_A(WORD_ADDR_WIDTH),      // 7 bits for 128 words
    .ADDR_WIDTH_B(WORD_ADDR_WIDTH),      // 7 bits for 128 words
    .AUTO_SLEEP_TIME(0),                 // Disable auto-sleep
    .BYTE_WRITE_WIDTH_A(8),              // Byte write granularity
    .CASCADE_HEIGHT(0),                  // No cascading
    .CLOCKING_MODE("common_clock"),      // Single clock domain
    .ECC_MODE("no_ecc"),                 // No ECC
    .MEMORY_INIT_FILE("none"),           // No init file
    .MEMORY_INIT_PARAM("0"),             // Initialize to 0
    .MEMORY_OPTIMIZATION("true"),        // Enable optimization
    .MEMORY_PRIMITIVE("auto"),           // Let tool choose (BRAM/URAM)
    .MEMORY_SIZE(DEPTH * DATA_WIDTH),    // 128 × 512 = 65,536 bits = 8KB
    .MESSAGE_CONTROL(0),                 // Disable info messages
    .READ_DATA_WIDTH_B(DATA_WIDTH),      // 512-bit read
    .READ_LATENCY_B(1),                  // 1-cycle read latency
    .READ_RESET_VALUE_B("0"),            // Reset value
    .USE_EMBEDDED_CONSTRAINT(0),         // No embedded constraints
    .USE_MEM_INIT(1),                    // Use memory initialization
    .WAKEUP_TIME("disable_sleep"),       // Disable sleep
    .WRITE_DATA_WIDTH_A(DATA_WIDTH)      // 512-bit write
  ) xpm_mem_inst (
    // Port A: Write (RX Engine)
    .dina(wr_data),
    .addra(wr_word_addr),
    .wea(wr_be),                         // 64-bit byte enable array
    .ena(wr_en),
    .clka(clk),
    .injectsbiterra(1'b0),
    .injectdbiterra(1'b0),
    
    // Port B: Read (TX Engine)
    .addrb(rd_word_addr),
    .doutb(rd_data),
    .enb(rd_en),
    .clkb(clk),
    .rstb(~rst_n),                       // Reset for read port (active high)
    .regceb(1'b1),
    .sbiterrb(),
    .dbiterrb(),
    
    // Sleep control
    .sleep(1'b0)                         // Disable sleep mode
  );

endmodule