#include <neorv32.h>
#include <stdint.h>

#include "audio_regs.h"

#define UART_BAUD_RATE        19200u
#define EXPECTED_CLOCK_HZ     50000000u
#define POLL_LIMIT            1000000u
#define SAMPLE_COUNT          1000u
#define BENCHMARK_REPETITIONS 5u
#define BENCHMARK_VOLUME_Q8   128u

static int16_t input_samples[SAMPLE_COUNT];
static volatile uint32_t benchmark_sink;

static void io_fence(void) {
  __asm__ volatile ("fence iorw, iorw" ::: "memory");
}

static void halt_forever(void) {
  while (1) {
    __asm__ volatile ("nop");
  }
}

static void print_u64(uint64_t value) {
  char digits[21];
  uint32_t index = 0u;

  if (value == 0u) {
    neorv32_uart0_putc('0');
    return;
  }

  while ((value != 0u) && (index < sizeof(digits))) {
    digits[index] = (char)('0' + (value % 10u));
    value /= 10u;
    index++;
  }

  while (index != 0u) {
    index--;
    neorv32_uart0_putc(digits[index]);
  }
}

static void print_fixed(uint64_t scaled_value, uint32_t decimal_digits) {
  uint64_t scale = 1u;
  uint64_t integer_part;
  uint32_t fractional_part;
  uint32_t divisor;
  uint32_t digit;

  for (digit = 0u; digit < decimal_digits; digit++) {
    scale *= 10u;
  }

  integer_part = scaled_value / scale;
  fractional_part = (uint32_t)(scaled_value % scale);
  print_u64(integer_part);

  if (decimal_digits != 0u) {
    neorv32_uart0_putc('.');
    divisor = (uint32_t)(scale / 10u);
    while (divisor != 0u) {
      digit = fractional_part / divisor;
      neorv32_uart0_putc((char)('0' + digit));
      fractional_part %= divisor;
      divisor /= 10u;
    }
  }
}

static int wait_status(uint32_t mask, uint32_t expected) {
  uint32_t count;

  for (count = 0u; count < POLL_LIMIT; count++) {
    if ((AUDIO_READ32(AUDIO_STATUS_OFFSET) & mask) == expected) {
      return 0;
    }
  }

  return -1;
}

static int cycle_counter_available(void) {
  uint64_t start_cycle;
  uint64_t end_cycle;
  uint32_t index;

  start_cycle = neorv32_cpu_get_cycle();
  for (index = 0u; index < 32u; index++) {
    __asm__ volatile ("nop");
  }
  end_cycle = neorv32_cpu_get_cycle();

  return (end_cycle > start_cycle) ? 1 : 0;
}

static int configure_benchmark_path(void) {
  AUDIO_WRITE32(AUDIO_CONTROL_OFFSET, AUDIO_MODE_HARD_CLIP);
  AUDIO_WRITE32(AUDIO_DELAY_OFFSET, 0u);
  AUDIO_WRITE32(AUDIO_FEEDBACK_OFFSET, 0u);
  AUDIO_WRITE32(AUDIO_VOLUME_OFFSET, BENCHMARK_VOLUME_Q8);
  io_fence();

  if ((AUDIO_READ32(AUDIO_CONTROL_OFFSET) & AUDIO_CONTROL_MODE_MASK) !=
      AUDIO_MODE_HARD_CLIP) {
    return -1;
  }
  if ((AUDIO_READ32(AUDIO_DELAY_OFFSET) & 0xffffu) != 0u) {
    return -1;
  }
  if ((AUDIO_READ32(AUDIO_FEEDBACK_OFFSET) & 0xffu) != 0u) {
    return -1;
  }
  if ((AUDIO_READ32(AUDIO_VOLUME_OFFSET) & 0x1ffu) !=
      BENCHMARK_VOLUME_Q8) {
    return -1;
  }

  return 0;
}

