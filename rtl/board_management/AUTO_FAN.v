module AutoFan(
	input		      	clk,    //400k
	input 	         reset_n,
	
	
	input	   signed [7:0]  temp_fpga ,
	output	signed [7:0]  d_temp ,	
	output          [15:0] fan_ktach ,
	output          [15:0] out_speed ,
   output          [15:0] diff_speed ,
	input           [15:0] Fan_Speed,
	
	input             invalid_temp
);
parameter  TH       = 1;
parameter  SEC      = 400_000;
parameter  S0d5     = SEC/2;
parameter min_speed = 3000;
parameter max_speed = 100_00;
parameter Hi_temp   = 90;
parameter Lo_temp   = 35;
parameter Toffset   = Hi_temp - Lo_temp ; 


//--speed scale by temparature 
assign  diff_speed  = (max_speed - min_speed)/Toffset ;

//--real temparature diff 
assign d_temp     =    ( temp_pre <= Lo_temp )? 1 : (
                       ( temp_pre >= Hi_temp )? Toffset : (temp_pre -Lo_temp ) 
							  );
							  
//---offset *real temparature diff
assign  out_speed     = min_speed + diff_speed * d_temp ;//

//---ktach out 
assign  fan_ktach  = 6_000_000/out_speed;//6_000_000/out_speed;

//---Tempture update rate 
reg [7:0] temp_pre;
reg [19:0] delay ; 

always@(posedge clk or negedge reset_n )
begin
	if (~reset_n) begin 
		temp_pre <= 0;
		delay <=0;
		end 
	else if ( delay < SEC) delay<=delay+1 ;
	else begin 
	     delay<=0;
		  if ( (temp_fpga > (temp_pre + TH) ) | ( temp_fpga < ( temp_pre-TH) ) ) temp_pre <= temp_fpga ;
	end	
end



//parameter Speed1 =min_speed+offset*7;
//parameter Speed2 =min_speed+offset*6;
//parameter Speed3 =min_speed+offset*5;
//parameter Speed4 =min_speed+offset*4;
//parameter Speed5 =min_speed+offset*3;
//parameter Speed6 =min_speed+offset*2;
//parameter Speed7 =min_speed+offset*1;
//parameter Speed8 =min_speed+offset*0;


//`define FAN_SPEED_1 ((992 * scale ) / (Speed1/60) ) - 1
//`define FAN_SPEED_2 ((992 * scale ) / (Speed2/60) ) - 1
//`define FAN_SPEED_3 ((992 * scale ) / (Speed3/60) ) - 1
//`define FAN_SPEED_4 ((992 * scale ) / (Speed4/60) ) - 1
//`define FAN_SPEED_5 ((992 * scale ) / (Speed5/60) ) - 1
//`define FAN_SPEED_6 ((992 * scale ) / (Speed6/60) ) - 1
//`define FAN_SPEED_7 ((992 * scale ) / (Speed7/60) ) - 1
//`define FAN_SPEED_8 ((992 * scale ) / (Speed8/60) ) - 1
//
//
//
//
//parameter Toffset    = (70-35)/6 ; //60~40 
//`define TEMP_LEVEL_1 40+Toffset*6 
//`define TEMP_LEVEL_2 40+Toffset*5 
//`define TEMP_LEVEL_3 40+Toffset*4 
//`define TEMP_LEVEL_4 40+Toffset*3 
//`define TEMP_LEVEL_5 40+Toffset*2 
//`define TEMP_LEVEL_6 40+Toffset*1 
//`define TEMP_LEVEL_7 40+Toffset*0
//
//
//
//
////-----------------

//
////-----------------
//reg TEMP_UP_FLAG;
//always@(posedge clk or negedge reset_n )
//begin
//	if (~reset_n)
//		TEMP_UP_FLAG <= 1'b1;
//	else if (TEMP_UP_FLAG)
//	begin
//		//if (temp_fpga < (temp_pre+1))
//		if (temp_fpga < temp_pre)
//			TEMP_UP_FLAG <= 1'b0;
//	end
//	else
//	begin
//		//if (temp_fpga > (temp_pre+1))
//		if (temp_fpga > temp_pre)
//			TEMP_UP_FLAG <= 1'b1;
//	end
//end
//
////-----------------
//wire  [7:0] auto_ktach;
//always@(posedge clk or negedge reset_n)
//begin
//	if (~reset_n)
//		auto_ktach <= `FAN_SPEED_4;
//	else if ( invalid_temp ) auto_ktach <= `FAN_SPEED_1;
//	else if (TEMP_UP_FLAG)
//	begin
//     if (temp_fpga  >  `TEMP_LEVEL_1 ) 
//			auto_ktach <= `FAN_SPEED_1;
//     else if (temp_fpga  >  `TEMP_LEVEL_2 ) 
//			auto_ktach <= `FAN_SPEED_2;
//     else if (temp_fpga  >  `TEMP_LEVEL_3 ) 
//			auto_ktach <= `FAN_SPEED_3;
//     else if (temp_fpga  >  `TEMP_LEVEL_4 ) 
//			auto_ktach <= `FAN_SPEED_4;
//     else if (temp_fpga  >  `TEMP_LEVEL_5 ) 
//			auto_ktach <= `FAN_SPEED_5;
//     else if (temp_fpga  >  `TEMP_LEVEL_6 ) 
//			auto_ktach <= `FAN_SPEED_6;
//     else if (temp_fpga  >  `TEMP_LEVEL_7 ) 
//			auto_ktach <= `FAN_SPEED_7;
//     else
//			auto_ktach <= `FAN_SPEED_8;
//	end
//	else
//	begin
//     if (temp_fpga  <  `TEMP_LEVEL_7 ) 
//			auto_ktach <= `FAN_SPEED_8;
//     else if (temp_fpga  <  `TEMP_LEVEL_6 ) 
//			auto_ktach <= `FAN_SPEED_7;
//     else if (temp_fpga  <  `TEMP_LEVEL_5 ) 
//			auto_ktach <= `FAN_SPEED_6;
//     else if (temp_fpga  <  `TEMP_LEVEL_4 ) 
//			auto_ktach <= `FAN_SPEED_5;
//     else if (temp_fpga  <  `TEMP_LEVEL_3 ) 
//			auto_ktach <= `FAN_SPEED_4;
//     else if (temp_fpga  <  `TEMP_LEVEL_2 ) 
//			auto_ktach <= `FAN_SPEED_3;
//     else if (temp_fpga  <  `TEMP_LEVEL_1 ) 
//			auto_ktach <= `FAN_SPEED_2;
//	  else
//			auto_ktach <= `FAN_SPEED_1;
//	
//	end
//	
//end





endmodule



