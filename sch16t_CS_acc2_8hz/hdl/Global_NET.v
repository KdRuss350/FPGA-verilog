`timescale 1 ns/100 ps
// Version: 9.0 9.0.0.15


module Global_NET(
       A,
       Y
    );
input  A;
output Y;

    wire GND_net, VCC_net;
    
	
	
	CLKINT CLKINT (.A(A), .Y(Y));
    //PWR PWR (.Y(VCC_net));
    //GLINT GLINT_0 (.A(A), .GL(Y));
    //GND GND (.Y(GND_net));
    
endmodule