static int16_t software_hard_clip_volume(int16_t input) {
  int32_t scaled_audio;
  int32_t clipped_audio;
  int32_t volume_product;
  int32_t volume_scaled;

  scaled_audio = (int32_t)input * 16;
  if (scaled_audio > 32767) {
    clipped_audio = 32767;
  } else if (scaled_audio < -32768) {
    clipped_audio = -32768;
  } else {
    clipped_audio = scaled_audio;
  }

  volume_product = clipped_audio * (int32_t)BENCHMARK_VOLUME_Q8;
  volume_scaled = volume_product >> 8;

  if (volume_scaled > 32767) {
    return (int16_t)32767;
  }
  if (volume_scaled < -32768) {
    return (int16_t)-32768;
  }
  return (int16_t)volume_scaled;
}

static int hardware_process_sample(int16_t input, int16_t *output) {
  uint32_t raw_output;

  if (wait_status(AUDIO_STATUS_READY, AUDIO_STATUS_READY) != 0) {
    return -1;
  }

  AUDIO_WRITE32(AUDIO_IN_OFFSET, (uint32_t)(uint16_t)input);
  io_fence();

  if (wait_status(AUDIO_STATUS_OUT_VALID, AUDIO_STATUS_OUT_VALID) != 0) {
    return -2;
  }

  raw_output = AUDIO_READ32(AUDIO_OUT_OFFSET);
  io_fence();
  *output = (int16_t)(raw_output & 0xffffu);
  return 0;
}

static uint32_t update_signature(uint32_t signature,
                                 int16_t output,
                                 uint32_t index) {
  signature = (signature << 5) | (signature >> 27);
  signature ^= (uint32_t)(uint16_t)output;
  signature += index + 0x9e3779b9u;
  return signature;
}

static void generate_input_vector(void) {
  uint32_t state = 0x13579bdfu;
  uint32_t index;

  for (index = 0u; index < SAMPLE_COUNT; index++) {
    state = (state * 1664525u) + 1013904223u;
    input_samples[index] = (int16_t)(state >> 16);
  }

  input_samples[0] = (int16_t)-32768;
  input_samples[1] = (int16_t)-2049;
  input_samples[2] = (int16_t)-2048;
  input_samples[3] = (int16_t)-1;
  input_samples[4] = (int16_t)0;
  input_samples[5] = (int16_t)1;
  input_samples[6] = (int16_t)2047;
  input_samples[7] = (int16_t)2048;
  input_samples[8] = (int16_t)32767;
}

static int validate_equivalence(void) {
  uint32_t index;
  uint32_t mismatch_count = 0u;
  int16_t software_output;
  int16_t hardware_output;
  int16_t first_input = 0;
  int16_t first_software = 0;
  int16_t first_hardware = 0;

  for (index = 0u; index < SAMPLE_COUNT; index++) {
    software_output = software_hard_clip_volume(input_samples[index]);
    if (hardware_process_sample(input_samples[index], &hardware_output) != 0) {
      neorv32_uart0_printf("Validacao SW x HW: FALHA (timeout na amostra %u)\r\n",
                           index);
      return -1;
    }

    if (software_output != hardware_output) {
      if (mismatch_count == 0u) {
        first_input = input_samples[index];
        first_software = software_output;
        first_hardware = hardware_output;
      }
      mismatch_count++;
    }
  }

  if (mismatch_count != 0u) {
    neorv32_uart0_printf(
      "Validacao SW x HW: FALHA | divergencias=%u | entrada=%i | SW=%i | HW=%i\r\n",
      mismatch_count, (int32_t)first_input, (int32_t)first_software,
      (int32_t)first_hardware);
    return -1;
  }

  neorv32_uart0_printf("Validacao SW x HW: PASS (%u/%u amostras)\r\n",
                       SAMPLE_COUNT, SAMPLE_COUNT);
  return 0;
}

