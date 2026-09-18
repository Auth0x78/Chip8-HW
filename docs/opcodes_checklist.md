# CHIP-8 Standard Opcodes Status

Summary of the 35 standard minimal CHIP-8 opcodes implemented in `rtl/cpu/` and tested via Verilator.

### Status Legend
- **Tested + Implemented**: Implemented in RTL and verified end-to-end in CPU/Control Unit integration tests (`tb_cpu` / `tb_control_unit`).
- **Implemented but not tested**: Implemented in RTL (`control_unit.sv`, `decoder.sv`, `alu.sv`), awaiting full CPU integration test cases.
- **No to both**: Neither implemented nor tested (`0NNN` RCA 1802 call).

---

### Summary Table

| Category | Count | Status |
| :--- | :---: | :---: |
| **Tested + Implemented** | **35** | Complete (100% Passed) |
| **Implemented but not tested** | **0** | All Tested |
| **No to both** | **1** | Unsupported (`0NNN`) |
| **Total Standard Opcodes** | **36** | — |

---

### Opcode Checklist

| Opcode | Mnemonic | Status | RTL Description |
| :--- | :--- | :---: | :--- |
| `00E0` | `CLS` | **Tested + Implemented** | Clears screen; emits `GPU_CMD_CLEAR` |
| `00EE` | `RET` | **Tested + Implemented** | Returns from subroutine; pops PC, `SP--` |
| `0NNN` | `SYS addr` | **No to both** | Legacy RCA 1802 call (unsupported) |
| `1NNN` | `JP addr` | **Tested + Implemented** | Jump to address `NNN` (`PC = NNN`) |
| `2NNN` | `CALL addr` | **Tested + Implemented** | Calls subroutine; pushes return address, `SP++` |
| `3XNN` | `SE Vx, byte` | **Tested + Implemented** | Skip next instruction if `Vx == NN` |
| `4XNN` | `SNE Vx, byte` | **Tested + Implemented** | Skip next instruction if `Vx != NN` |
| `5XY0` | `SE Vx, Vy` | **Tested + Implemented** | Skip next instruction if `Vx == Vy` |
| `6XNN` | `LD Vx, byte` | **Tested + Implemented** | Load immediate into `Vx` |
| `7XNN` | `ADD Vx, byte` | **Tested + Implemented** | Add immediate to `Vx` (no carry flag) |
| `8XY0` | `LD Vx, Vy` | **Tested + Implemented** | Move `Vy` to `Vx` |
| `8XY1` | `OR Vx, Vy` | **Tested + Implemented** | Bitwise OR (`Vx = Vx \| Vy`, resets `VF`) |
| `8XY2` | `AND Vx, Vy` | **Tested + Implemented** | Bitwise AND (`Vx = Vx & Vy`, resets `VF`) |
| `8XY3` | `XOR Vx, Vy` | **Tested + Implemented** | Bitwise XOR (`Vx = Vx ^ Vy`, resets `VF`) |
| `8XY4` | `ADD Vx, Vy` | **Tested + Implemented** | Add with carry (`Vx += Vy`, `VF = carry`) |
| `8XY5` | `SUB Vx, Vy` | **Tested + Implemented** | Subtract (`Vx -= Vy`, `VF = NOT borrow`) |
| `8XY6` | `SHR Vx` | **Tested + Implemented** | Shift right (`Vx >>= 1`, `VF = LSB`) |
| `8XY7` | `SUBN Vx, Vy` | **Tested + Implemented** | Reverse subtract (`Vx = Vy - Vx`, `VF = NOT borrow`) |
| `8XYE` | `SHL Vx` | **Tested + Implemented** | Shift left (`Vx <<= 1`, `VF = MSB`) |
| `9XY0` | `SNE Vx, Vy` | **Tested + Implemented** | Skip next instruction if `Vx != Vy` |
| `ANNN` | `LD I, addr` | **Tested + Implemented** | Set index register `I = NNN` |
| `BNNN` | `JP V0, addr` | **Tested + Implemented** | Jump to `NNN + V0` |
| `CXNN` | `RND Vx, byte` | **Tested + Implemented** | `Vx = random_byte & NN` via LFSR |
| `DXYN` | `DRW Vx, Vy, N`| **Tested + Implemented** | Draw sprite; emits `GPU_CMD_DRAW` |
| `EX9E` | `SKP Vx` | **Tested + Implemented** | Skip next instruction if key `Vx` is pressed |
| `EXA1` | `SKNP Vx` | **Tested + Implemented** | Skip next instruction if key `Vx` is not pressed |
| `FX07` | `LD Vx, DT` | **Tested + Implemented** | Read delay timer into `Vx` |
| `FX0A` | `LD Vx, K` | **Tested + Implemented** | Wait for keypress, then store in `Vx` |
| `FX15` | `LD DT, Vx` | **Tested + Implemented** | Write delay timer from `Vx` |
| `FX18` | `LD ST, Vx` | **Tested + Implemented** | Write sound timer from `Vx` (activates sound) |
| `FX1E` | `ADD I, Vx` | **Tested + Implemented** | Add register `Vx` to index `I` |
| `FX29` | `LD F, Vx` | **Tested + Implemented** | Point `I` to 5-byte font character `Vx` |
| `FX33` | `LD B, Vx` | **Tested + Implemented** | Store BCD representation of `Vx` at `I..I+2` |
| `FX55` | `LD [I], Vx` | **Tested + Implemented** | Store registers `V0..Vx` to RAM starting at `I` |
| `FX65` | `LD Vx, [I]` | **Tested + Implemented** | Load registers `V0..Vx` from RAM starting at `I` |
