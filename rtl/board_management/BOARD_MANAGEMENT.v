module BOARD_MANAGEMENT ( 
    output  reg  I2C_READY,
    input        clk_50,
    input        reset_n,

    // device i2c interface
    inout        I2C_SCL,
    inout        I2C_SDA,

    // board info and control
    output signed [15:0] FPGA_Temperature,  // unit: C
	 output signed [15:0] Board_Temperature , // unit: C
    output [15:0]        Fan_Speed,         // unit: RPM

    input                Auto_Fan_Speed,    // 1: enable audo speed control.0: user specify fan speed
    input  [15:0]        Set_Fan_Speed ,    // used when Auto_Fan_Speedis low

	 
//----USER PORT 
	//FAN IC      

   output  reg [ 15:0] READ_TACH,

	output reg [ 7:0] ID, 	
	output reg [ 7:0] READ_TACH_L, 
	output reg [ 7:0] READ_TACH_H, 
	output reg [ 7:0] STATUS1,
	output reg [ 7:0] STATUS2,
	
	//temperature 
	output reg signed [ 7:0] LOCAL_TEMP ,
	output reg signed [ 7:0] REMOTE_TEMP,
	output reg signed [ 7:0] Temp_DATA_LByte,

		
	//--TEST -- 
   output reg       I2C_LO0P,
	//-
	output reg [7:0] SLAVE_ADDR , 
   output reg [7:0] ST ,
   output reg [7:0] CNT,
	output reg [7:0] WCNT,
   output reg [7:0] W_WORD_DATA,
   output reg [7:0] W_POINTER_REG,
	
	output           W_WORD_END ,
   output reg       W_WORD_GO ,

   output     [7:0] R_DATA,
	output reg       TEMP_VALID

);



wire [15:0] user_ktach;
assign   user_ktach =   6_000_000 / Set_Fan_Speed[15:0];

//---- output to AMC6821 KTACH ; 
wire [15:0] SET_TACH;
assign  SET_TACH = Auto_Fan_Speed? auto_ktach :user_ktach ; 



//----------------latch temperature 
reg signed [ 7:0] last_LOCAL_TEMP  = 80 /*synthesis noprune*/;
reg signed [ 7:0] last_REMOTE_TEMP = 80 /*synthesis noprune*/;
always @ (posedge CLK_400K or negedge  reset_n )
begin
	if (!reset_n  )
	begin
		last_LOCAL_TEMP   <= 80;
		last_REMOTE_TEMP  <= 80;
	end
	else 
	begin
		if (TEMP_VALID)
		begin
			last_LOCAL_TEMP    <= LOCAL_TEMP ;
			last_REMOTE_TEMP   <= REMOTE_TEMP ;
		end
	end
end


//-----MAX Temperature ( FPGA, Board , Board2 ) to Auto fan --- 
reg signed[7:0] AutoFan_temp=40 ; 
always @ (posedge CLK_400K or negedge reset_n )
begin
	if (~reset_n)
		AutoFan_temp <= 40;
	else begin 
	        if ( FPGA_Temperature   >=Board_Temperature ) AutoFan_temp   <= FPGA_Temperature;
	   else                                               AutoFan_temp   <= Board_Temperature;
	   
	end  
end

//--------Auto FAN -----------------
wire invalid_temp ; 
wire [15:0]auto_ktach ;           
AutoFan AutoFan_inst(
	.clk         ( CLK_400K     ),
	.reset_n     ( reset_n      ),
	.temp_fpga   ( AutoFan_temp ),
	.fan_ktach   ( auto_ktach   ) ,
	.invalid_temp(invalid_temp  ) 
);
//----------------------------------------------------



/////

//---- output FAN speed
assign Fan_Speed   = 6_000_000/READ_TACH[15:0]  ;   //rpm  


//---- output FPGA temperature
assign FPGA_Temperature   = last_REMOTE_TEMP-21 ; //-21 is Offsetting difference

//---- output BOARD temperature
assign  Board_Temperature = last_LOCAL_TEMP; 
 
//----400KHZ generater-----
wire CLK_400K;
CLOCKMEM CLOCKMEM_inst2(   .CLK    (clk_50),.CLK_FREQ(125) ,.CK_1HZ (CLK_400K)) ;

//=======================================================
//  WIRE /REGISETER 
//=======================================================

//--I2C Main Controller--- 
reg  [31:0] DELY;

//-----I2C-BUS-I/O----
wire        SDAO;
wire        SCLO;
wire        W_WORD_SCL; 
wire        W_WORD_SDAO;  
wire        W_POINTER_SCL; 
wire        W_POINTER_END; 
reg         W_POINTER_GO;
wire        W_POINTER_SDAO; 
wire        R_SCL; 
wire        R_END; 
reg         R_GO; 
wire        R_SDAO;  

