package audio_fx_core_uvm_pkg;

    import uvm_pkg::*;
    import audio_fx_types_pkg::*;
    `include "uvm_macros.svh"

    localparam int UVM_DELAY_DEPTH = 256;

    class audio_fx_core_item extends uvm_sequence_item;
        rand logic signed [15:0] audio_in;
        rand logic        [1:0] mode;
        rand logic       [15:0] delay_samples;
        rand logic        [7:0] feedback_q8;
        rand logic        [8:0] volume_q8;
        rand int unsigned       gap_cycles;
        rand bit                inject_busy_attempt;
        rand logic signed [15:0] busy_audio_in;
        rand int unsigned       output_stall_cycles;
        rand bit                reset_during_processing;
        rand int unsigned       reset_hold_cycles;

        logic signed [15:0] audio_out;
        longint unsigned accept_cycle;
        longint unsigned output_cycle;
        int unsigned latency_cycles;
        bit busy_attempt_seen;
        bit backpressure_seen;

        `uvm_object_utils_begin(audio_fx_core_item)
            `uvm_field_int(audio_in, UVM_DEFAULT)
            `uvm_field_int(mode, UVM_DEFAULT)
            `uvm_field_int(delay_samples, UVM_DEFAULT)
            `uvm_field_int(feedback_q8, UVM_DEFAULT)
            `uvm_field_int(volume_q8, UVM_DEFAULT)
            `uvm_field_int(gap_cycles, UVM_DEFAULT)
            `uvm_field_int(inject_busy_attempt, UVM_DEFAULT)
            `uvm_field_int(busy_audio_in, UVM_DEFAULT)
            `uvm_field_int(output_stall_cycles, UVM_DEFAULT)
            `uvm_field_int(reset_during_processing, UVM_DEFAULT)
            `uvm_field_int(reset_hold_cycles, UVM_DEFAULT)
            `uvm_field_int(audio_out, UVM_DEFAULT)
            `uvm_field_int(accept_cycle, UVM_DEFAULT)
            `uvm_field_int(output_cycle, UVM_DEFAULT)
            `uvm_field_int(latency_cycles, UVM_DEFAULT)
            `uvm_field_int(busy_attempt_seen, UVM_DEFAULT)
            `uvm_field_int(backpressure_seen, UVM_DEFAULT)
        `uvm_object_utils_end

        function new(string name = "audio_fx_core_item");
            super.new(name);
        endfunction

        function string convert2string();
            return $sformatf(
                {"mode=%0d in=%0d delay=%0d feedback=0x%02h volume=%0d ",
                 "out=%0d latency=%0d busy_attempt=%0b backpressure=%0b"},
                mode, $signed(audio_in), delay_samples, feedback_q8,
                volume_q8, $signed(audio_out), latency_cycles,
                busy_attempt_seen, backpressure_seen);
        endfunction
    endclass

    class audio_fx_core_sequencer extends uvm_sequencer #(audio_fx_core_item);
        `uvm_component_utils(audio_fx_core_sequencer)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction
    endclass

    class audio_fx_core_sequence extends uvm_sequence #(audio_fx_core_item);
        `uvm_object_utils(audio_fx_core_sequence)

        string scenario = "basic";

        function new(string name = "audio_fx_core_sequence");
            super.new(name);
        endfunction

        task send_sample(
            input int signed sample_value,
            input logic [1:0] selected_mode,
            input int unsigned requested_delay = 0,
            input int unsigned requested_feedback = 0,
            input int unsigned requested_volume = 256,
            input int unsigned requested_gap = 0,
            input bit inject_busy = 1'b0,
            input int signed busy_sample = -1234,
            input int unsigned stall_cycles = 0,
            input bit inject_reset = 1'b0,
            input int unsigned reset_cycles = 2
        );
            audio_fx_core_item item;
            item = audio_fx_core_item::type_id::create("item");
            start_item(item);
            item.audio_in      = sample_value;
            item.mode          = selected_mode;
            item.delay_samples = requested_delay;
            item.feedback_q8   = requested_feedback;
            item.volume_q8     = requested_volume;
            item.gap_cycles    = requested_gap;
            item.inject_busy_attempt = inject_busy;
            item.busy_audio_in = busy_sample;
            item.output_stall_cycles = stall_cycles;
            item.reset_during_processing = inject_reset;
            item.reset_hold_cycles = reset_cycles;
            finish_item(item);
        endtask

        task run_basic();
            send_sample( 1000, FX_MODE_BYPASS);
            send_sample( 3000, FX_MODE_HARD_CLIP);
            send_sample(-3000, FX_MODE_HARD_CLIP);
            send_sample(20000, FX_MODE_BYPASS, 0, 0, 128);
            send_sample(32000, FX_MODE_LOW_PASS);
            send_sample(32000, FX_MODE_LOW_PASS);
            send_sample( 1500, FX_MODE_BITCRUSHER);
            send_sample( 7000, FX_MODE_BITCRUSHER);
            send_sample( 7000, FX_MODE_BITCRUSHER);
        endtask

        task run_delay();
            send_sample(1000, FX_MODE_BYPASS, 2, 8'h80, 256);
            send_sample(   0, FX_MODE_BYPASS, 2, 8'h80, 256);
            send_sample(   0, FX_MODE_BYPASS, 2, 8'h80, 256);
        endtask

        task run_protocol();
            // Produz uma saida sob backpressure e tenta apresentar uma
            // segunda entrada enquanto o core permanece ocupado.
            send_sample(2000, FX_MODE_BYPASS, 0, 0, 256, 0,
                        1'b1, -2222, 3, 1'b0, 2);

            // Esta transacao e aceita, mas deve ser cancelada pelo reset e
            // portanto nao produz uma saida observavel pelo scoreboard.
            send_sample(1234, FX_MODE_BYPASS, 2, 8'h80, 256, 0,
                        1'b0, 0, 0, 1'b1, 2);

            // Confirma que o core voltou ao estado ocioso e processa uma
            // nova transacao normalmente depois do reset.
            send_sample(-1000, FX_MODE_BYPASS, 0, 0, 128);
        endtask

        task run_delay_edges();
            // Feedback zero: a leitura atrasada ocorre, mas nao altera a saida.
            send_sample(1000, FX_MODE_BYPASS, 2, 8'h00, 256);
            send_sample(   0, FX_MODE_BYPASS, 2, 8'h00, 256);
            send_sample(   0, FX_MODE_BYPASS, 2, 8'h00, 256);

            // Realimentacao quase unitaria: atinge primeiro a saturacao
            // positiva e depois a negativa, sem reset intermediario.
            send_sample( 30000, FX_MODE_BYPASS, 1, 8'hff, 256);
            send_sample( 30000, FX_MODE_BYPASS, 1, 8'hff, 256);
            send_sample(-30000, FX_MODE_BYPASS, 1, 8'hff, 256);
            send_sample(-30000, FX_MODE_BYPASS, 1, 8'hff, 256);
            send_sample(-30000, FX_MODE_BYPASS, 1, 8'hff, 256);
        endtask

        task run_long();
            int i;
            int signed sample_value;
            logic [1:0] selected_mode;
            int unsigned requested_delay;
            int unsigned requested_feedback;
            int unsigned requested_volume;

            for (i = 0; i < 1000; i++) begin
                if (i == 0) begin
                    sample_value = 0;
                end else begin
                    sample_value = ((i * 7919) % 65536) - 32768;
                end

                selected_mode = i % 4;
                requested_delay = ((i % 16) == 0) ? 0 : ((i % 31) + 1);
                requested_feedback = ((i % 10) == 0) ? 0 : ((i * 37) % 256);

                case (i % 4)
                    0: requested_volume = 0;
                    1: requested_volume = 128;
                    2: requested_volume = 256;
                    default: requested_volume = 300;
                endcase

                send_sample(sample_value, selected_mode, requested_delay,
                            requested_feedback, requested_volume);
            end
        endtask

        virtual task body();
            `uvm_info("SEQ", $sformatf("Cenario selecionado: %s", scenario), UVM_NONE)
            case (scenario)
                "basic": run_basic();
                "delay": run_delay();
                "protocol": run_protocol();
                "delay_edges": run_delay_edges();
                "long": run_long();
                default: `uvm_fatal("SEQ", $sformatf(
                    "Cenario desconhecido: %s", scenario))
            endcase
        endtask
    endclass

    class audio_fx_core_driver extends uvm_driver #(audio_fx_core_item);
        `uvm_component_utils(audio_fx_core_driver)

        virtual audio_fx_core_if vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual audio_fx_core_if)::get(
                    this, "", "vif", vif)) begin
                `uvm_fatal("NOVIF", "Interface virtual nao configurada no driver")
            end
        endfunction

        task drive_item(audio_fx_core_item item);
            int unsigned hold_cycles;

            repeat (item.gap_cycles) @(vif.drv_cb);

            if (item.output_stall_cycles != 0) begin
                vif.drv_cb.m_ready <= 1'b0;
            end else begin
                vif.drv_cb.m_ready <= 1'b1;
            end

            do begin
                @(vif.drv_cb);
            end while (!vif.drv_cb.s_ready);

            vif.drv_cb.s_audio       <= item.audio_in;
            vif.drv_cb.mode          <= item.mode;
            vif.drv_cb.delay_samples <= item.delay_samples;
            vif.drv_cb.feedback_q8   <= item.feedback_q8;
            vif.drv_cb.volume_q8     <= item.volume_q8;
            vif.drv_cb.s_valid       <= 1'b1;

            @(posedge vif.clk);
            @(vif.drv_cb);
            vif.drv_cb.s_valid <= 1'b0;

            if (item.inject_busy_attempt) begin
                vif.drv_cb.s_audio <= item.busy_audio_in;
                vif.drv_cb.s_valid <= 1'b1;
                @(posedge vif.clk);
                @(vif.drv_cb);
                vif.drv_cb.s_valid <= 1'b0;
            end

            if (item.reset_during_processing) begin
                hold_cycles = item.reset_hold_cycles;
                if (hold_cycles == 0) hold_cycles = 1;

                vif.drv_cb.rst_n <= 1'b0;
                repeat (hold_cycles) @(vif.drv_cb);
                vif.drv_cb.rst_n <= 1'b1;
                vif.drv_cb.m_ready <= 1'b1;
            end else if (item.output_stall_cycles != 0) begin
                do begin
                    @(vif.drv_cb);
                end while (!vif.drv_cb.m_valid);

                repeat (item.output_stall_cycles) @(vif.drv_cb);
                vif.drv_cb.m_ready <= 1'b1;
            end
        endtask

        task run_phase(uvm_phase phase);
            vif.rst_n        = 1'b0;
            vif.s_valid       = 1'b0;
            vif.s_audio       = '0;
            vif.mode          = FX_MODE_BYPASS;
            vif.delay_samples = '0;
            vif.feedback_q8   = '0;
            vif.volume_q8     = VOLUME_UNITY_Q8;
            vif.m_ready       = 1'b1;

            repeat (4) @(vif.drv_cb);
            vif.drv_cb.rst_n <= 1'b1;

            forever begin
                seq_item_port.get_next_item(req);
                drive_item(req);
                seq_item_port.item_done();
            end
        endtask
    endclass

    class audio_fx_core_monitor extends uvm_monitor;
        `uvm_component_utils(audio_fx_core_monitor)

        virtual audio_fx_core_if vif;
        uvm_analysis_port #(audio_fx_core_item) analysis_port;
        audio_fx_core_item pending_item;
        longint unsigned cycle_count;
        int unsigned busy_attempt_count;
        int unsigned backpressure_cycle_count;
        int unsigned reset_abort_count;
        int unsigned accepted_count;
        int unsigned completed_count;
        int unsigned memory_write_count;
        int unsigned memory_wrap_count;
        int unsigned min_latency_cycles;
        int unsigned max_latency_cycles;
        int unsigned min_accept_interval;
        int unsigned max_accept_interval;
        longint unsigned first_accept_cycle;
        longint unsigned last_accept_cycle;
        longint unsigned last_output_cycle;
        bit expect_wrap_zero;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            analysis_port = new("analysis_port", this);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual audio_fx_core_if)::get(
                    this, "", "vif", vif)) begin
                `uvm_fatal("NOVIF", "Interface virtual nao configurada no monitor")
            end
        endfunction

        task run_phase(uvm_phase phase);
            audio_fx_core_item observed;
            cycle_count = 0;
            pending_item = null;
            busy_attempt_count = 0;
            backpressure_cycle_count = 0;
            reset_abort_count = 0;
            accepted_count = 0;
            completed_count = 0;
            memory_write_count = 0;
            memory_wrap_count = 0;
            min_latency_cycles = 32'hffff_ffff;
            max_latency_cycles = 0;
            min_accept_interval = 32'hffff_ffff;
            max_accept_interval = 0;
            first_accept_cycle = 0;
            last_accept_cycle = 0;
            last_output_cycle = 0;
            expect_wrap_zero = 1'b0;

            forever begin
                @(vif.mon_cb);
                cycle_count++;

                if (!vif.mon_cb.rst_n) begin
                    if (pending_item != null) begin
                        reset_abort_count++;
                    end
                    pending_item = null;
                    expect_wrap_zero = 1'b0;
                end else begin
                    if (vif.mon_cb.mem_req && vif.mon_cb.mem_we) begin
                        memory_write_count++;
                        if (expect_wrap_zero) begin
                            if (vif.mon_cb.mem_addr == 0) begin
                                memory_wrap_count++;
                            end else begin
                                `uvm_error("MON", $sformatf(
                                    "Wrap incorreto: esperado endereco 0, obtido=%0d",
                                    vif.mon_cb.mem_addr))
                            end
                        end
                        expect_wrap_zero = (vif.mon_cb.mem_addr == 8'hff);
                    end

                    if (vif.mon_cb.s_valid && vif.mon_cb.s_ready) begin
                        if (pending_item != null) begin
                            `uvm_error("MON", "Nova entrada aceita com transacao pendente")
                        end
                        pending_item = audio_fx_core_item::type_id::create(
                            "pending_item");
                        pending_item.audio_in = vif.mon_cb.s_audio;
                        pending_item.mode = vif.mon_cb.mode;
                        pending_item.delay_samples = vif.mon_cb.delay_samples;
                        pending_item.feedback_q8 = vif.mon_cb.feedback_q8;
                        pending_item.volume_q8 = vif.mon_cb.volume_q8;
                        pending_item.accept_cycle = cycle_count;
                        pending_item.busy_attempt_seen = 1'b0;
                        pending_item.backpressure_seen = 1'b0;
                        accepted_count++;
                        if (accepted_count == 1) begin
                            first_accept_cycle = cycle_count;
                        end else begin
                            if ((cycle_count - last_accept_cycle) <
                                min_accept_interval) begin
                                min_accept_interval = cycle_count -
                                                      last_accept_cycle;
                            end
                            if ((cycle_count - last_accept_cycle) >
                                max_accept_interval) begin
                                max_accept_interval = cycle_count -
                                                      last_accept_cycle;
                            end
                        end
                        last_accept_cycle = cycle_count;
                    end

                    if ((pending_item != null) &&
                        vif.mon_cb.s_valid && !vif.mon_cb.s_ready) begin
                        pending_item.busy_attempt_seen = 1'b1;
                        busy_attempt_count++;
                    end

                    if ((pending_item != null) &&
                        vif.mon_cb.m_valid && !vif.mon_cb.m_ready) begin
                        pending_item.backpressure_seen = 1'b1;
                        backpressure_cycle_count++;
                    end

                    if (vif.mon_cb.m_valid && vif.mon_cb.m_ready) begin
                        if (pending_item == null) begin
                            `uvm_error("MON", "Saida observada sem entrada correspondente")
                        end else begin
                            observed = audio_fx_core_item::type_id::create(
                                "observed");
                            observed.copy(pending_item);
                            observed.audio_out = vif.mon_cb.m_audio;
                            observed.output_cycle = cycle_count;
                            observed.latency_cycles =
                                cycle_count - pending_item.accept_cycle;
                            completed_count++;
                            last_output_cycle = cycle_count;
                            if (observed.latency_cycles < min_latency_cycles) begin
                                min_latency_cycles = observed.latency_cycles;
                            end
                            if (observed.latency_cycles > max_latency_cycles) begin
                                max_latency_cycles = observed.latency_cycles;
                            end
                            analysis_port.write(observed);
                            pending_item = null;
                        end
                    end
                end
            end
        endtask

        function void report_phase(uvm_phase phase);
            longint unsigned elapsed_cycles;
            real samples_per_cycle;

            super.report_phase(phase);
            if (completed_count != 0) begin
                elapsed_cycles = last_output_cycle - first_accept_cycle + 1;
                samples_per_cycle = $itor(completed_count) /
                                    $itor(elapsed_cycles);
                `uvm_info("METRICS", $sformatf(
                    {"aceitas=%0d concluidas=%0d latencia_min=%0d ",
                     "latencia_max=%0d intervalo_min=%0d intervalo_max=%0d ",
                     "ciclos_totais=%0d amostras_por_ciclo=%0.6f ",
                     "escritas_mem=%0d wraps=%0d"},
                    accepted_count, completed_count,
                    min_latency_cycles, max_latency_cycles,
                    min_accept_interval, max_accept_interval,
                    elapsed_cycles, samples_per_cycle,
                    memory_write_count, memory_wrap_count), UVM_NONE)
            end
        endfunction
    endclass

    class audio_fx_core_agent extends uvm_agent;
        `uvm_component_utils(audio_fx_core_agent)

        audio_fx_core_sequencer sequencer;
        audio_fx_core_driver driver;
        audio_fx_core_monitor monitor;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            sequencer = audio_fx_core_sequencer::type_id::create(
                "sequencer", this);
            driver = audio_fx_core_driver::type_id::create("driver", this);
            monitor = audio_fx_core_monitor::type_id::create("monitor", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            driver.seq_item_port.connect(sequencer.seq_item_export);
        endfunction
    endclass

    class audio_fx_core_scoreboard extends uvm_scoreboard;
        `uvm_component_utils(audio_fx_core_scoreboard)

        uvm_analysis_imp #(audio_fx_core_item, audio_fx_core_scoreboard)
            analysis_export;
        virtual audio_fx_core_if vif;

        int signed lpf_state_ref;
        int signed bitcrusher_hold_ref;
        int bitcrusher_count_ref;
        int signed delay_memory_ref [0:UVM_DELAY_DEPTH-1];
        int delay_write_pointer_ref;
        int delay_history_ref;

        int expected_count;
        int received_count;
        int pass_count;
        int fail_count;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            analysis_export = new("analysis_export", this);
        endfunction

        function int signed saturate16(input int signed value);
            if (value > 32767) return 32767;
            if (value < -32768) return -32768;
            return value;
        endfunction

        function int signed quantize6(input int signed value);
            int masked;
            masked = value & 16'hfc00;
            if (masked >= 32768) masked -= 65536;
            return masked;
        endfunction

        function void reset_reference_state();
            lpf_state_ref = 0;
            bitcrusher_hold_ref = 0;
            bitcrusher_count_ref = 0;
            delay_write_pointer_ref = 0;
            delay_history_ref = 0;
            foreach (delay_memory_ref[index]) delay_memory_ref[index] = 0;
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual audio_fx_core_if)::get(
                    this, "", "vif", vif)) begin
                `uvm_fatal("NOVIF", "Interface virtual nao configurada no scoreboard")
            end
            if (!uvm_config_db#(int)::get(
                    this, "", "expected_count", expected_count)) begin
                expected_count = 0;
            end
            reset_reference_state();
            received_count = 0;
            pass_count = 0;
            fail_count = 0;
        endfunction

        task run_phase(uvm_phase phase);
            forever begin
                @(negedge vif.rst_n);
                reset_reference_state();
                `uvm_info("SCOREBOARD", "Modelo de referencia reiniciado", UVM_HIGH)
            end
        endtask

        function void write(audio_fx_core_item item);
            int signed sample_value;
            int signed hard_clip_value;
            int signed bitcrusher_value;
            int signed selected_value;
            int signed delayed_value;
            int signed delay_value;
            int signed expected_value;
            int effective_delay;
            int effective_volume;
            int signed feedback_value;
            int read_address;

            sample_value = $signed(item.audio_in);
            feedback_value = item.feedback_q8;

            lpf_state_ref = saturate16(
                lpf_state_ref + ((sample_value - lpf_state_ref) >>> 5));

            if (bitcrusher_count_ref == 0) begin
                bitcrusher_hold_ref = quantize6(sample_value);
                bitcrusher_count_ref = 7;
            end else begin
                bitcrusher_count_ref--;
            end
            bitcrusher_value = bitcrusher_hold_ref;
            hard_clip_value = saturate16(sample_value * 16);

            case (item.mode)
                FX_MODE_LOW_PASS:   selected_value = lpf_state_ref;
                FX_MODE_HARD_CLIP:  selected_value = hard_clip_value;
                FX_MODE_BITCRUSHER: selected_value = bitcrusher_value;
                default:            selected_value = sample_value;
            endcase

            effective_delay = item.delay_samples;
            if (effective_delay >= UVM_DELAY_DEPTH) begin
                effective_delay = UVM_DELAY_DEPTH - 1;
            end

            if ((effective_delay == 0) ||
                (delay_history_ref < effective_delay)) begin
                delayed_value = 0;
            end else begin
                read_address = delay_write_pointer_ref - effective_delay;
                if (read_address < 0) read_address += UVM_DELAY_DEPTH;
                delayed_value = delay_memory_ref[read_address];
            end

            delay_value = saturate16(
                selected_value +
                ((delayed_value * feedback_value) >>> 8));
            delay_memory_ref[delay_write_pointer_ref] = delay_value;
            delay_write_pointer_ref =
                (delay_write_pointer_ref + 1) % UVM_DELAY_DEPTH;
            if (delay_history_ref < UVM_DELAY_DEPTH) delay_history_ref++;

            effective_volume = item.volume_q8;
            if (effective_volume > 256) effective_volume = 256;
            expected_value = saturate16(
                (delay_value * effective_volume) >>> 8);

            received_count++;
            if ($signed(item.audio_out) !== expected_value) begin
                fail_count++;
                `uvm_error("SCOREBOARD", $sformatf(
                    "FAIL %0d | %s esperado=%0d",
                    received_count, item.convert2string(), expected_value))
            end else begin
                pass_count++;
                if ((received_count <= 10) ||
                    ((received_count % 100) == 0) ||
                    (received_count == expected_count)) begin
                    `uvm_info("SCOREBOARD", $sformatf(
                        "PASS %0d | %s",
                        received_count, item.convert2string()), UVM_LOW)
                end
            end
        endfunction

        function void check_phase(uvm_phase phase);
            super.check_phase(phase);
            if (received_count != expected_count) begin
                `uvm_error("SCOREBOARD", $sformatf(
                    "Quantidade incorreta: esperadas=%0d recebidas=%0d",
                    expected_count, received_count))
            end
            if (fail_count != 0) begin
                `uvm_error("SCOREBOARD", $sformatf(
                    "Foram encontradas %0d divergencias", fail_count))
            end
        endfunction

        function void report_phase(uvm_phase phase);
            super.report_phase(phase);
            `uvm_info("SCOREBOARD", $sformatf(
                "FINAL | esperadas=%0d recebidas=%0d pass=%0d fail=%0d",
                expected_count, received_count, pass_count, fail_count), UVM_NONE)
            if ((received_count == expected_count) && (fail_count == 0)) begin
                `uvm_info("SCOREBOARD", "TEST PASSED", UVM_NONE)
            end
        endfunction
    endclass

    class audio_fx_core_coverage extends uvm_subscriber #(audio_fx_core_item);
        `uvm_component_utils(audio_fx_core_coverage)

        logic [1:0] sampled_mode;
        int signed sampled_audio;
        int sampled_delay;
        int sampled_feedback;
        int sampled_volume;
        int signed sampled_output;
        bit sampled_busy_attempt;
        bit sampled_backpressure;

        covergroup core_covergroup;
            option.per_instance = 1;

            cp_mode: coverpoint sampled_mode {
                bins bypass = {FX_MODE_BYPASS};
                bins low_pass = {FX_MODE_LOW_PASS};
                bins hard_clip = {FX_MODE_HARD_CLIP};
                bins bitcrusher = {FX_MODE_BITCRUSHER};
            }

            cp_sign: coverpoint sampled_audio {
                bins negative = {[-32768:-1]};
                bins zero = {0};
                bins positive = {[1:32767]};
            }

            cp_delay: coverpoint sampled_delay {
                bins zero = {0};
                bins nonzero = {[1:65535]};
            }

            cp_feedback: coverpoint sampled_feedback {
                bins zero = {0};
                bins nonzero = {[1:255]};
            }

            cp_volume: coverpoint sampled_volume {
                bins mute = {0};
                bins reduced = {[1:255]};
                bins unity = {256};
                bins clamped = {[257:511]};
            }

            cp_output: coverpoint sampled_output {
                bins negative_saturation = {-32768};
                bins linear = {[-32767:32766]};
                bins positive_saturation = {32767};
            }

            cp_busy_attempt: coverpoint sampled_busy_attempt {
                bins not_seen = {0};
                bins seen = {1};
            }

            cp_backpressure: coverpoint sampled_backpressure {
                bins not_seen = {0};
                bins seen = {1};
            }

            mode_x_sign: cross cp_mode, cp_sign;
        endgroup

        function new(string name, uvm_component parent);
            super.new(name, parent);
            core_covergroup = new();
        endfunction

        virtual function void write(audio_fx_core_item t);
            sampled_mode = t.mode;
            sampled_audio = $signed(t.audio_in);
            sampled_delay = t.delay_samples;
            sampled_feedback = t.feedback_q8;
            sampled_volume = t.volume_q8;
            sampled_output = $signed(t.audio_out);
            sampled_busy_attempt = t.busy_attempt_seen;
            sampled_backpressure = t.backpressure_seen;
            core_covergroup.sample();
        endfunction

        function void report_phase(uvm_phase phase);
            super.report_phase(phase);
            `uvm_info("COVERAGE", $sformatf(
                "Cobertura funcional: %.2f%%",
                core_covergroup.get_inst_coverage()), UVM_NONE)
        endfunction
    endclass

    class audio_fx_core_env extends uvm_env;
        `uvm_component_utils(audio_fx_core_env)

        audio_fx_core_agent agent;
        audio_fx_core_scoreboard scoreboard;
        audio_fx_core_coverage coverage;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            agent = audio_fx_core_agent::type_id::create("agent", this);
            scoreboard = audio_fx_core_scoreboard::type_id::create(
                "scoreboard", this);
            coverage = audio_fx_core_coverage::type_id::create(
                "coverage", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            agent.monitor.analysis_port.connect(scoreboard.analysis_export);
            agent.monitor.analysis_port.connect(coverage.analysis_export);
        endfunction
    endclass

    class audio_fx_core_test extends uvm_test;
        `uvm_component_utils(audio_fx_core_test)

        audio_fx_core_env env;
        virtual audio_fx_core_if vif;
        string scenario;
        int expected_count;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);

            scenario = "basic";
            void'($value$plusargs("SCENARIO=%s", scenario));

            case (scenario)
                "basic": expected_count = 9;
                "delay": expected_count = 3;
                "protocol": expected_count = 2;
                "delay_edges": expected_count = 8;
                "long": expected_count = 1000;
                default: begin
                    expected_count = 0;
                    `uvm_fatal("TEST", $sformatf(
                        "Cenario desconhecido: %s", scenario))
                end
            endcase

            if (!uvm_config_db#(virtual audio_fx_core_if)::get(
                    this, "", "vif", vif)) begin
                `uvm_fatal("NOVIF", "Interface virtual nao configurada no teste")
            end

            uvm_config_db#(int)::set(
                this, "env.scoreboard", "expected_count", expected_count);
            env = audio_fx_core_env::type_id::create("env", this);
        endfunction

        task run_phase(uvm_phase phase);
            audio_fx_core_sequence seq;
            int unsigned timeout_cycles;

            phase.raise_objection(this);
            wait (vif.rst_n === 1'b1);
            repeat (2) @(posedge vif.clk);

            `uvm_info("TEST", $sformatf(
                "Executando scenario=%s expected_count=%0d",
                scenario, expected_count), UVM_NONE)

            seq = audio_fx_core_sequence::type_id::create("seq");
            seq.scenario = scenario;
            seq.start(env.agent.sequencer);

            timeout_cycles = (scenario == "long") ? 20000 : 500;

            fork
                begin
                    wait (env.scoreboard.received_count == expected_count);
                    repeat (5) @(posedge vif.clk);
                end
                begin
                    repeat (timeout_cycles) @(posedge vif.clk);
                    `uvm_fatal("TIMEOUT", "Timeout esperando as saidas do core")
                end
            join_any
            disable fork;

            if (scenario == "protocol") begin
                if (env.agent.monitor.busy_attempt_count == 0) begin
                    `uvm_error("TEST", "Tentativa durante busy nao foi observada")
                end
                if (env.agent.monitor.backpressure_cycle_count == 0) begin
                    `uvm_error("TEST", "Backpressure de saida nao foi observado")
                end
                if (env.agent.monitor.reset_abort_count != 1) begin
                    `uvm_error("TEST", $sformatf(
                        "Esperado um cancelamento por reset; observado=%0d",
                        env.agent.monitor.reset_abort_count))
                end
                `uvm_info("TEST", $sformatf(
                    {"PROTOCOLO | busy_attempts=%0d backpressure_cycles=%0d ",
                     "reset_aborts=%0d"},
                    env.agent.monitor.busy_attempt_count,
                    env.agent.monitor.backpressure_cycle_count,
                    env.agent.monitor.reset_abort_count), UVM_NONE)
            end

            if (scenario == "long") begin
                if (env.agent.monitor.accepted_count != 1000) begin
                    `uvm_error("TEST", $sformatf(
                        "Esperadas 1000 entradas aceitas; observado=%0d",
                        env.agent.monitor.accepted_count))
                end
                if (env.agent.monitor.completed_count != 1000) begin
                    `uvm_error("TEST", $sformatf(
                        "Esperadas 1000 saidas; observado=%0d",
                        env.agent.monitor.completed_count))
                end
                if (env.agent.monitor.memory_write_count != 1000) begin
                    `uvm_error("TEST", $sformatf(
                        "Esperadas 1000 escritas na memoria; observado=%0d",
                        env.agent.monitor.memory_write_count))
                end
                if (env.agent.monitor.memory_wrap_count < 3) begin
                    `uvm_error("TEST", $sformatf(
                        "Esperados pelo menos 3 wraps; observado=%0d",
                        env.agent.monitor.memory_wrap_count))
                end
                `uvm_info("TEST", $sformatf(
                    "LONG | aceitas=%0d saidas=%0d escritas=%0d wraps=%0d",
                    env.agent.monitor.accepted_count,
                    env.agent.monitor.completed_count,
                    env.agent.monitor.memory_write_count,
                    env.agent.monitor.memory_wrap_count), UVM_NONE)
            end

            phase.drop_objection(this);
        endtask
    endclass

endpackage
