/*************************************************************************************************************************************
 AMBA AHB is a backbone bus for the on-chip communication protocol. AHB is a high performace (pipelined,non-tristated-->next address 
is avaiable during the execution of data phase), high bandwidth (8,16,32,64,128 bits) support is avaiabble. However, 32 bits is minimum
recomended. It supports burst transfers (incremental or wrapped - multiple data transfer within in a fixed address range) and split 
transaction (slave holds the last data recevied and starts recebving the data from master again). AMBA follows a master-slave relation.
 
In simple tranfer there are two phases:
	1. Address phase - the slave has to receive it when put onto bus it cannot be extended
	2. Data phase - depending uppon the response from the slave the data cylce can be extended and can take upto multiple bus cycles
	3. At first posedge the master puts address onto bus, at the 2nd edge slave reads this address and at 3rd edge slave reads data 
***************************************************************************************************************************************/


//------------------------------------AMBA AHB MASTER MODULE----------------------------------------//
module amab_ahb_simple(HCLK,HADDR,HWDATA,HREADY,HRDATA,HRESET,HTRANS,HBURST,HGRANTx,HRESP,HBUSREQx,HSIZE,HPORT,HWRITE);

parameter n = 32;
integer beat_count=0;
reg [27:0] wrap4_temp;
reg wrap4_bound;
//----------------------------I/O DECLARATIONS-------------------------------------------------//
input HCLK;
input HRESET;
input HREADY;
input [n-1:0] HRDATA;
input HGRANTx;
input [1:0]HRESP; 
reg [1:0]hresp_temp;
output reg [n-1:0] HADDR;
output reg [n-1:0] HWDATA;
output reg [1:0] HTRANS;
output reg [2:0] HBURST;
output reg HBUSREQx;
output reg [2:0] HSIZE;
output reg [3:0] HPORT;
output reg HWRITE;

//----------------------------STATE DEFINATION AND PIPELINE LATCH------------------------------//
reg [5:0] state,next;
reg [n-1:0] HADDR_HWDATA_A;
reg [n-1:0] HADDR_HWDATA_B;
reg [n-1:0] slave_wait_temp;

//----------------------------HBURST[2:0] TYPES-----------------------------------------------//
parameter hburst_single=3'b000; 		//single transfer
parameter hburst_incr=3'b001; 			//incrmental busrt of unspecified length
parameter hburst_wrap4=3'b010;			//4-beat wrapping burst
parameter hburst_incr4=3'b011;			//4-beat incremental busrt
parameter hburst_wrap8=3'b100;			//8-beat wrapping burst
parameter hburst_incr8=3'b101;			//8-beat incremental burst
parameter hburst_wrap16=3'b110;			//16-beat wrapping burst
parameter hburst_incr16=3'b111;			//16-beat incremental burst

//----------------------------HTRANS[1:0] TYPES-----------------------------------------------//
parameter trans_idle=5'b00000;			//master granted permission but does not transfer
parameter trans_busy=5'b00001;			//busy in transaction
parameter trans_nonseq=5'b00010;		//single transfer
parameter trans_seq=5'b00011;			//burst mode

//----------------------------HRESP[1:0] TYPES------------------------------------------------//
parameter resp_okay=2'b00;			//slave response as OKAY
parameter resp_error=2'b01;			//slave response as ERROR
parameter resp_retry_split=2'b10;		//slave response as SPLIT

assign HRESP = hresp_temp;
//----------------------------STATE TRANSITIONS----------------------------------------------//
always @ (posedge HCLK)
	if (!HRESET) 
		state <= trans_idle; 
	
	else 
		state <= next;
	
//----------------------------HTRANS TYPE BEHAVIOUR------------------------------------------//