//reg  [12:0] FAN_RPS;
//reg  [ 7:0] KTACH

//=======================================================
//  Parameter  
//=======================================================
// I2C  W/R NUMBER 
parameter    WRITE_MAX      = 9; 
parameter    READ_MAX       = 8; 
    
//--- Temerature-Monitor and Fan control IC (AMC6821) Register ----- 
//slave address   
parameter    SLAVE_ADDR_F   = 8'h5C;

//ID REGISTER
parameter    P_ID           = 8'h3D ; //identification number. Always read '0x21'

//CONFIG  REGISTER
parameter    P_CONFIG1      = 8'h00 ; //default 0xD4, 7:HERMOVIE ,6:FDRC1 ,5:FDRC0 ,4: Fan-FaultEN ,3:PWMINV ,2:FANIE ,1:INT-EN ,0:START
parameter    P_CONFIG2      = 8'h01 ; //default 0x3D, 7:RST ,6:PSVIE 5:RTOIE 4:LTOIE 3:RTFIE 2:TACH-EN 1: TACH MODE 0:PWM-E
parameter    P_CONFIG3      = 8'h3F ; //default 0x82
parameter    P_CONFIG4      = 8'h04 ; //default 0x08

//CONFIG  DATA
parameter    CONFIG1        = 8'b1_01_1_1111; //default0xD4 : [DRC1 FDRC0]=10: auto remote-temperature-fan contro,  
                                              //[DRC1 FDRC0]=01 :software RPM control. 
parameter    CONFIG2        = 8'h3D;   //default 0x3D 2:TACH-EN 1: TACH MODE 0:PWM-E 
parameter    CONFIG3        = 8'h02;   //default 0x82 
parameter    CONFIG4        = 8'h98;	//default 0x08	.eable  OVER pin		

//STATUS REGISTER
parameter    P_STATUS1      = 8'h02 ; 
parameter    P_STATUS2      = 8'h03 ; 

//FAN controll registers 
parameter    P_TACH_READ_H     = 8'h09;//read FAN speed HByte
parameter    P_TACH_READ_L     = 8'h08;//read FAN speed LByte
parameter    P_TACH_SET_H      = 8'h1F;//TACH_SETTING_HByte
parameter    P_TACH_SET_L      = 8'h1E;//TACH_SETTING_HByte

//Temperature monitor registers 
parameter    P_Temp_DATA_LByte    = 8'h06 ;
parameter    P_LOCAL_TEMP         = 8'h0a ; //Local-Temp-DATA-HByte
parameter    P_REMOTE_TEMP        = 8'h0b ; //Remote-Temp-DATA-HByte
parameter    P_LocalHighTempLimit =8'h14 ; 
parameter    P_RemoteHighTempLimit=8'h18 ; 

//FAN PWM chara registers 
parameter    P_FAN_Char  =8'h20 ; 


					 

//-------Software-RPM Control Mode (Fan Speed Regulator)
//=======================================================
//  Structural coding
//======================================================= 
parameter    SEC    = 400_000;
parameter    SEC0d1 = SEC/10;
parameter    SEC0d5 = SEC/2;

//-  AMC6821 define  RPM =   ( 100K x 60 )  / ( Value of TACH-DATA Register ) 

//wire can_enable_alarm ; //<--- about 0.2s after reset
//fan_timer timer_enable_alarm(  
//.RESET_N   (reset_n),
//.CLK       (CLK_400K) ,
//.TIME_OUT  (can_enable_alarm)
//);
																	 
																	 

//--I2C Main Controller--- 
reg do_config ; //<--
always @(negedge reset_n or posedge CLK_400K )begin 
if (!reset_n  ) begin 
    ST <=0;
 	 W_POINTER_GO <=1;
    R_GO  <=1 ;		 
	 W_WORD_GO <=1;
	 WCNT <=0;  
	 CNT  <=0;
	 DELY <=0 ; 
    do_config   <=0;//<--
	 TEMP_VALID <=0;
	 I2C_READY   <=0;
end 
else 
case (ST)
0: begin 
    ST<=30;     //---First ,  to do I2C write . 
	 W_POINTER_GO <=1;
    R_GO  <=1 ;		 
	 W_WORD_GO <=1;
	 WCNT <=0;  
	 CNT  <=0;
	 DELY <=0 ;   
    do_config   <=0;//<--
   end
//------------- READ -------	
1: begin 
    ST<=2;
	 TEMP_VALID <=0;
	end	