static uint64_t benchmark_empty_loop(void) {
  uint64_t start_cycle;
  uint64_t end_cycle;
  uint32_t signature = 0u;
  uint32_t index;

  start_cycle = neorv32_cpu_get_cycle();
  for (index = 0u; index < SAMPLE_COUNT; index++) {
    signature = update_signature(signature, input_samples[index], index);
  }
  end_cycle = neorv32_cpu_get_cycle();

  benchmark_sink = signature;
  return end_cycle - start_cycle;
}

static uint64_t benchmark_software(uint32_t *signature_out) {
  uint64_t start_cycle;
  uint64_t end_cycle;
  uint32_t signature = 0u;
  uint32_t index;
  int16_t output;

  start_cycle = neorv32_cpu_get_cycle();
  for (index = 0u; index < SAMPLE_COUNT; index++) {
    output = software_hard_clip_volume(input_samples[index]);
    signature = update_signature(signature, output, index);
  }
  end_cycle = neorv32_cpu_get_cycle();

  *signature_out = signature;
  benchmark_sink = signature;
  return end_cycle - start_cycle;
}

static int benchmark_hardware(uint64_t *cycles_out, uint32_t *signature_out) {
  uint64_t start_cycle;
  uint64_t end_cycle;
  uint32_t signature = 0u;
  uint32_t index;
  int16_t output;

  start_cycle = neorv32_cpu_get_cycle();
  for (index = 0u; index < SAMPLE_COUNT; index++) {
    if (hardware_process_sample(input_samples[index], &output) != 0) {
      return -1;
    }
    signature = update_signature(signature, output, index);
  }
  end_cycle = neorv32_cpu_get_cycle();

  *cycles_out = end_cycle - start_cycle;
  *signature_out = signature;
  benchmark_sink = signature;
  return 0;
}

static void print_summary_metrics(const char *label,
                                  uint64_t minimum_cycles,
                                  uint64_t average_cycles) {
  uint64_t cycles_per_sample_milli;
  uint64_t samples_per_cycle_micro;
  uint64_t samples_per_second;

  cycles_per_sample_milli = (average_cycles * 1000u) / SAMPLE_COUNT;
  samples_per_cycle_micro =
    ((uint64_t)SAMPLE_COUNT * 1000000u) / average_cycles;
  samples_per_second =
    ((uint64_t)SAMPLE_COUNT * EXPECTED_CLOCK_HZ) / average_cycles;

  neorv32_uart0_printf("%s\r\n", label);
  neorv32_uart0_puts("  ciclos (menor/media): ");
  print_u64(minimum_cycles);
  neorv32_uart0_putc('/');
  print_u64(average_cycles);
  neorv32_uart0_puts("\r\n  ciclos/amostra: ");
  print_fixed(cycles_per_sample_milli, 3u);
  neorv32_uart0_puts(" | amostras/ciclo: ");
  print_fixed(samples_per_cycle_micro, 6u);
  neorv32_uart0_puts("\r\n  amostras/s: ");
  print_u64(samples_per_second);
  neorv32_uart0_puts("\r\n");
}

