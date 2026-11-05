#include <neorv32.h>
#include <stdint.h>

#include "audio_regs.h"

#define UART_BAUD_RATE       19200u
#define EXPECTED_CLOCK_HZ    50000000u
#define POLL_LIMIT           1000000u

static void io_fence(void) {
  __asm__ volatile ("fence iorw, iorw" ::: "memory");
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

static int configure_effect(uint32_t mode,
                            uint32_t delay_samples,
                            uint32_t feedback_q8,
                            uint32_t volume_q8) {
  AUDIO_WRITE32(AUDIO_CONTROL_OFFSET, mode & AUDIO_CONTROL_MODE_MASK);
  AUDIO_WRITE32(AUDIO_DELAY_OFFSET, delay_samples & 0xFFFFu);
  AUDIO_WRITE32(AUDIO_FEEDBACK_OFFSET, feedback_q8 & 0xFFu);
  AUDIO_WRITE32(AUDIO_VOLUME_OFFSET, volume_q8 & 0x1FFu);
  io_fence();

  if ((AUDIO_READ32(AUDIO_CONTROL_OFFSET) & AUDIO_CONTROL_MODE_MASK) !=
      (mode & AUDIO_CONTROL_MODE_MASK)) {
    return -1;
  }
  if ((AUDIO_READ32(AUDIO_DELAY_OFFSET) & 0xFFFFu) !=
      (delay_samples & 0xFFFFu)) {
    return -1;
  }
  if ((AUDIO_READ32(AUDIO_FEEDBACK_OFFSET) & 0xFFu) !=
      (feedback_q8 & 0xFFu)) {
    return -1;
  }
  if ((AUDIO_READ32(AUDIO_VOLUME_OFFSET) & 0x1FFu) !=
      (volume_q8 & 0x1FFu)) {
    return -1;
  }

  return 0;
}

static int process_sample(const char *label, int16_t input, int16_t expected) {
  int32_t output;

  if (wait_status(AUDIO_STATUS_READY, AUDIO_STATUS_READY) != 0) {
    neorv32_uart0_printf("%s : FAIL (timeout esperando INPUT_READY)\n", label);
    return 1;
  }

  AUDIO_WRITE32(AUDIO_IN_OFFSET, (uint32_t)(uint16_t)input);
  io_fence();

  if (wait_status(AUDIO_STATUS_OUT_VALID, AUDIO_STATUS_OUT_VALID) != 0) {
    neorv32_uart0_printf("%s : FAIL (timeout esperando OUTPUT_VALID)\n", label);
    return 1;
  }

  output = (int32_t)AUDIO_READ32(AUDIO_OUT_OFFSET);
  io_fence();

  neorv32_uart0_printf("%s | IN=%i OUT=%i EXPECTED=%i : ",
                       label, (int32_t)input, output, (int32_t)expected);

  if (output != (int32_t)expected) {
    neorv32_uart0_puts("FAIL\n");
    return 1;
  }

  neorv32_uart0_puts("PASS\n");
  return 0;
}

static int check_configuration(const char *label,
                               uint32_t mode,
                               uint32_t delay_samples,
                               uint32_t feedback_q8,
                               uint32_t volume_q8) {
  if (configure_effect(mode, delay_samples, feedback_q8, volume_q8) != 0) {
    neorv32_uart0_printf("%s : FAIL (readback de configuracao)\n", label);
    return 1;
  }

  neorv32_uart0_printf("%s : PASS\n", label);
  return 0;
}

int main(void) {
  uint32_t clock_hz;
  uint32_t version;
  uint32_t status;
  int failures = 0;

  neorv32_rte_setup();
  neorv32_uart0_setup(UART_BAUD_RATE, 0);

  neorv32_uart0_puts("\n[AUDIO FX AXI] BUILD R2 2026-11-02\n");
  neorv32_uart0_puts("UART baseline preserved at 19200 baud.\n");
  neorv32_uart0_printf("Peripheral base: 0x%x\n", AUDIO_BASE_ADDR);

  clock_hz = neorv32_sysinfo_get_clk();
  neorv32_uart0_printf("NEORV32 clock: %u Hz : ", clock_hz);
  if (clock_hz == EXPECTED_CLOCK_HZ) {
    neorv32_uart0_puts("PASS\n");
  } else {
    neorv32_uart0_puts("FAIL\n");
    failures++;
  }

  version = AUDIO_READ32(AUDIO_VERSION_OFFSET);
  neorv32_uart0_printf("IP_VERSION=0x%x EXPECTED=0x%x : ",
                       version, AUDIO_EXPECTED_VERSION);
  if (version == AUDIO_EXPECTED_VERSION) {
    neorv32_uart0_puts("PASS\n");
  } else {
    neorv32_uart0_puts("FAIL\n");
    failures++;
  }

  status = AUDIO_READ32(AUDIO_STATUS_OFFSET);
  if ((status & AUDIO_STATUS_REJECTED) != 0u) {
    AUDIO_WRITE32(AUDIO_CONTROL_OFFSET, AUDIO_CONTROL_CLEAR_ERR);
    io_fence();
  }

  /* O bitcrusher mantem estado; teste-o antes dos demais modos. */
  failures += check_configuration("CONFIG BITCRUSHER", AUDIO_MODE_BITCRUSHER, 0u, 0u, 256u);
  failures += process_sample("BITCRUSHER QUANTIZE", 1500, 1024);
  failures += process_sample("BITCRUSHER HOLD", 7000, 1024);

  failures += check_configuration("CONFIG BYPASS", AUDIO_MODE_BYPASS, 0u, 0u, 256u);
  failures += process_sample("BYPASS", -1234, -1234);

  failures += check_configuration("CONFIG HARD CLIP", AUDIO_MODE_HARD_CLIP, 0u, 0u, 256u);
  failures += process_sample("HARD CLIP +", 3000, 32767);
  failures += process_sample("HARD CLIP -", -3000, -32768);

  failures += check_configuration("CONFIG VOLUME", AUDIO_MODE_BYPASS, 0u, 0u, 128u);
  failures += process_sample("VOLUME 0.5", 20000, 10000);

  /* Inicializa o historico usado pelo teste de impulso. */
  failures += check_configuration("CONFIG DELAY PREFILL", AUDIO_MODE_BYPASS, 0u, 128u, 256u);
  failures += process_sample("PREFILL 1", 0, 0);
  failures += process_sample("PREFILL 2", 0, 0);

  failures += check_configuration("CONFIG DELAY", AUDIO_MODE_BYPASS, 2u, 128u, 256u);
  failures += process_sample("DELAY IMPULSE", 1000, 1000);
  failures += process_sample("DELAY GAP", 0, 0);
  failures += process_sample("DELAY ECHO", 0, 500);

  status = AUDIO_READ32(AUDIO_STATUS_OFFSET);
  if ((status & AUDIO_STATUS_REJECTED) != 0u) {
    neorv32_uart0_printf("REJECTED_WRITE sticky | STATUS=0x%x : FAIL\n", status);
    failures++;
  }

  if (failures == 0) {
    neorv32_uart0_puts("AUDIO FX AXI HARDWARE PASS\n");
  } else {
    neorv32_uart0_printf("AUDIO FX AXI HARDWARE FAIL | failures=%i\n", failures);
  }

  while (1) {
    __asm__ volatile ("nop");
  }

  return 0;
}