2: begin
        // FAN READ 		  
	          if ( CNT==0)      {SLAVE_ADDR[7:0] ,W_POINTER_REG}<= {SLAVE_ADDR_F[7:0] ,P_ID  };
	     else if ( CNT==1)      {SLAVE_ADDR[7:0] ,W_POINTER_REG}<= {SLAVE_ADDR_F[7:0] ,P_STATUS1  };
	     else if ( CNT==2)      {SLAVE_ADDR[7:0] ,W_POINTER_REG}<= {SLAVE_ADDR_F[7:0] ,P_STATUS2  };	 
		  else if ( CNT==3)      {SLAVE_ADDR[7:0] ,W_POINTER_REG}<= {SLAVE_ADDR_F[7:0] ,P_TACH_READ_L };
		  else if ( CNT==4)      {SLAVE_ADDR[7:0] ,W_POINTER_REG}<= {SLAVE_ADDR_F[7:0] ,P_TACH_READ_H };
		  else if ( CNT==5)      {SLAVE_ADDR[7:0] ,W_POINTER_REG}<= {SLAVE_ADDR_F[7:0] ,P_LOCAL_TEMP   };
		  else if ( CNT==6)      {SLAVE_ADDR[7:0] ,W_POINTER_REG}<= {SLAVE_ADDR_F[7:0] ,P_Temp_DATA_LByte};//
		  else if ( CNT==7)      {SLAVE_ADDR[7:0] ,W_POINTER_REG}<= {SLAVE_ADDR_F[7:0] ,P_REMOTE_TEMP  };
		                
	if ( W_POINTER_END ) begin  
	   W_POINTER_GO  <=0; 
		ST<=3 ; 
		DELY<=0;  
	 end
	end                
	//------- Write Pointer
3: begin 
    DELY  <=DELY +1;
    if ( DELY ==2 ) begin 
      W_POINTER_GO  <=1;
      ST<=4 ; 
	 end
	end       
4: begin 
    if  ( W_POINTER_END ) ST<=5 ; 	
	end              
5: begin 
    ST<=6 ; 
	end 
	//------- Read DATA  		 
6: begin 
	 if ( R_END ) begin  
	  R_GO  <=0; 
	  ST<=7 ; 
	  DELY<=0; 
	 end
	end                
7: begin 
    DELY  <=DELY +1;
    if ( DELY ==2 ) begin 	 
      R_GO  <=1;
      ST<=8 ; 
	 end
	end       
8: begin 
     ST<=9 ; 
	end       
9: begin 
   if  ( R_END ) 
	 begin 		
	      //--READ  
		        if ( CNT==0) 	ID          <=R_DATA ; 			
		   else if ( CNT==1) 	STATUS1     <=R_DATA ; 
		   else if ( CNT==2) 	STATUS2     <=R_DATA ; 				 	  
		   else if ( CNT==3) 	READ_TACH_L <=R_DATA ;
		   else if ( CNT==4) 	READ_TACH_H <=R_DATA ;
		   else if ( CNT==5) 	LOCAL_TEMP  <=R_DATA ;
			else if ( CNT==6) 	Temp_DATA_LByte<=R_DATA ;
		   else if ( CNT==7) 	REMOTE_TEMP <=R_DATA ;
	      CNT<=CNT+1 ;
	      ST<=10 ; 	
	 end 
  end	
  
  
10: begin   
     if ( CNT == READ_MAX) 
	   begin  
		  I2C_READY   <=1;
	     CNT <=0 ;   
		  ST  <= 29; 
		  READ_TACH[15:0] <= {READ_TACH_H[7:0] , READ_TACH_L[7:0]};		 
		end
	  else begin   
	        ST<=1; 
		end 	
		  DELY <=0;
	     W_POINTER_GO <=1;
        R_GO         <=1 ;		 
	     W_WORD_GO    <=1; 		    		 		  
	 end 
//----  READ END ----

//----  WRITE----
29: begin 
	  TEMP_VALID <=1;
     if (DELY < 10 ) DELY <=DELY+1; 
	  else  ST<=30; 
    end	
30: begin 
	  ST<=31; 
    end	
