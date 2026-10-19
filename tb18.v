`timescale 1ns/1ps

// DAY 18 UART TRANSMITTER - SELF-CHECKING HIERARCHICAL TESTBENCH
// Compatible with the supplied design file containing:
// logic_gates, half_adder, full_adder, incrementer, baud_counter,
// uart_data_register, uart_bit_counter, uart_fsm, uart_tx_logic,
// uart_tx_structural, uart_tx_rtl, uart_tx_top.
//
// UART format: 8-N-1, LSB first, CLKS_PER_BIT = 4
// Reset: active-low asynchronous
//
// Set this testbench as the simulation top: tb18

module tb18;

    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg rst_n = 1'b0;

    integer pass_count = 0;
    integer fail_count = 0;
    integer i, j, k;

    // ----------------------------------------------------------
    // 1. LOGIC GATES
    // ----------------------------------------------------------
    reg ga, gb;
    wire g_and, g_or, g_xor, g_not;

    logic_gates GATES (
        .a(ga), .b(gb),
        .y_and(g_and), .y_or(g_or),
        .y_xor(g_xor), .y_not(g_not)
    );

    // ----------------------------------------------------------
    // 2. HALF ADDER
    // ----------------------------------------------------------
    reg ha_a, ha_b;
    wire ha_sum, ha_carry;

    half_adder HA (
        .a(ha_a), .b(ha_b),
        .sum(ha_sum), .carry(ha_carry)
    );

    // ----------------------------------------------------------
    // 3. FULL ADDER
    // ----------------------------------------------------------
    reg fa_a, fa_b, fa_cin;
    wire fa_sum, fa_cout;

    full_adder FA (
        .a(fa_a), .b(fa_b), .cin(fa_cin),
        .sum(fa_sum), .cout(fa_cout)
    );

    // ----------------------------------------------------------
    // 4. INCREMENTER
    // ----------------------------------------------------------
    reg [3:0] inc_in;
    wire [3:0] inc_out;

    incrementer #(.WIDTH(4)) INC4 (
        .value_in(inc_in), .value_out(inc_out)
    );

    // ----------------------------------------------------------
    // 5. BAUD COUNTER
    // Its internal count is not an output in the supplied design,
    // so this test checks the externally visible baud_tick timing.
    // ----------------------------------------------------------
    reg baud_enable;
    wire baud_tick_unit;

    baud_counter #(.CLKS_PER_BIT(4)) BAUD_UNIT (
        .clk(clk), .rst_n(rst_n),
        .enable(baud_enable), .baud_tick(baud_tick_unit)
    );

    // ----------------------------------------------------------
    // 6. DATA REGISTER
    // ----------------------------------------------------------
    reg data_load, data_shift;
    reg [7:0] data_input;
    wire serial_bit_unit;
    wire [7:0] data_output_unit;

    uart_data_register DATA_REG_UNIT (
        .clk(clk), .rst_n(rst_n),
        .load(data_load), .shift(data_shift),
        .data_in(data_input),
        .serial_bit(serial_bit_unit),
        .data_out(data_output_unit)
    );

    // ----------------------------------------------------------
    // 7. BIT COUNTER
    // ----------------------------------------------------------
    reg bit_clear, bit_increment;
    wire bit_last_unit;
    wire [2:0] bit_count_unit;

    uart_bit_counter BIT_COUNTER_UNIT (
        .clk(clk), .rst_n(rst_n),
        .clear(bit_clear), .increment(bit_increment),
        .bit_last(bit_last_unit), .bit_count(bit_count_unit)
    );

    // ----------------------------------------------------------
    // 8. FSM
    // State encoding in supplied design: IDLE=0, START=1,
    // DATA=2, STOP=3.
    // ----------------------------------------------------------
    reg fsm_start, fsm_tick, fsm_bit_last;
    wire [1:0] fsm_state;
    wire fsm_load_data, fsm_shift_data;
    wire fsm_clear_count, fsm_increment_count;
    wire fsm_done;

    uart_fsm FSM_UNIT (
        .clk(clk), .rst_n(rst_n),
        .tx_start(fsm_start),
        .baud_tick(fsm_tick),
        .bit_last(fsm_bit_last),
        .state(fsm_state),
        .load_data(fsm_load_data),
        .shift_data(fsm_shift_data),
        .clear_bit_count(fsm_clear_count),
        .increment_bit_count(fsm_increment_count),
        .tx_done(fsm_done)
    );

    // ----------------------------------------------------------
    // 9. TX OUTPUT LOGIC
    // ----------------------------------------------------------
    reg [1:0] tx_logic_state;
    reg tx_logic_data;
    wire tx_logic_serial;

    uart_tx_logic TX_LOGIC_UNIT (
        .state(tx_logic_state),
        .data_bit(tx_logic_data),
        .tx_serial(tx_logic_serial)
    );

    // ----------------------------------------------------------
    // 10. STRUCTURAL UART - actual module name from design file
    // ----------------------------------------------------------
    reg structural_start;
    reg [7:0] structural_data;
    wire structural_tx, structural_busy, structural_done;

    uart_tx_structural #(.CLKS_PER_BIT(4)) STRUCTURAL (
        .clk(clk), .rst_n(rst_n),
        .tx_start(structural_start), .tx_data(structural_data),
        .tx_serial(structural_tx), .tx_busy(structural_busy),
        .tx_done(structural_done)
    );

    // ----------------------------------------------------------
    // 11. BEHAVIORAL RTL UART - actual module name from design file
    // ----------------------------------------------------------
    reg rtl_start;
    reg [7:0] rtl_data;
    wire rtl_tx, rtl_busy, rtl_done;

    uart_tx_rtl #(.CLKS_PER_BIT(4)) RTL (
        .clk(clk), .rst_n(rst_n),
        .tx_start(rtl_start), .tx_data(rtl_data),
        .tx_serial(rtl_tx), .tx_busy(rtl_busy),
        .tx_done(rtl_done)
    );

    // ----------------------------------------------------------
    // 12. TOP MODULE - actual module name from design file
    // ----------------------------------------------------------
    reg top_start;
    reg [7:0] top_data;
    wire top_tx, top_busy, top_done;

    uart_tx_top #(.CLKS_PER_BIT(4)) TOP (
        .clk(clk), .rst_n(rst_n),
        .tx_start(top_start), .tx_data(top_data),
        .tx_serial(top_tx), .tx_busy(top_busy),
        .tx_done(top_done)
    );

    // ----------------------------------------------------------
    // ----------------------------------------------------------
    // CHECK HELPERS - consistent console columns for every check
    // ----------------------------------------------------------
    task check_bit;
        input [8*48-1:0] label;
        input expected;
        input actual;
        begin
            if (actual !== expected) begin
                $display("FAIL | %-32s | Expected=%b | Actual=%b | Time=%0t",
                         label, expected, actual, $time);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS | %-32s | Expected=%b | Actual=%b | Time=%0t",
                         label, expected, actual, $time);
                pass_count = pass_count + 1;
            end
        end
    endtask

    task check_2bit;
        input [8*48-1:0] label;
        input [1:0] expected;
        input [1:0] actual;
        begin
            if (actual !== expected) begin
                $display("FAIL | %-32s | Expected=%b | Actual=%b | Time=%0t",
                         label, expected, actual, $time);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS | %-32s | Expected=%b | Actual=%b | Time=%0t",
                         label, expected, actual, $time);
                pass_count = pass_count + 1;
            end
        end
    endtask

    task check_3bit;
        input [8*48-1:0] label;
        input [2:0] expected;
        input [2:0] actual;
        begin
            if (actual !== expected) begin
                $display("FAIL | %-32s | Expected=%b | Actual=%b | Time=%0t",
                         label, expected, actual, $time);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS | %-32s | Expected=%b | Actual=%b | Time=%0t",
                         label, expected, actual, $time);
                pass_count = pass_count + 1;
            end
        end
    endtask

    task check_4bit;
        input [8*48-1:0] label;
        input [3:0] expected;
        input [3:0] actual;
        begin
            if (actual !== expected) begin
                $display("FAIL | %-32s | Expected=0x%h | Actual=0x%h | Time=%0t",
                         label, expected, actual, $time);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS | %-32s | Expected=0x%h | Actual=0x%h | Time=%0t",
                         label, expected, actual, $time);
                pass_count = pass_count + 1;
            end
        end
    endtask

    task check_8bit;
        input [8*48-1:0] label;
        input [7:0] expected;
        input [7:0] actual;
        begin
            if (actual !== expected) begin
                $display("FAIL | %-32s | Expected=0x%h | Actual=0x%h | Time=%0t",
                         label, expected, actual, $time);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS | %-32s | Expected=0x%h | Actual=0x%h | Time=%0t",
                         label, expected, actual, $time);
                pass_count = pass_count + 1;
            end
        end
    endtask

    // Select a UART's start/data inputs by ID:
    // 0 = structural, 1 = RTL, 2 = top.
    task drive_uart;
        input integer which_uart;
        input start_value;
        input [7:0] payload;
        begin
            case (which_uart)
                0: begin structural_start = start_value; structural_data = payload; end
                1: begin rtl_start = start_value; rtl_data = payload; end
                2: begin top_start = start_value; top_data = payload; end
            endcase
        end
    endtask

    task read_uart_tx;
        input integer which_uart;
        output reg value;
        begin
            case (which_uart)
                0: value = structural_tx;
                1: value = rtl_tx;
                2: value = top_tx;
                default: value = 1'bx;
            endcase
        end
    endtask

    task read_uart_busy;
        input integer which_uart;
        output reg value;
        begin
            case (which_uart)
                0: value = structural_busy;
                1: value = rtl_busy;
                2: value = top_busy;
                default: value = 1'bx;
            endcase
        end
    endtask

    task read_uart_done;
        input integer which_uart;
        output reg value;
        begin
            case (which_uart)
                0: value = structural_done;
                1: value = rtl_done;
                2: value = top_done;
                default: value = 1'bx;
            endcase
        end
    endtask

    // Verify one complete UART frame. Samples are taken near the
    // centre of each bit. The UART is 8-N-1 and sends LSB first.
    task test_uart_frame;
        input integer which_uart;
        input [7:0] payload;
        reg sampled_tx;
        reg sampled_busy;
        reg sampled_done;
        integer bit_number;
        integer timeout_count;
        begin
            $display("");
            $display("FRAME START | UART_ID=%0d | PAYLOAD=0x%02h",
                     which_uart, payload);

            @(negedge clk);
            drive_uart(which_uart, 1'b1, payload);
            @(posedge clk);
            #1;
            read_uart_busy(which_uart, sampled_busy);
            check_bit("UART BUSY ASSERTS", 1'b1, sampled_busy);
            read_uart_tx(which_uart, sampled_tx);
            check_bit("UART START BIT BEGINS LOW", 1'b0, sampled_tx);

            @(negedge clk);
            drive_uart(which_uart, 1'b0, payload);

            // Start-bit centre: two rising edges after accepting start.
            repeat (2) begin @(posedge clk); #1; end
            read_uart_tx(which_uart, sampled_tx);
            check_bit("UART START BIT CENTRE", 1'b0, sampled_tx);

            // First data-bit centre is four clocks after start-bit centre.
            repeat (4) begin @(posedge clk); #1; end
            for (bit_number = 0; bit_number < 8; bit_number = bit_number + 1) begin
                read_uart_tx(which_uart, sampled_tx);
                if (sampled_tx !== payload[bit_number]) begin
                    $display("FAIL | UART %0d DATA BIT %-20d | Expected=%b | Actual=%b | Time=%0t",
                             which_uart, bit_number, payload[bit_number],
                             sampled_tx, $time);
                    fail_count = fail_count + 1;
                end else begin
                    $display("PASS | UART %0d DATA BIT %-20d | Expected=%b | Actual=%b | Time=%0t",
                             which_uart, bit_number, payload[bit_number],
                             sampled_tx, $time);
                    pass_count = pass_count + 1;
                end
                if (bit_number != 7)
                    repeat (4) begin @(posedge clk); #1; end
            end

            // Stop-bit centre follows the centre of data bit 7 by 4 clocks.
            repeat (4) begin @(posedge clk); #1; end
            read_uart_tx(which_uart, sampled_tx);
            check_bit("UART STOP BIT HIGH", 1'b1, sampled_tx);

            // Wait for completion, with a bounded timeout.
            timeout_count = 0;
            sampled_done = 1'b0;
            while ((sampled_done !== 1'b1) && (timeout_count < 12)) begin
                @(posedge clk);
                #1;
                read_uart_done(which_uart, sampled_done);
                timeout_count = timeout_count + 1;
            end
            check_bit("UART DONE PULSE", 1'b1, sampled_done);
            read_uart_busy(which_uart, sampled_busy);
            check_bit("UART BUSY CLEARS", 1'b0, sampled_busy);
            read_uart_tx(which_uart, sampled_tx);
            check_bit("UART IDLE LINE HIGH", 1'b1, sampled_tx);
        end
    endtask

    // ----------------------------------------------------------
    // MAIN TEST SEQUENCE
    // ----------------------------------------------------------
    initial begin
        $display("");
        $display("======================================================================");
        $display("  DAY 18 UART TRANSMITTER | HIERARCHICAL SELF-CHECKING TESTBENCH");
        $display("  UART: 8-N-1 | LSB FIRST | CLKS_PER_BIT=4 | RESET=ACTIVE LOW");
        $display("  Every check reports expected and actual values immediately.");
        $display("======================================================================");
        $display("RESULT | CHECK                            | EXPECTED   | ACTUAL     | TIME");
        $display("-------+----------------------------------+------------+------------+----------");
        $display("");

        ga = 0; gb = 0;
        ha_a = 0; ha_b = 0;
        fa_a = 0; fa_b = 0; fa_cin = 0;
        inc_in = 0;
        baud_enable = 0;
        data_load = 0; data_shift = 0; data_input = 0;
        bit_clear = 1; bit_increment = 0;
        fsm_start = 0; fsm_tick = 0; fsm_bit_last = 0;
        tx_logic_state = 0; tx_logic_data = 0;
        structural_start = 0; structural_data = 0;
        rtl_start = 0; rtl_data = 0;
        top_start = 0; top_data = 0;

        // Keep active-low reset asserted initially.
        repeat (3) @(posedge clk);
        #1;
        check_2bit("FSM RESET STATE IDLE", 2'd0, fsm_state);
        check_3bit("BIT COUNTER RESET", 3'd0, bit_count_unit);
        check_8bit("DATA REGISTER RESET", 8'h00, data_output_unit);

        @(negedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);
        #1;

        // ------------------------------------------------------
        // TEST 1: BASIC GATES - all four input combinations
        // ------------------------------------------------------
        $display("");
        $display("---- TEST 01/12 : BASIC LOGIC GATES --------------------------------");
        for (i = 0; i < 2; i = i + 1) begin
            for (j = 0; j < 2; j = j + 1) begin
                ga = i[0]; gb = j[0]; #1;
                check_bit("GATE AND", (i & j), g_and);
                check_bit("GATE OR",  (i | j), g_or);
                check_bit("GATE XOR", (i ^ j), g_xor);
                check_bit("GATE NOT A", (~i), g_not);
            end
        end

        // ------------------------------------------------------
        // TEST 2: HALF ADDER - all input combinations
        // ------------------------------------------------------
        $display("");
        $display("---- TEST 02/12 : HALF ADDER ---------------------------------------");
        for (i = 0; i < 2; i = i + 1) begin
            for (j = 0; j < 2; j = j + 1) begin
                ha_a = i[0]; ha_b = j[0]; #1;
                check_bit("HALF ADDER SUM", (i ^ j), ha_sum);
                check_bit("HALF ADDER CARRY", (i & j), ha_carry);
            end
        end

        // ------------------------------------------------------
        // TEST 3: FULL ADDER - all eight input combinations
        // ------------------------------------------------------
        $display("");
        $display("---- TEST 03/12 : FULL ADDER ---------------------------------------");
        for (i = 0; i < 2; i = i + 1) begin
            for (j = 0; j < 2; j = j + 1) begin
                for (k = 0; k < 2; k = k + 1) begin
                    fa_a = i[0]; fa_b = j[0]; fa_cin = k[0]; #1;
                    check_bit("FULL ADDER SUM", (i ^ j ^ k), fa_sum);
                    check_bit("FULL ADDER CARRY", ((i & j) | (i & k) | (j & k)), fa_cout);
                end
            end
        end

        // ------------------------------------------------------
        // TEST 4: INCREMENTER - all 4-bit values including wrap
        // ------------------------------------------------------
        $display("");
        $display("---- TEST 04/12 : 4-BIT INCREMENTER --------------------------------");
        for (i = 0; i < 16; i = i + 1) begin
            inc_in = i[3:0]; #1;
            check_4bit("INCREMENTER", (i + 1), inc_out);
        end

        // ------------------------------------------------------
        // TEST 5: BAUD COUNTER - tick on terminal count
        // Expected post-edge tick sequence: 0, 0, 1, 0.
        // ------------------------------------------------------
        $display("");
        $display("---- TEST 05/12 : BAUD COUNTER -------------------------------------");
        @(negedge clk);
        baud_enable = 1'b1;
        for (i = 0; i < 4; i = i + 1) begin
            @(posedge clk); #1;
            case (i)
                0: check_bit("BAUD TICK COUNT 1", 1'b0, baud_tick_unit);
                1: check_bit("BAUD TICK COUNT 2", 1'b0, baud_tick_unit);
                2: check_bit("BAUD TERMINAL TICK", 1'b1, baud_tick_unit);
                3: check_bit("BAUD TICK CLEARED", 1'b0, baud_tick_unit);
            endcase
        end
        @(negedge clk);
        baud_enable = 1'b0;

        // ------------------------------------------------------
        // TEST 6: DATA REGISTER - load, serial LSB, shift
        // ------------------------------------------------------
        $display("");
        $display("---- TEST 06/12 : UART DATA REGISTER -------------------------------");
        @(negedge clk);
        data_input = 8'hA5; data_load = 1'b1; data_shift = 1'b0;
        @(posedge clk); #1;
        check_8bit("DATA REGISTER PARALLEL LOAD", 8'hA5, data_output_unit);
        check_bit("DATA REGISTER LSB OUTPUT", 1'b1, serial_bit_unit);
        @(negedge clk);
        data_load = 1'b0; data_shift = 1'b1;
        @(posedge clk); #1;
        check_8bit("DATA REGISTER SHIFT RIGHT", 8'h52, data_output_unit);
        @(negedge clk);
        data_shift = 1'b0;

        // ------------------------------------------------------
        // TEST 7: BIT COUNTER - count 0..7, terminal, wrap
        // ------------------------------------------------------
        $display("");
        $display("---- TEST 07/12 : UART BIT COUNTER ---------------------------------");
        @(negedge clk);
        bit_clear = 1'b1; bit_increment = 1'b0;
        @(posedge clk); #1;
        check_3bit("BIT COUNTER CLEAR", 3'd0, bit_count_unit);
        @(negedge clk);
        bit_clear = 1'b0; bit_increment = 1'b1;
        for (i = 1; i <= 7; i = i + 1) begin
            @(posedge clk); #1;
            check_3bit("BIT COUNTER INCREMENT", i[2:0], bit_count_unit);
        end
        check_bit("BIT COUNTER TERMINAL FLAG", 1'b1, bit_last_unit);
        @(posedge clk); #1;
        check_3bit("BIT COUNTER 3-BIT WRAP", 3'd0, bit_count_unit);
        @(negedge clk);
        bit_increment = 1'b0; bit_clear = 1'b1;

        // ------------------------------------------------------
        // TEST 8: FSM - IDLE -> START -> DATA -> STOP -> IDLE
        // ------------------------------------------------------
        $display("");
        $display("---- TEST 08/12 : UART FINITE STATE MACHINE ------------------------");
        check_2bit("FSM IDLE", 2'd0, fsm_state);
        @(negedge clk);
        fsm_start = 1'b1;
        #1;
        check_bit("FSM LOAD DATA CONTROL", 1'b1, fsm_load_data);
        @(posedge clk); #1;
        check_2bit("FSM ENTERS START", 2'd1, fsm_state);
        @(negedge clk);
        fsm_start = 1'b0; fsm_tick = 1'b1;
        @(posedge clk); #1;
        check_2bit("FSM START TO DATA", 2'd2, fsm_state);
        @(negedge clk);
        fsm_tick = 1'b1; fsm_bit_last = 1'b1;
        @(posedge clk); #1;
        check_2bit("FSM DATA TO STOP", 2'd3, fsm_state);
        @(negedge clk);
        fsm_tick = 1'b1; fsm_bit_last = 1'b0;
        @(posedge clk); #1;
        check_2bit("FSM STOP TO IDLE", 2'd0, fsm_state);
        check_bit("FSM DONE PULSE", 1'b1, fsm_done);
        @(negedge clk);
        fsm_tick = 1'b0;
        @(posedge clk); #1;
        check_bit("FSM DONE CLEARS", 1'b0, fsm_done);

        // ------------------------------------------------------
        // TEST 9: TX OUTPUT LOGIC - each state encoding
        // ------------------------------------------------------
        $display("");
        $display("---- TEST 09/12 : UART TX OUTPUT LOGIC -----------------------------");
        tx_logic_state = 2'd0; tx_logic_data = 1'b0; #1;
        check_bit("TX IDLE HIGH", 1'b1, tx_logic_serial);
        tx_logic_state = 2'd1; #1;
        check_bit("TX START LOW", 1'b0, tx_logic_serial);
        tx_logic_state = 2'd2; tx_logic_data = 1'b0; #1;
        check_bit("TX DATA ZERO", 1'b0, tx_logic_serial);
        tx_logic_data = 1'b1; #1;
        check_bit("TX DATA ONE", 1'b1, tx_logic_serial);
        tx_logic_state = 2'd3; #1;
        check_bit("TX STOP HIGH", 1'b1, tx_logic_serial);

        // ------------------------------------------------------
        // TESTS 10-12: full frame through each UART implementation
        // ------------------------------------------------------
        $display("");
        $display("---- TEST 10/12 : STRUCTURAL UART FRAME ----------------------------");
        test_uart_frame(0, 8'hA5);

        $display("");
        $display("---- TEST 11/12 : BEHAVIORAL RTL UART FRAME ------------------------");
        test_uart_frame(1, 8'h3C);

        $display("");
        $display("---- TEST 12/12 : TOP-LEVEL UART FRAME -----------------------------");
        test_uart_frame(2, 8'h96);

        // Final result
        $display("");
        $display("======================================================================");
        $display("                      DAY 18 VERIFICATION SUMMARY");
        $display("======================================================================");
        $display("  RESULT | CHECK COUNT");
        $display("  PASS   | %0d", pass_count);
        $display("  FAIL   | %0d", fail_count);
        $display("  TOTAL  | %0d", pass_count + fail_count);
        if (fail_count == 0) begin
            $display("  FINAL STATUS : PASS - ALL CHECKS PASSED");
        end else begin
            $display("  FINAL STATUS : FAIL - REVIEW FAILED CHECKS ABOVE");
        end
        $display("======================================================================");
        $display("");

        #20;
     
    end

    // Global simulation timeout prevents an endless run.
    initial begin
        #200000;
        $display("FATAL: Global testbench timeout.");
        $finish;
    end

endmodule
