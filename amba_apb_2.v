/* AMBA-APB TRIAL 2....with internal registers 
*/

module amba_apb(pclk,preset,psel,penable,pwrite,paddr,pwdata,prdata,pready);

input pclk;					// clock signal
input preset;					// reset signal
input psel;					// select signal
input penable;					// enable signal
input pwrite;					// direction signal
input [0:31] paddr;				// 32 bit address bus
input [0:31] pwdata;				// 32 bit wire data bus
output reg [0:31] prdata;			// 32 bit read data bus
input  pready;					// ready signal

reg [0:1] state,next;

parameter idle=2'b00;
parameter setup=2'b01;
parameter access=2'b10;

reg p_sel;
reg p_enable;
reg p_write;
reg [0:31]p_addr;
reg [0:31]p_wdata;
reg p_ready;

always @ (posedge pclk or negedge preset)
	if (!preset)
		state<=idle;
	else
		state<=next;

always @ (state,psel,penable,pwrite,paddr,pwdata,pready)
begin
	case (state)
		idle: begin
			p_sel=0;
			p_enable=0;
			next=setup;
	
		end

		setup: begin
			p_sel=#2 1'b1;		//SETUP state starts
			p_enable=0;
			p_addr = 32'hff;
			p_write=0;
			p_wdata=32'haa;
			next=access;
		end

		access: begin
			p_sel=1'b1;
			p_enable=#2 1'b1;	//access starts	
			

		end


	endcase
end
endmodule 