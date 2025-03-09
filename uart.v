`timescale 1ns/1ps

module uart_top (
    input wire clk,         // 100MHz clock
    input wire rst,         // Reset
    input wire rx,          // RX input pin
    output wire tx,         // TX output pin
    output wire pwm_out     // PWM output signal
);

    wire [7:0] rx_data;
    wire rx_done;
    reg [7:0] duty_cycle;
    reg tx_start;
    wire tx_busy;

    // UART RX Module
    uart_rx rx_module (
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .rx_data(rx_data),
        .rx_done(rx_done)
    );

    // Capture received data as duty cycle
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            duty_cycle <= 8'd0;
            tx_start <= 1'b0;
        end else if (rx_done && !tx_busy) begin
            duty_cycle <= rx_data; // Assign received data to duty cycle
            tx_start <= 1'b1;
        end else begin
            tx_start <= 1'b0; // Ensure single pulse for TX start
        end
    end

    // UART TX Module (sends back duty cycle value)
    uart_tx tx_module (
        .clk(clk),
        .rst(rst),
        .tx_start(tx_start),
        .tx_data(duty_cycle),
        .tx(tx),
        .tx_busy(tx_busy)
    );

    // PWM Generator Module
    pwm_generator pwm_module (
        .clk(clk),
        .rst(rst),
        .duty_cycle(duty_cycle),
        .pwm_out(pwm_out)
    );

endmodule

module uart_tx (
    input wire clk,       
    input wire rst,       
    input wire tx_start,  
    input wire [7:0] tx_data, 
    output reg tx,        
    output reg tx_busy    
);

    parameter CLK_PER_BIT = 10416; // 9600 baud at 100MHz clock

    reg [13:0] clk_count = 0;
    reg [3:0] bit_index = 0;
    reg [9:0] tx_shift_reg = 10'sb1111111111;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tx <= 1'b1;
            tx_busy <= 1'b0;
            clk_count <= 0;
            bit_index <= 0;
            tx_shift_reg <= 10'b1111111111;
        end else if (tx_start && !tx_busy) begin
            tx_busy <= 1'b1;
            tx_shift_reg <= {1'b1, tx_data, 1'b0};
            clk_count <= 0;
            bit_index <= 0;
        end else if (tx_busy) begin
            if (clk_count == CLK_PER_BIT - 1) begin
                clk_count <= 0;
                tx <= tx_shift_reg[0];
                tx_shift_reg <= {1'b1, tx_shift_reg[9:1]};
                if (bit_index < 9) begin
                    bit_index <= bit_index + 1;
                end else begin
                    tx_busy <= 1'b0;
                end
            end else begin
                clk_count <= clk_count + 1;
            end
        end
    end

endmodule

module uart_rx (
    input wire clk,      
    input wire rst,      
    input wire rx,       
    output reg [7:0] rx_data, 
    output reg rx_done  
);

    parameter CLK_PER_BIT = 10416; 

    reg [13:0] clk_count = 0;
    reg [3:0] bit_index = 0;
    reg [9:0] rx_shift_reg = 0;
    reg rx_active = 0;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_data <= 8'b0;
            rx_done <= 0;
            clk_count <= 0;
            bit_index <= 0;
            rx_shift_reg <= 0;
            rx_active <= 0;
        end else begin
            if (!rx_active && rx == 0) begin  
                rx_active <= 1;
                clk_count <= 0;
                bit_index <= 0;
            end else if (rx_active) begin
                if (clk_count == CLK_PER_BIT - 1) begin
                    clk_count <= 0;
                    rx_shift_reg <= {rx, rx_shift_reg[9:1]}; 

                    if (bit_index < 9) begin
                        bit_index <= bit_index + 1;
                    end else begin
                        rx_active <= 0;
                        rx_done <= 1;
                        rx_data <= rx_shift_reg[8:1];
                    end
                end else begin
                    clk_count <= clk_count + 1;
                end
            end else begin
                rx_done <= 0;
            end
        end
    end

endmodule

module pwm_generator (
    input wire clk,
    input wire rst,
    input wire [7:0] duty_cycle, 
    output reg pwm_out
);
    
    reg [7:0] counter;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter <= 8'd0;
            pwm_out <= 1'b0;
        end else begin
            counter <= counter + 8'd1;
            pwm_out <= (counter < duty_cycle) ? 1'b1 : 1'b0;
        end
    end

endmodule