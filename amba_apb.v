/* AMBA - Advanced Microcontroller Bus Architecture is a on-chip communication protocol. It is widely
used in SoC and ASIC and also these days in Smartphones. AMBA has been revised several times depending 
upon the requirements with increasing device functionality. AMBA consists of 3 components:-
	1. AHB or ASB - Advanced high speed bus for high bandwidth and high performance---AHB-lite.
	2. APB - Advanced Peripeheral Bus for low bandwidth low performance
*/

module amba_apb(pclk,preset,psel,penable,pwrite,paddr,pwdata,prdata,pready);

input pclk;					// clock signal
input preset;					// 1bit reset signal
input psel;					// 1bit select signal
input penable;					// 1bit enable signal
input pwrite;					// direction signal (1=write/0=read)
input [0:31] paddr;				// 32 bit address bus
input [0:31] pwdata;				// 32 bit wire data bus
output reg [0:31] prdata;			// 32 bit read data bus
input  pready;					// ready signal

reg [0:1] state,next;				//2 bit state change variable

parameter idle=2'b00;				//initial idle state
parameter setup=2'b01;				//data is made stable in this state to be accessed in the next
parameter access=2'b10;				//data is accessed in this state

reg [0:31]pwdata_temp;				//temp reg to store data to be written
reg temp_psel;
reg temp_penable;


always @ (posedge pclk or negedge preset)
	if (!preset)
		state<=idle;
	else 	
		state<=next;

always @ (state or preset or psel or penable or pwrite or paddr or pwdata)
begin
	case (state)
		idle : begin
			temp_psel=1'b0;
			temp_penable=1'b0;
			if (psel==1) next=setup;
			else next=idle; 
		end
		
		setup: begin
			temp_psel=1'b1;
			temp_penable=1'b0;
			pwdata_temp=32'h0;
			next=access;
			
		end
	
		access: begin
			if (pwrite==1 && penable==1) begin
				pwdata_temp=pwdata;	
				next = idle;
			end
			else if (pwrite==0 && penable==1)begin
				//prdata=32'haa;
				prdata=pwdata_temp;	
				next = idle;
			end
			
			else next=idle;
		end
	endcase

end

endmodule 