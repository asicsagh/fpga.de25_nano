//`define ENABLE_LPDDR4A
//`define ENABLE_LPDDR4B
//`define ENABLE_HPS
//`define ENABLE_CAM

module top_de25_nano (
    input logic CLOCK0_50,
    input logic CLOCK1_50,
    input logic CLOCK2_50,

    output logic [7:0] LED,
    input logic [1:0] KEY,
    input logic [3:0] SW,

    output logic DRAM_CLK,
    output logic DRAM_CKE,
    output logic [12:0] DRAM_ADDR,
    output logic [1:0] DRAM_BA,
    output logic DRAM_LDQM,
    output logic DRAM_UDQM,
    output logic [1:0] DRAM_CS_n,
    output logic DRAM_WE_n,
    output logic DRAM_CAS_n,
    output logic DRAM_RAS_n,
    inout logic [15:0] DRAM_DQ,

`ifdef ENABLE_LPDDR4A
    output logic LPDDR4A_CS_n,
    output logic [5:0] LPDDR4A_CA,
    output logic LPDDR4A_CK,
    output logic LPDDR4A_CKE,
    output logic LPDDR4A_CK_n,
    output logic LPDDR4A_RESET_n,
    inout logic [3:0] LPDDR4A_DM,
    inout logic [31:0] LPDDR4A_DQ,
    inout logic [3:0] LPDDR4A_DQS,
    inout logic [3:0] LPDDR4A_DQS_n,
    input logic LPDDR4A_RZQ,
    input logic LPDDR4A_REFCLK_p,
`endif

`ifdef ENABLE_LPDDR4B
    output logic LPDDR4B_CS_n,
    output logic [5:0] LPDDR4B_CA,
    output logic LPDDR4B_CK,
    output logic LPDDR4B_CKE,
    output logic LPDDR4B_CK_n,
    output logic LPDDR4B_RESET_n,
    inout logic [3:0] LPDDR4B_DM,
    inout logic [31:0] LPDDR4B_DQ,
    inout logic [3:0] LPDDR4B_DQS,
    inout logic [3:0] LPDDR4B_DQS_n,
    input logic LPDDR4B_REFCLK_p,
    input logic LPDDR4B_RZQ,
`endif

    output logic HDMI_TX_CLK,
    output logic HDMI_TX_HS,
    output logic HDMI_TX_VS,
    output logic [23:0] HDMI_TX_D,
    output logic HDMI_TX_DE,
    inout logic HDMI_LRCLK,
    inout logic HDMI_MCLK,
    inout logic HDMI_SCLK,
    inout logic HDMI_I2C_SCL,
    inout logic HDMI_I2C_SDA,
    inout logic HDMI_I2S,
    input logic HDMI_TX_INT,

`ifdef ENABLE_CAM
    inout logic CAM_I2C_SCL,
    inout logic CAM_I2C_SDA,
    inout logic CAM_GPIO,
    input logic CAM_CLK_p,
    input logic CAM_CLK_n,
    input logic [1:0] CAM_D_p,
    input logic [1:0] CAM_D_n,
    input logic CAM_RZQ1,
`endif

    output logic FPGA_UART_TX,
    input logic FPGA_UART_RX,

    output logic ADC_SCK,
    output logic ADC_SDI,
    output logic ADC_CS_n,
    input logic ADC_SDO,

    inout logic [35:0] GPIO0_D,
    inout logic [35:0] GPIO1_D,

`ifdef ENABLE_HPS
    output logic HPS_ENET_MDC,
    output logic HPS_ENET_TX_CLK,
    output logic HPS_ENET_TX_CTL,
    output logic [3:0] HPS_ENET_TX_DATA,
    output logic HPS_SD_CLK,
    output logic HPS_UART_TX,
    output logic HPS_USB_STP,
    inout logic HPS_ENET_MDIO,
    inout logic HPS_GSENSOR_I2C_EN,
    inout logic HPS_GSENSOR_INT,
    inout logic HPS_I2C_SCL,
    inout logic HPS_I2C_SDA,
    inout logic HPS_KEY,
    inout logic HPS_LED,
    inout logic HPS_SD_CMD,
    inout logic [3:0] HPS_SD_DATA,
    inout logic [7:0] HPS_USB_DATA,
    input logic HPS_CLK_25,
    input logic HPS_ENET_RX_CLK,
    input logic HPS_ENET_RX_CTL,
    input logic [3:0] HPS_ENET_RX_DATA,
    input logic HPS_UART_RX,
    input logic HPS_USB_CLK,
    input logic HPS_USB_DIR,
    input logic HPS_USB_NXT,
`endif

    input logic FAN_ALERT_n
);


/* Local variables and signals */

logic clk_100, rst_n, ninit_done;

logic [31:0] counter;


/* Signals assignments */

assign clk = CLOCK0_50;
assign rst_n = KEY[0] & ~ninit_done;

assign LED = ~counter[31:22];


/* Submodules */

reset_release u_reset_release (
    .ninit_done
);

pll u_pll (
    .refclk(CLOCK0_50),
    .rst(~rst_n),

    .outclk_0(clk_100)
);

BOARD_MANAGEMENT u_BOARD_MANAGEMENT (
    .clk_50(CLOCK0_50),
    .reset_n(rst_n),

    .I2C_READY(),
    .I2C_SCL(HDMI_I2C_SCL),
    .I2C_SDA(HDMI_I2C_SDA),

    .FPGA_Temperature(),
    .Board_Temperature(),
    .Fan_Speed(),

    .Auto_Fan_Speed(1'b1),
    .Set_Fan_Speed(16'b0),

    .READ_TACH(),

    .ID(),
    .READ_TACH_L(),
    .READ_TACH_H(),
    .STATUS1(),
    .STATUS2(),

    .LOCAL_TEMP(),
    .REMOTE_TEMP(),
    .Temp_DATA_LByte(),

    .I2C_LO0P(),

    .SLAVE_ADDR(),
    .ST(),
    .CNT(),
    .WCNT(),
    .W_WORD_DATA(),
    .W_POINTER_REG(),

    .W_WORD_END(),
    .W_WORD_GO(),

    .R_DATA(),
    .TEMP_VALID()
);


/* Internal logic */

always_ff @(posedge clk_100 or negedge rst_n) begin
    if (!rst_n)
        counter <= 32'b0;
    else
        counter <= counter + 1;
end

endmodule
