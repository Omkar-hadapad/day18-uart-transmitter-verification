
`timescale 1ns/1ps

//==============================================================
// DAY 18 - UART TRANSMITTER
// Complete hierarchical design in one Verilog file
//
// UART: 8-N-1, LSB first
// CLKS_PER_BIT = 4
// Reset: active-low asynchronous
//
// HIERARCHY:
// Gates -> Half Adder -> Full Adder -> Incrementer
// -> Baud Counter -> Data Register -> Bit Counter
// -> UART FSM -> TX Logic -> Structural UART
// -> RTL UART -> TOP
//==============================================================


//==============================================================
// 1. BASIC LOGIC GATES
//==============================================================

module logic_gates (
    input  wire a,
    input  wire b,
    output wire y_and,
    output wire y_or,
    output wire y_xor,
    output wire y_not
);
    assign y_and = a & b;
    assign y_or  = a | b;
    assign y_xor = a ^ b;
    assign y_not = ~a;
endmodule


//==============================================================
// 2. HALF ADDER
//==============================================================

module half_adder (
    input  wire a,
    input  wire b,
    output wire sum,
    output wire carry
);
    assign sum   = a ^ b;
    assign carry = a & b;
endmodule


//==============================================================
// 3. FULL ADDER
//==============================================================

module full_adder (
    input  wire a,
    input  wire b,
    input  wire cin,
    output wire sum,
    output wire cout
);
    wire s1;
    wire c1;
    wire c2;

    half_adder HA1 (
        .a(a),
        .b(b),
        .sum(s1),
        .carry(c1)
    );

    half_adder HA2 (
        .a(s1),
        .b(cin),
        .sum(sum),
        .carry(c2)
    );

    assign cout = c1 | c2;
endmodule


//==============================================================
// 4. PARAMETERIZED INCREMENTER
//==============================================================

module incrementer #(
    parameter WIDTH = 4
)(
    input  wire [WIDTH-1:0] value_in,
    output wire [WIDTH-1:0] value_out
);
    assign value_out = value_in + {{(WIDTH-1){1'b0}}, 1'b1};
endmodule


//==============================================================
// 5. BAUD COUNTER
// Generates baud_tick once every CLKS_PER_BIT clocks
// while enable is high.
//==============================================================

module baud_counter #(
    parameter integer CLKS_PER_BIT = 4,
    parameter integer WIDTH =
        (CLKS_PER_BIT <= 1) ? 1 : $clog2(CLKS_PER_BIT)
)(
    input  wire clk,
    input  wire rst_n,
    input  wire enable,
    output wire baud_tick
);
    reg [WIDTH-1:0] count;
    wire [WIDTH-1:0] count_next;

    incrementer #(.WIDTH(WIDTH)) INC (
        .value_in(count),
        .value_out(count_next)
    );

    assign baud_tick =
        enable && (count == CLKS_PER_BIT - 1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= {WIDTH{1'b0}};
        else if (!enable)
            count <= {WIDTH{1'b0}};
        else if (baud_tick)
            count <= {WIDTH{1'b0}};
        else
            count <= count_next;
    end

endmodule


//==============================================================
// 6. 8-BIT DATA REGISTER
// Supports parallel load, shift-right, and hold.
//==============================================================

module uart_data_register (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       load,
    input  wire       shift,
    input  wire [7:0] data_in,
    output wire       serial_bit,
    output reg  [7:0] data_out
);
    assign serial_bit = data_out[0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            data_out <= 8'h00;
        else if (load)
            data_out <= data_in;
        else if (shift)
            data_out <= {1'b0, data_out[7:1]};
    end

endmodule


//==============================================================
// 7. 3-BIT DATA BIT COUNTER
// Counts transmitted data bits from 0 through 7.
//==============================================================

module uart_bit_counter (
    input  wire clk,
    input  wire rst_n,
    input  wire clear,
    input  wire increment,
    output wire bit_last,
    output reg  [2:0] bit_count
);
    wire [2:0] count_next;

    incrementer #(.WIDTH(3)) INC (
        .value_in(bit_count),
        .value_out(count_next)
    );

    assign bit_last = (bit_count == 3'd7);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bit_count <= 3'd0;
        else if (clear)
            bit_count <= 3'd0;
        else if (increment)
            bit_count <= count_next;
    end

endmodule


//==============================================================
// 8. UART FINITE STATE MACHINE
//
// IDLE -> START -> DATA -> STOP -> IDLE
//==============================================================

module uart_fsm (
    input  wire clk,
    input  wire rst_n,
    input  wire tx_start,
    input  wire baud_tick,
    input  wire bit_last,

    output reg  [1:0] state,
    output wire load_data,
    output wire shift_data,
    output wire clear_bit_count,
    output wire increment_bit_count,
    output reg  tx_done
);
    localparam [1:0] IDLE  = 2'd0;
    localparam [1:0] START = 2'd1;
    localparam [1:0] DATA  = 2'd2;
    localparam [1:0] STOP  = 2'd3;

    assign load_data =
        (state == IDLE) && tx_start;

    assign shift_data =
        (state == DATA) && baud_tick;

    assign clear_bit_count =
        (state != DATA);

    assign increment_bit_count = shift_data;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= IDLE;
            tx_done <= 1'b0;
        end else begin
            tx_done <= 1'b0;

            case (state)
                IDLE: begin
                    if (tx_start)
                        state <= START;
                end

                START: begin
                    if (baud_tick)
                        state <= DATA;
                end

                DATA: begin
                    if (baud_tick && bit_last)
                        state <= STOP;
                end

                STOP: begin
                    if (baud_tick) begin
                        state   <= IDLE;
                        tx_done <= 1'b1;
                    end
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule


//==============================================================
// 9. TX OUTPUT LOGIC
//==============================================================

module uart_tx_logic (
    input  wire [1:0] state,
    input  wire       data_bit,
    output reg        tx_serial
);
    localparam [1:0] IDLE  = 2'd0;
    localparam [1:0] START = 2'd1;
    localparam [1:0] DATA  = 2'd2;
    localparam [1:0] STOP  = 2'd3;

    always @(*) begin
        case (state)
            IDLE:    tx_serial = 1'b1;
            START:   tx_serial = 1'b0;
            DATA:    tx_serial = data_bit;
            STOP:    tx_serial = 1'b1;
            default: tx_serial = 1'b1;
        endcase
    end

endmodule


//==============================================================
// 10. STRUCTURAL UART
// Integrates the counter, data register, bit counter, FSM,
// and serial output logic.
//==============================================================

module uart_tx_structural #(
    parameter integer CLKS_PER_BIT = 4
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tx_start,
    input  wire [7:0] tx_data,
    output wire       tx_serial,
    output wire       tx_busy,
    output wire       tx_done
);
    localparam [1:0] IDLE = 2'd0;

    wire [1:0] state;
    wire baud_tick;
    wire load_data;
    wire shift_data;
    wire clear_bit_count;
    wire increment_bit_count;
    wire bit_last;
    wire serial_bit;

    wire [2:0] bit_count;
    wire [7:0] data_out;

    assign tx_busy = (state != IDLE);

    baud_counter #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) BAUD (
        .clk(clk),
        .rst_n(rst_n),
        .enable(tx_busy),
        .baud_tick(baud_tick)
    );

    uart_data_register DATA_REG (
        .clk(clk),
        .rst_n(rst_n),
        .load(load_data),
        .shift(shift_data),
        .data_in(tx_data),
        .serial_bit(serial_bit),
        .data_out(data_out)
    );

    uart_bit_counter BIT_COUNT (
        .clk(clk),
        .rst_n(rst_n),
        .clear(clear_bit_count),
        .increment(increment_bit_count),
        .bit_last(bit_last),
        .bit_count(bit_count)
    );

    uart_fsm FSM (
        .clk(clk),
        .rst_n(rst_n),
        .tx_start(tx_start),
        .baud_tick(baud_tick),
        .bit_last(bit_last),
        .state(state),
        .load_data(load_data),
        .shift_data(shift_data),
        .clear_bit_count(clear_bit_count),
        .increment_bit_count(increment_bit_count),
        .tx_done(tx_done)
    );

    uart_tx_logic TX_OUTPUT (
        .state(state),
        .data_bit(serial_bit),
        .tx_serial(tx_serial)
    );

endmodule


//==============================================================
// 11. BEHAVIORAL RTL UART
// Independent behavioral implementation for comparison.
//==============================================================

module uart_tx_rtl #(
    parameter integer CLKS_PER_BIT = 4,
    parameter integer TIMER_WIDTH =
        (CLKS_PER_BIT <= 1) ? 1 : $clog2(CLKS_PER_BIT)
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tx_start,
    input  wire [7:0] tx_data,
    output reg        tx_serial,
    output wire       tx_busy,
    output reg        tx_done
);
    localparam [1:0] IDLE  = 2'd0;
    localparam [1:0] START = 2'd1;
    localparam [1:0] DATA  = 2'd2;
    localparam [1:0] STOP  = 2'd3;

    reg [1:0] state;
    reg [TIMER_WIDTH-1:0] timer;
    reg [2:0] bit_index;
    reg [7:0] shift_reg;

    assign tx_busy = (state != IDLE);

    always @(*) begin
        case (state)
            IDLE:    tx_serial = 1'b1;
            START:   tx_serial = 1'b0;
            DATA:    tx_serial = shift_reg[0];
            STOP:    tx_serial = 1'b1;
            default: tx_serial = 1'b1;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            timer     <= {TIMER_WIDTH{1'b0}};
            bit_index <= 3'd0;
            shift_reg <= 8'h00;
            tx_done   <= 1'b0;
        end else begin
            tx_done <= 1'b0;

            case (state)
                IDLE: begin
                    timer     <= {TIMER_WIDTH{1'b0}};
                    bit_index <= 3'd0;

                    if (tx_start) begin
                        shift_reg <= tx_data;
                        state     <= START;
                    end
                end

                START: begin
                    if (timer == CLKS_PER_BIT - 1) begin
                        timer <= {TIMER_WIDTH{1'b0}};
                        state <= DATA;
                    end else begin
                        timer <= timer + 1'b1;
                    end
                end

                DATA: begin
                    if (timer == CLKS_PER_BIT - 1) begin
                        timer     <= {TIMER_WIDTH{1'b0}};
                        shift_reg <= {1'b0, shift_reg[7:1]};

                        if (bit_index == 3'd7)
                            state <= STOP;
                        else
                            bit_index <= bit_index + 1'b1;
                    end else begin
                        timer <= timer + 1'b1;
                    end
                end

                STOP: begin
                    if (timer == CLKS_PER_BIT - 1) begin
                        timer   <= {TIMER_WIDTH{1'b0}};
                        state   <= IDLE;
                        tx_done <= 1'b1;
                    end else begin
                        timer <= timer + 1'b1;
                    end
                end

                default: begin
                    state <= IDLE;
                    timer <= {TIMER_WIDTH{1'b0}};
                end
            endcase
        end
    end

endmodule


//==============================================================
// 12. TOP MODULE
// Default top-level design is the structural implementation.
//==============================================================

module uart_tx_top #(
    parameter integer CLKS_PER_BIT = 4
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tx_start,
    input  wire [7:0] tx_data,
    output wire       tx_serial,
    output wire       tx_busy,
    output wire       tx_done
);
    uart_tx_structural #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) UART (
        .clk(clk),
        .rst_n(rst_n),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx_serial(tx_serial),
        .tx_busy(tx_busy),
        .tx_done(tx_done)
    );

endmodule
