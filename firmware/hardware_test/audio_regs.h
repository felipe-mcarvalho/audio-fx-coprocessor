#ifndef AUDIO_REGS_H
#define AUDIO_REGS_H

#include <stdint.h>

/* Deve coincidir com o Address Editor do Vivado. */
#define AUDIO_BASE_ADDR          0x44A00000u

#define AUDIO_CONTROL_OFFSET     0x00u
#define AUDIO_STATUS_OFFSET      0x04u
#define AUDIO_IN_OFFSET          0x08u
#define AUDIO_OUT_OFFSET         0x0Cu
#define AUDIO_DELAY_OFFSET       0x10u
#define AUDIO_FEEDBACK_OFFSET    0x14u
#define AUDIO_VOLUME_OFFSET      0x18u
#define AUDIO_VERSION_OFFSET     0x1Cu

#define AUDIO_MODE_BYPASS        0u
#define AUDIO_MODE_LOW_PASS      1u
#define AUDIO_MODE_HARD_CLIP     2u
#define AUDIO_MODE_BITCRUSHER    3u

#define AUDIO_CONTROL_MODE_MASK  0x00000003u
#define AUDIO_CONTROL_CLEAR_ERR  0x00000100u

#define AUDIO_STATUS_READY       0x00000001u
#define AUDIO_STATUS_BUSY        0x00000002u
#define AUDIO_STATUS_OUT_VALID   0x00000004u
#define AUDIO_STATUS_REJECTED    0x00000008u

#define AUDIO_EXPECTED_VERSION   0x00010000u

#define AUDIO_REG32(offset) \
  (*(volatile uint32_t *)(AUDIO_BASE_ADDR + (uint32_t)(offset)))

#define AUDIO_READ32(offset) \
  (AUDIO_REG32(offset))

#define AUDIO_WRITE32(offset, value) \
  do { AUDIO_REG32(offset) = (uint32_t)(value); } while (0)

#endif