int main(void) {
  uint64_t empty_cycles;
  uint64_t sw_cycles[BENCHMARK_REPETITIONS];
  uint64_t hw_cycles[BENCHMARK_REPETITIONS];
  uint64_t sw_sum = 0u;
  uint64_t hw_sum = 0u;
  uint64_t sw_min = UINT64_MAX;
  uint64_t hw_min = UINT64_MAX;
  uint64_t sw_average;
  uint64_t hw_average;
  uint64_t speedup_milli;
  uint32_t sw_signature[BENCHMARK_REPETITIONS];
  uint32_t hw_signature[BENCHMARK_REPETITIONS];
  uint32_t repetition;
  uint32_t clock_hz;
  uint32_t version;
  uint32_t failures = 0u;

  neorv32_rte_setup();
  neorv32_uart0_setup(UART_BAUD_RATE, 0);

  neorv32_uart0_puts("\r\n=== AUDIO FX BENCHMARK R3.2 ===\r\n");

  clock_hz = neorv32_sysinfo_get_clk();
  version = AUDIO_READ32(AUDIO_VERSION_OFFSET);
  neorv32_uart0_printf("Amostras: %u | Clock: %u Hz | IP: 0x%x\r\n",
                       SAMPLE_COUNT, clock_hz, version);

  if ((clock_hz != EXPECTED_CLOCK_HZ) ||
      (version != AUDIO_EXPECTED_VERSION)) {
    neorv32_uart0_puts("Pre-check: FALHA (clock ou versao do IP)\r\n");
    halt_forever();
  }

  if (!cycle_counter_available()) {
    neorv32_uart0_puts("Pre-check: FALHA (contador de ciclos indisponivel)\r\n");
    halt_forever();
  }

  if ((AUDIO_READ32(AUDIO_STATUS_OFFSET) & AUDIO_STATUS_REJECTED) != 0u) {
    AUDIO_WRITE32(AUDIO_CONTROL_OFFSET, AUDIO_CONTROL_CLEAR_ERR);
    io_fence();
  }

  if (configure_benchmark_path() != 0) {
    neorv32_uart0_puts("Configuracao do coprocessador: FALHA\r\n");
    halt_forever();
  }

  generate_input_vector();

  if (validate_equivalence() != 0) {
    halt_forever();
  }

  empty_cycles = benchmark_empty_loop();

  for (repetition = 0u; repetition < BENCHMARK_REPETITIONS; repetition++) {
    sw_cycles[repetition] = benchmark_software(&sw_signature[repetition]);
    if (benchmark_hardware(&hw_cycles[repetition],
                           &hw_signature[repetition]) != 0) {
      neorv32_uart0_printf("Benchmark em hardware: FALHA (timeout no teste %u)\r\n",
                           repetition + 1u);
      halt_forever();
    }

    if (sw_signature[repetition] != hw_signature[repetition]) {
      failures++;
    }

    sw_sum += sw_cycles[repetition];
    hw_sum += hw_cycles[repetition];
    if (sw_cycles[repetition] < sw_min) {
      sw_min = sw_cycles[repetition];
    }
    if (hw_cycles[repetition] < hw_min) {
      hw_min = hw_cycles[repetition];
    }
  }

  sw_average = sw_sum / BENCHMARK_REPETITIONS;
  hw_average = hw_sum / BENCHMARK_REPETITIONS;
  speedup_milli = (sw_average * 1000u) / hw_average;

  neorv32_uart0_puts("Loop de referencia: ");
  print_u64(empty_cycles);
  neorv32_uart0_puts(" ciclos\r\n");

  neorv32_uart0_puts("\r\nExecucoes\r\n");

  for (repetition = 0u; repetition < BENCHMARK_REPETITIONS; repetition++) {
    neorv32_uart0_printf("  %u) Software: ", repetition + 1u);
    print_u64(sw_cycles[repetition]);
    neorv32_uart0_puts(" ciclos | Hardware: ");
    print_u64(hw_cycles[repetition]);
    neorv32_uart0_puts(" ciclos\r\n");
  }

  neorv32_uart0_puts("\r\nResumo (5 execucoes)\r\n");
  print_summary_metrics("Software", sw_min, sw_average);
  print_summary_metrics("Hardware fim a fim (AXI + polling)", hw_min,
                        hw_average);
  neorv32_uart0_puts("Relacao SW/HW: ");
  print_fixed(speedup_milli, 3u);
  neorv32_uart0_puts("x\r\n");

  if ((AUDIO_READ32(AUDIO_STATUS_OFFSET) & AUDIO_STATUS_REJECTED) != 0u) {
    neorv32_uart0_puts("Status de escrita rejeitada: FALHA\r\n");
    failures++;
  }

  if (failures == 0u) {
    neorv32_uart0_puts("\r\nResultado final: PASS\r\n");
  } else {
    neorv32_uart0_printf("\r\nResultado final: FALHA (%u erro(s))\r\n",
                         failures);
  }

  halt_forever();
  return 0;
}