31: begin 
      //TEMP 
		     if ( WCNT==0 ) begin {SLAVE_ADDR ,W_POINTER_REG ,W_WORD_DATA}   <= { SLAVE_ADDR_F ,P_CONFIG4 ,CONFIG4 };  end
      else if ( WCNT==1 ) begin {SLAVE_ADDR ,W_POINTER_REG ,W_WORD_DATA}   <= { SLAVE_ADDR_F ,P_CONFIG3 ,CONFIG3 };  end
      else if ( WCNT==2 ) begin {SLAVE_ADDR ,W_POINTER_REG ,W_WORD_DATA}   <= { SLAVE_ADDR_F ,P_CONFIG2 ,CONFIG2 };  end
		else if  (WCNT==3 ) begin {SLAVE_ADDR ,W_POINTER_REG ,W_WORD_DATA}   <= { SLAVE_ADDR_F ,P_CONFIG1 , CONFIG1 }; end  // [DRC1 FDRC0]=01 , software RPM control. INT_EN=1 		
		else if  (WCNT==4 ) begin {SLAVE_ADDR ,W_POINTER_REG ,W_WORD_DATA}   <= { SLAVE_ADDR_F ,P_FAN_Char ,8'h3d }; end   // PWM frequcy =40khz
      else if ( WCNT==5 ) begin {SLAVE_ADDR ,W_POINTER_REG ,W_WORD_DATA}   <= { SLAVE_ADDR_F ,P_CONFIG2  ,8'h3f };  end
	   else if ( WCNT==7 ) begin {SLAVE_ADDR ,W_POINTER_REG ,W_WORD_DATA}   <= { SLAVE_ADDR_F ,P_TACH_SET_L ,SET_TACH[7:0]};  end	//set TACH
	   else if ( WCNT==6 ) begin {SLAVE_ADDR ,W_POINTER_REG ,W_WORD_DATA}   <= { SLAVE_ADDR_F ,P_TACH_SET_H ,SET_TACH[15:8]}; end	
      else if ( WCNT==8 ) begin {SLAVE_ADDR ,W_POINTER_REG ,W_WORD_DATA}   <= { SLAVE_ADDR_F ,P_CONFIG2 ,8'h3f  };  end

		
	 if (  W_WORD_END ) begin  
	   W_WORD_GO  <=0; 
		ST   <=32 ;  
		DELY <=0;  
	 end
	end           
32: begin 
    DELY  <=DELY +1;
		if (DELY ==5 ) begin 
        W_WORD_GO  <=1;
        ST         <=33 ; 
	   end
	end       
33: begin 
    ST<=34 ; 
	end       	
34: begin 
     if  ( W_WORD_END )  begin 	
			 WCNT<=WCNT+1 ;			 
			 ST<=35 ; 
	  end
	end              
35: begin
	 if ( WCNT != WRITE_MAX )  ST<=31 ; 	  
	 else  
		begin 
	         ST       <= 36; 
	 			WCNT     <= WRITE_MAX-4;  
				CNT      <= 0; 
				DELY     <= 0;
				I2C_LO0P <= 0;
	   end 
	 end
36: begin
    I2C_LO0P <= 0 ; 
       if ( DELY == SEC0d5 ) ST <=37; 
	    else DELY  <= DELY +1;
	 end  
37: begin 
		 ST <=1;
	 end  
endcase
end
//-----------------------------MAIN-ST END ------------------------------------------

//============i2c bus  ===============  
assign I2C_SDA        = (SDAO)?1'bz :0;
assign I2C_SCL        = (SCLO)?1'bz :0;
assign SDAO           = W_POINTER_SDAO & R_SDAO  & W_WORD_SDAO;
assign SCLO           = W_POINTER_SCL  & R_SCL   & W_WORD_SCL;

//==== I2C WRITE WORD ===
I2C_WRITE_BYTE  wrd(
   .RESET_N      ( reset_n),
	.PT_CK        ( CLK_400K),
	.GO           ( W_WORD_GO),
	.POINTER      ( W_POINTER_REG),
   .WDATA8	     ( W_WORD_DATA),
	.SLAVE_ADDRESS( SLAVE_ADDR ),
	.SDAI         ( I2C_SDA),
	.SDAO         ( W_WORD_SDAO),
	.SCLO         ( W_WORD_SCL ),
	.END_OK       ( W_WORD_END)
);

//==== I2C WRITE POINTER ===
I2C_WRITE_POINTER  wpt(
   .RESET_N      (reset_n   ),
	.PT_CK        ( CLK_400K ),
	.GO           ( W_POINTER_GO ),
	.POINTER      ( W_POINTER_REG),
	.SLAVE_ADDRESS( SLAVE_ADDR ),
	.SDAI         ( I2C_SDA    ),
	.SDAO         ( W_POINTER_SDAO),
	.SCLO         ( W_POINTER_SCL ),
	.END_OK       ( W_POINTER_END )
);

//-----I2C TO READ---- 
I2C_READ_DATA rd( 
   .RESET_N      ( reset_n    ),
	.PT_CK        ( CLK_400K   ),
	.GO           ( R_GO       ),
	.SLAVE_ADDRESS( SLAVE_ADDR ),
 	.BYTE_NUM     ( 0          ) , // I2C read 8 bit data 
	.SDAI         ( I2C_SDA),
	.SDAO         ( R_SDAO ),
	.SCLO         ( R_SCL  ),
	.END_OK       ( R_END  ),
	.DATA         ( R_DATA )
);
	
endmodule
	