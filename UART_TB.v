`timescale 1ns/1ps

module uart_tb;
    reg clk;
    reg rst;
    reg rx;
    wire tx;
    wire pwm_out;

    // Instantiate the UART top module
    uart_top uut (
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .tx(tx),
        .pwm_out(pwm_out)
    );

    // Clock generation (100MHz clock)
    always begin
        #5 clk = ~clk; // 100MHz clock with a period of 10ns
    end

    // Task to send a byte through RX
    task send_byte;
        input [7:0] data;
        integer i;
        begin
            rx = 0; // Start bit
            #104160; // Wait for one bit time (9600 baud)
            for (i = 0; i < 8; i = i + 1) begin
                rx = data[i];
                #104160;
            end
            rx = 1; // Stop bit
            #104160;
        end
    endtask

    // Test procedure
    initial begin
        // Initialize signals
        clk = 0;
        rst = 1;
        rx = 1; // Default idle state

        // Apply reset
        #20 rst = 1;
        #20 rst = 0;

        // Send duty cycle value
        #200;
        send_byte(8'h50); // Send 50% duty cycle

        // Wait for transmission to complete
        #20000000;

        $stop;  // End simulation
    end
endmodule
