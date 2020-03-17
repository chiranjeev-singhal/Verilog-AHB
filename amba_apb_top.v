/* This is the stimulus block for AMBA APB, here we will provide all the inputs and control signals

*/

module amba_apb_top();

wire [0:31] prdata;
reg pclk,preset,psel,penable,pwrite,pready;
reg [0:31] paddr,pwdata;

amba_apb AMBA_APB(pclk,preset,psel,penable,pwrite,paddr,pwdata,prdata,pready);

initial
begin
pclk = 0;
psel=0;
penable=0;
preset = 1;
paddr = 0;
pwdata=0;

#2 preset = 0; 
#1 preset = 1;	

end

initial
begin
	//write cycle inputs
	#14 psel = 1; paddr =8'h60;penable=0; pwrite = 1; pwdata=32'haa;
	#10 penable = 1;
	//idle state inputs
	#12 paddr=0;pwdata=0;pwrite=0;pwdata=32'hz;
	//read cycle inputs
	#8 psel = 1; paddr =8'h60;penable=0; pwrite = 0; 
	#10 penable = 1;
	//idle state inputs after read cycle
	#12 penable=0; psel=0;paddr=0;pwdata=0;pwrite=0;
end
always 
	#5 pclk=~pclk;

endmodule 