always @ (state)
begin
	case (state)

			//-----------------------------------IDLE STATE-----------------------------------------------//

		trans_idle: begin
		
			HTRANS = trans_idle;
			HADDR = $random; 
			HADDR_HWDATA_A = HADDR;
 			HADDR_HWDATA_B = $random;
			HWRITE = 1'bx;
			HSIZE = 3'bxxx;
			HPORT = 4'bxxxx;
			HWDATA = HADDR_HWDATA_B;
			next = trans_nonseq;
			hresp_temp = resp_okay;	
		
	end //trans_idle				
		
			//-----------------------------------NONSEQ STATE---------------------------------------------//

		trans_nonseq: begin
			beat_count = 0;
			HTRANS = trans_nonseq;
			HWRITE =1'b1;
			//HWRITE = 1'b0;									//for read(0)/write(1) operation
			HSIZE = 3'b010;										//32-bits combination for HSIZE, i.e. we will use wrap/incremental 4 for our HBURST
			//HBURST = hburst_single;								//Single transfer
			//HBURST = hburst_incr;									//INCREMENTAL transfer of unspecified length
			HBURST = hburst_wrap4;								//WRAP 4
			//HBURST = hburst_incr4;								//INCREMENTAL 4
			//HBURST = hburst_wrap8;								//WRAP 8
			//HBURST = hburst_incr8;								//INCREMENTAL 8
			//HBURST = hburst_wrap16;								//WRAP 16
			//HBURST = hburst_incr16;								//INCREMENTAL 16
			HPORT = 4'bxxxx;
			HADDR_HWDATA_A = 32'h00_00_00_34;								//FF FF = 00 38 (0x38) (BYTES)
														//[31:0][23:16]_[15:8][7:0] = [0][0]_[3][8] (BYTES) 			
			HADDR_HWDATA_B = 32'h11_11_11_34;
			HADDR = HADDR_HWDATA_A;
			//next = trans_busy;
			next = trans_seq;									//condition to by-pass busy state	
		
		end //trans_nonseq
		
			//-----------------------------------BUSY STATE-----------------------------------------------//

		trans_busy: begin
			HTRANS = trans_busy;
			HWRITE =1'b1;
			HSIZE = 3'b010;										//32-bits combination for HSIZE, i.e. we will use wrap/incremental 4 for our HBURST
			//HBURST = hburst_wrap4;								//WRAP 4
			HBURST = hburst_incr4;									//INCREMENTAL 4
			HPORT = 4'bxxxx;
			if (HREADY==1) begin
				HADDR_HWDATA_A = 32'h00_00_00_34;
				HADDR = HADDR_HWDATA_A; $display ("%h", HADDR);
				HADDR_HWDATA_B = 32'h11_11_11_34;
				HWDATA = HADDR_HWDATA_B;
				next = trans_seq;
				hresp_temp = 2'b00;
			end // if (HREADY==1) 
		
		end // trans_busy 
		

			//-----------------------------------SEQ STATE-----------------------------------------------//

		trans_seq: begin
			
			HTRANS = trans_seq;
			//------------------------------------SINGLE && READY 1-------------------------------------//

			if (HBURST==hburst_single && HREADY==1'b1) begin
				HADDR_HWDATA_A = $random;
				HADDR_HWDATA_B = $random;
				HADDR = HADDR_HWDATA_A;
				HWDATA = HADDR_HWDATA_B;
				state = 5'bxxxxx;
				next = trans_idle;
			end // if (HBURST==hburst_single && HREADY==1'b1)

			//------------------------------------SINGLE && READY 0-------------------------------------//

			if (HBURST==hburst_single && HREADY==1'b0) begin
				HADDR_HWDATA_A = HADDR_HWDATA_A;
				HADDR_HWDATA_B = HADDR_HWDATA_B;
				HWDATA = HADDR_HWDATA_B;
				state = 5'bxxxxx;
				HADDR = HADDR_HWDATA_A;
				next = trans_seq;

			end // if (HBURST==hburst_single && HREADY==1'b1)
			//------------------------------------INCR && READY 1--------------------------------------//
			
			if (HBURST==hburst_incr && HREADY==1'b1) begin
				HADDR = HADDR_HWDATA_A;
				HADDR_HWDATA_A = HADDR_HWDATA_A+4;
				HADDR = HADDR_HWDATA_A;							//condition if busy is not a valid state
				HWDATA = HADDR_HWDATA_B;
				HADDR_HWDATA_B = HADDR_HWDATA_B+4;
				state = 5'bxxxxx;
				next = trans_seq;

			end // if (HBURST==hburst_incr && HREADY==1'b1)

			//------------------------------------INCR && READY 0--------------------------------------//

			if (HBURST==hburst_incr && HREADY==1'b0) begin
				HADDR_HWDATA_A = HADDR_HWDATA_A;
				HADDR = HADDR_HWDATA_A;
 				state = 5'bxxxxx;
				next = trans_seq;

			end // if (HBURST==hburst_incr && HREADY==1'b0)
			//------------------------------------INCR4 && READY 1-------------------------------------//	

			if (HBURST==hburst_incr4 && HREADY==1'b1) begin
				if (beat_count != 2) begin	
				HADDR = HADDR_HWDATA_A;
				HADDR_HWDATA_A = HADDR_HWDATA_A+4;
				HADDR = HADDR_HWDATA_A;							//condition if busy is not a valid state
				HWDATA = HADDR_HWDATA_B;
				HADDR_HWDATA_B = HADDR_HWDATA_B+4;
				state = 5'bxxxxx;
				next = trans_seq;
				beat_count = beat_count +1;
				end // if (beat_count != 2)

				else begin
				beat_count = 0;
				HADDR = HADDR_HWDATA_A;
				HADDR_HWDATA_A = HADDR_HWDATA_A+4;
				HADDR = HADDR_HWDATA_A;
				HWDATA = HADDR_HWDATA_B;
				HADDR_HWDATA_B = HADDR_HWDATA_B+4;
				state = 5'bxxxxx;
				next = trans_nonseq;
				end // else (beat_count != 2)
  			
			end //if (HBURST==hburst_incr4 && HREADY==1'b1) 
			
			//-----------------------------------INCR4 && READY 0--------------------------------------//

			else if (HBURST==hburst_incr4 && HREADY==1'b0) begin
				if (beat_count != 2) begin
				HADDR_HWDATA_A = HADDR_HWDATA_A;
				
				if (HADDR_HWDATA_A == HADDR_HWDATA_A) begin
					HADDR = HADDR_HWDATA_A;
 					state = 5'bxxxxx;
					next = trans_seq;
					beat_count = beat_count +1;
				end // if (HADDR_HWDATA_A == HADDR_HWDATA_A)
				
				else begin
					HADDR_HWDATA_B = HADDR_HWDATA_B;
					HWDATA = HADDR_HWDATA_B;
					state = 5'bxxxxx;
					HADDR = HADDR_HWDATA_A;
					next = trans_seq;
					beat_count = beat_count +1;
				end //else
				end // if (beat_count != 2)

				else begin
					HADDR_HWDATA_B = HADDR_HWDATA_B;
					HWDATA = HADDR_HWDATA_B;
					state = 5'bxxxxx;
					HADDR = HADDR_HWDATA_A;
					next = trans_seq;
					beat_count = 0;

				end // else (beat_count != 2) 
			end // else if (HBURST==hburst_incr4 && HREADY==1'b0)
			
			//------------------------------------INCR8 && READY 1-------------------------------------//
			
			if (HBURST==hburst_incr8 && HREADY==1'b1) begin
				if (beat_count != 6) begin	
				HADDR = HADDR_HWDATA_A;
				HADDR_HWDATA_A = HADDR_HWDATA_A+4;
				HADDR = HADDR_HWDATA_A;							//condition if busy is not a valid state
				HWDATA = HADDR_HWDATA_B;
				HADDR_HWDATA_B = HADDR_HWDATA_B+4;
				state = 5'bxxxxx;
				next = trans_seq;
				beat_count = beat_count +1;
				end // if (beat_count != 6)

				else begin
				beat_count = 0;
				HADDR = HADDR_HWDATA_A;
				HADDR_HWDATA_A = HADDR_HWDATA_A+4;
				HADDR = HADDR_HWDATA_A;
				HWDATA = HADDR_HWDATA_B;
				HADDR_HWDATA_B = HADDR_HWDATA_B+4;
				state = 5'bxxxxx;
				next = trans_nonseq;
				end // else (beat_count != 6)
  			
			end //if (HBURST==hburst_incr8 && HREADY==1'b1)

			//-----------------------------------INCR8 && READY 0--------------------------------------//

			else if (HBURST==hburst_incr8 && HREADY==1'b0) begin
				if (beat_count != 6) begin
				HADDR_HWDATA_A = HADDR_HWDATA_A;
				
				if (HADDR_HWDATA_A == HADDR_HWDATA_A) begin
					HADDR = HADDR_HWDATA_A;
 					state = 5'bxxxxx;
					next = trans_seq;
					beat_count = beat_count +1;
				end // if (HADDR_HWDATA_A == HADDR_HWDATA_A)
				
				else begin
					HADDR_HWDATA_B = HADDR_HWDATA_B;
					HWDATA = HADDR_HWDATA_B;
					state = 5'bxxxxx;
					HADDR = HADDR_HWDATA_A;
					next = trans_seq;
					beat_count = beat_count +1;
				end //else
				end // if (beat_count != 6)

				else begin
					HADDR_HWDATA_B = HADDR_HWDATA_B;
					HWDATA = HADDR_HWDATA_B;
					state = 5'bxxxxx;
					HADDR = HADDR_HWDATA_A;
					next = trans_seq;
					beat_count = 0;

				end // else (beat_count != 6) 
			end // else if (HBURST==hburst_incr8 && HREADY==1'b0)
			
			//-----------------------------------INCR16 && READY 1--------------------------------------//
	
			if (HBURST==hburst_incr16 && HREADY==1'b1) begin
				if (beat_count != 14) begin	
				HADDR = HADDR_HWDATA_A;
				HADDR_HWDATA_A = HADDR_HWDATA_A+4;
				HADDR = HADDR_HWDATA_A;							//condition if busy is not a valid state
				HWDATA = HADDR_HWDATA_B;
				HADDR_HWDATA_B = HADDR_HWDATA_B+4;
				state = 5'bxxxxx;
				next = trans_seq;
				beat_count = beat_count +1;
				end // if (beat_count != 14)

				else begin
				beat_count = 0;
				HADDR = HADDR_HWDATA_A;
				HADDR_HWDATA_A = HADDR_HWDATA_A+4;
				HADDR = HADDR_HWDATA_A;
				HWDATA = HADDR_HWDATA_B;
				HADDR_HWDATA_B = HADDR_HWDATA_B+4;
				state = 5'bxxxxx;
				next = trans_nonseq;
				end // else (beat_count != 14)
  			
			end //if (HBURST==hburst_incr16 && HREADY==1'b1)

			//-----------------------------------INCR16 && READY 0--------------------------------------//

			else if (HBURST==hburst_incr16 && HREADY==1'b0) begin
				if (beat_count != 14) begin
				HADDR_HWDATA_A = HADDR_HWDATA_A;
				
				if (HADDR_HWDATA_A == HADDR_HWDATA_A) begin
					HADDR = HADDR_HWDATA_A;
 					state = 5'bxxxxx;
					next = trans_seq;
					beat_count = beat_count +1;
				end // if (HADDR_HWDATA_A == HADDR_HWDATA_A)
				
				else begin
					HADDR_HWDATA_B = HADDR_HWDATA_B;
					HWDATA = HADDR_HWDATA_B;
					state = 5'bxxxxx;
					HADDR = HADDR_HWDATA_A;
					next = trans_seq;
					beat_count = beat_count +1;
				end //else
				end // if (beat_count != 14)

				else begin
					HADDR_HWDATA_B = HADDR_HWDATA_B;
					HWDATA = HADDR_HWDATA_B;
					state = 5'bxxxxx;
					HADDR = HADDR_HWDATA_A;
					next = trans_seq;
					beat_count = 0;

				end // else (beat_count != 14) 
			end // else if (HBURST==hburst_incr16 && HREADY==1'b0)


			//------------------------------------WRAP4 && READY 1------------------------------------//

			else if (HBURST==hburst_wrap4 && HREADY==1'b1) begin
				if (HADDR_HWDATA_A [4] == HADDR_HWDATA_A [4]) begin 
				$display ($time,"NOT CHNAGED IF STARTED AT START %b",HADDR_HWDATA_A[4]);
					if (beat_count!=2) begin
						HADDR = HADDR_HWDATA_A;
						HADDR_HWDATA_A[7:0] =  HADDR_HWDATA_A[7:0] + 4; 			//1st BYTE
						HADDR_HWDATA_A[15:8] = HADDR_HWDATA_A[15:8];				//2nd BYTE
						HADDR_HWDATA_A[23:16] = HADDR_HWDATA_A[23:16];				//3rd BYTE
						HADDR_HWDATA_A[31:24] = HADDR_HWDATA_A[31:24];				//4th BYTE  
						
						HADDR_HWDATA_A  = {HADDR_HWDATA_A [31:24],HADDR_HWDATA_A [23:16],HADDR_HWDATA_A [15:8],HADDR_HWDATA_A[7:0]}; 		//WRAP4, the last byte will increment 4 times byte addressable
						HADDR = HADDR_HWDATA_A;							//condition if busy is not a valid state
						HWDATA = HADDR_HWDATA_B;
						HADDR_HWDATA_B = HADDR_HWDATA_B+4;
						state = 5'bxxxxx;
						next = trans_seq;	
						beat_count = beat_count+1;
						$display ($time,"BIT CHECKING AT LAST %b",HADDR_HWDATA_A[4]);
					end // if (beat_count!=2)	
					
				else begin
				$display ($time,"BIT CHANGED AND ELSE STARTED %b",HADDR_HWDATA_A[4]);
					beat_count = beat_count+1;
					HADDR_HWDATA_A =  HADDR_HWDATA_A;
					HADDR_HWDATA_A [31:4] = HADDR_HWDATA_A [31:4]; 
					HADDR_HWDATA_A[3:0] =  HADDR_HWDATA_A[3:0]+4;				//1st BYTE 4 BITS 
					next = trans_nonseq;
					HADDR = {HADDR_HWDATA_A [31:4],HADDR_HWDATA_A[3:0]};							//condition if busy is not a valid state
					HWDATA = HADDR_HWDATA_B;
					HADDR_HWDATA_B = HADDR_HWDATA_B+4;
				end // else (HADDR_HWDATA_A [4] == HADDR_HWDATA_A [4])			
			
				end // if (HADDR_HWDATA_A [4] == HADDR_HWDATA_A [4] )
			
			end // else if (HBURST=hburst_wrap4 && HREADY=1'b1)


 			//------------------------------------WRAP8 && READY 1------------------------------------//

			else if (HBURST==hburst_wrap8 && HREADY==1'b1) begin
				if (HADDR_HWDATA_A [5] == HADDR_HWDATA_A [5]) begin
					if (beat_count!=6) begin
						HADDR = HADDR_HWDATA_A;
						HADDR_HWDATA_A[31:5] = HADDR_HWDATA_A[31:5];
						HADDR_HWDATA_A[4:0] = HADDR_HWDATA_A[4:0]+4;
						HADDR_HWDATA_A  = {HADDR_HWDATA_A [31:5],HADDR_HWDATA_A[4:0]};
						HADDR = HADDR_HWDATA_A;							
						HWDATA = HADDR_HWDATA_B;
						HADDR_HWDATA_B = HADDR_HWDATA_B+8;
						state = 5'bxxxxx;
						next = trans_seq;	
						beat_count = beat_count+1;
					end // if (beat_count!=6)

				else begin
					beat_count = beat_count +1;
					HADDR_HWDATA_A =  HADDR_HWDATA_A;
					HADDR_HWDATA_A[31:5] = HADDR_HWDATA_A[31:5];
					HADDR_HWDATA_A[4:0] = HADDR_HWDATA_A[4:0]+4;
					HADDR_HWDATA_A  = {HADDR_HWDATA_A [31:5],HADDR_HWDATA_A[4:0]};
					next = trans_nonseq;
					HADDR = HADDR_HWDATA_A;
					HWDATA = HADDR_HWDATA_B;
					HADDR_HWDATA_B = HADDR_HWDATA_B+8;
					end // else (HADDR_HWDATA_A [5] == HADDR_HWDATA_A [5])							
			
				end // if (HADDR_HWDATA_A [5] == HADDR_HWDATA_A [5]) 
			
			end // else if (HBURST==hburst_wrap8 && HREADY==1'b1)

			//------------------------------------WRAP16 && READY 1------------------------------------//
	
			else if (HBURST==hburst_wrap16 && HREADY==1'b1) begin
				if (HADDR_HWDATA_A [6] == HADDR_HWDATA_A [6]) begin
					if (beat_count!=14) begin
						HADDR = HADDR_HWDATA_A;
						HADDR_HWDATA_A[31:6] = HADDR_HWDATA_A[31:6];
						HADDR_HWDATA_A[5:0] = HADDR_HWDATA_A[5:0]+4;
						HADDR_HWDATA_A  = {HADDR_HWDATA_A [31:6],HADDR_HWDATA_A[5:0]};
						HADDR = HADDR_HWDATA_A;							
						HWDATA = HADDR_HWDATA_B;
						HADDR_HWDATA_B = HADDR_HWDATA_B+8;
						state = 5'bxxxxx;
						next = trans_seq;	
						beat_count = beat_count+1;
					end // if (beat_count!=14)

				else begin
					beat_count = beat_count +1;
					HADDR_HWDATA_A =  HADDR_HWDATA_A;
					HADDR_HWDATA_A[31:6] = HADDR_HWDATA_A[31:6];
					HADDR_HWDATA_A[5:0] = HADDR_HWDATA_A[5:0]+4;
					HADDR_HWDATA_A  = {HADDR_HWDATA_A [31:6],HADDR_HWDATA_A[5:0]};
					next = trans_nonseq;
					HADDR = HADDR_HWDATA_A;
					HWDATA = HADDR_HWDATA_B;
					HADDR_HWDATA_B = HADDR_HWDATA_B+8;
					end // else (HADDR_HWDATA_A [6] == HADDR_HWDATA_A [6])						
			
				end // if (HADDR_HWDATA_A [6] == HADDR_HWDATA_A [6]) 
			
			end // else if (HBURST==hburst_wrap16 && HREADY==1'b1)

		end // trans_seq
		
		default : next = trans_idle;
	
	endcase

end
endmodule 

//-----------------------------------TOP MODULE FOR CONTROL SIGNALS--------------------------------//
module amba_ahb_simple_top();

wire [31:0] HADDR;
wire [31:0] HWDATA;
wire [1:0] HTRANS;
wire [2:0] HBURST;
wire HBUSREQx;
wire [2:0] HSIZE;
wire [3:0] HPORT;
wire HWRITE;
wire [2:0] HSEL;
reg HCLK, HRESET,HREADY;
reg [31:0] HRDATA;
reg HGRANTx;
reg [1:0]HRESP;
reg HADDR_DEC;
 
amab_ahb_simple ahb_simple_1(HCLK,HADDR,HWDATA,HREADY,HRDATA,HRESET,HTRANS,HBURST,HGRANTx,HRESP,HBUSREQx,HSIZE,HPORT,HWRITE);
//address_decoder decoder_1 (HSEL,HADDR);
initial
begin
	HCLK =0;
	HREADY = 0;		
	HRESET = 1;
	#5 HRESET = 0;
	#1 HRESET = 1;
	//HREADY stimulus without WAIT states
	#9 HREADY =1;
	
	//HREADY stimulus with WAIT states
	#101;
	#40  HREADY = 0;
	
	//HREAY stimulus without wait states to resume the simple operation again
	#101; 
	#20 HREADY = 1;
	
	#60 HREADY = 0;
	
	#20 HREADY = 1;

	HRDATA = ahb_simple_1.HWDATA;
end

always 
	#5 HCLK = ~HCLK; //CLOCK WITH 10 UNITS TIME PERIOD
endmodule 
/*
//----------------------------CENTERAL ADDRESS DECODER MODULE (COMBO)------------------------------//
module address_decoder (HSEL,HADDR_DEC); 

//----------------------------I/O PORTS DECLARATIONS--------------------------------------//
output [2:0] HSEL;				//3 slaves HSEL[1],HSEL[2],HSEL[3]
input [31:0] HADDR_DEC;				//32bit slave address

parameter hsel_1_addr = 8'b00_00_00_00;		//pre configured high order (8 bits or 1 byte) address for slave 1
parameter hsel_2_addr = 8'b00_00_00_01;		//pre comfigured high order (8 bits or 1 byte) address for slave 2
parameter hsel_3_addr = 8'b00_00_00_10;		//pre comfigured high order (8 bits or 1 byte) address for slave 3
 
assign HSEL[0] = (HADDR_DEC [31:24]==hsel_1_addr) ? 1'b1 : 1'b0;
assign HSEL[1] = (HADDR_DEC [31:24]==hsel_2_addr) ? 1'b1 : 1'b0;
assign HSEL[2] = (HADDR_DEC [31:24]==hsel_3_addr) ? 1'b1 : 1'b0;


endmodule
//------------------------------------ADDRESS AND CONTROL MUX-------------------------------------//
module address_control_mux (HADDR_MUX,HADDR_M1,HADDR_M2,HGRANT);

output [31:0]HADDR_MUX;
input [31:0] HADDR_M1, HADDR_M2;
input HGRANT;

assign HADDR_MUX = (HGRANT==1'b1) ? HADDR_M1 : HADDR_M2;  //2:1 MUX with HGRANT as Select Line 

endmodule
*/ 