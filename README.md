# Audio FX coprocessor

Coprocessador de efeitos de áudio em SystemVerilog, integrado ao NEORV32 por
AXI4-Lite.

## Estrutura

```text
rtl/            núcleo e periférico
verification/   UVM do núcleo e teste dirigido do periférico
firmware/       teste de hardware e benchmark
fpga/           wrapper AXI4-Lite e constraints
asic/           scripts de síntese, pós-síntese e DFT
```

Os testes com Xcelium e Genus dependem do ambiente Cadence e da biblioteca
GPDK045. O firmware depende do NEORV32 e de uma toolchain RISC-V(xpack).

O código não inclui o projeto completo do Vivado, netlists geradas, bitstream ou executáveis.

## Execução

No ambiente Cadence:

```bash
cd verification/uvm
./run_xcelium.sh all

cd ../directed
./run_xcelium.sh

cd ../../asic/genus
./run_synthesis.sh
./run_dft.sh

cd ../xcelium
./run_post_synth.sh
./run_post_dft.sh all
```

Os dois últimos comandos usam as netlists produzidas pelos scripts do Genus.

Para compilar um dos firmwares, informe a instalação do NEORV32:

```bash
cd firmware/hardware_test
make NEORV32_HOME=/caminho/para/neorv32
```

O benchmark é compilado da mesma forma em `firmware/benchmark_r3`.
