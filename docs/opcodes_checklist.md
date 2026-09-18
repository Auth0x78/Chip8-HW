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
| **Tested + Implemented** | **12** | Complete |
| **Implemented but not tested** | **23** | Pending Integration TB |
| **No to both** | **1** | Unsupported |
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
| `4XNN` | `SNE Vx, byte` | **Implemented but not tested** | Skip next instruction if `Vx != NN` |
| `5XY0` | `SE Vx, Vy` | **Implemented but not tested** | Skip next instruction if `Vx == Vy` |
| `6XNN` | `LD Vx, byte` | **Tested + Implemented** | Load immediate into `Vx` |
| `7XNN` | `ADD Vx, byte` | **Implemented but not tested** | Add immediate to `Vx` (no carry flag) |
| `8XY0` | `LD Vx, Vy` | **Implemented but not tested** | Move `Vy` to `Vx` |
| `8XY1` | `OR Vx, Vy` | **Implemented but not tested** | Bitwise OR (`Vx = Vx \| Vy`, resets `VF`) |
| `8XY2` | `AND Vx, Vy` | **Implemented but not tested** | Bitwise AND (`Vx = Vx & Vy`, resets `VF`) |
| `8XY3` | `XOR Vx, Vy` | **Implemented but not tested** | Bitwise XOR (`Vx = Vx ^ Vy`, resets `VF`) |
| `8XY4` | `ADD Vx, Vy` | **Tested + Implemented** | Add with carry (`Vx += Vy`, `VF = carry`) |
| `8XY5` | `SUB Vx, Vy` | **Implemented but not tested** | Subtract (`Vx -= Vy`, `VF = NOT borrow`) |
| `8XY6` | `SHR Vx` | **Implemented but not tested** | Shift right (`Vx >>= 1`, `VF = LSB`) |
| `8XY7` | `SUBN Vx, Vy` | **Implemented but not tested** | Reverse subtract (`Vx = Vy - Vx`, `VF = NOT borrow`) |
| `8XYE` | `SHL Vx` | **Implemented but not tested** | Shift left (`Vx <<= 1`, `VF = MSB`) |
| `9XY0` | `SNE Vx, Vy` | **Implemented but not tested** | Skip next instruction if `Vx != Vy` |
| `ANNN` | `LD I, addr` | **Tested + Implemented** | Set index register `I = NNN` |
| `BNNN` | `JP V0, addr` | **Implemented but not tested** | Jump to `NNN + V0` |
| `CXNN` | `RND Vx, byte` | **Implemented but not tested** | `Vx = random_byte & NN` via LFSR |
| `DXYN` | `DRW Vx, Vy, N`| **Tested + Implemented** | Draw sprite; emits `GPU_CMD_DRAW` |
| `EX9E` | `SKP Vx` | **Implemented but not tested** | Skip next instruction if key `Vx` is pressed |
| `EXA1` | `SKNP Vx` | **Implemented but not tested** | Skip next instruction if key `Vx` is not pressed |
| `FX07` | `LD Vx, DT` | **Implemented but not tested** | Read delay timer into `Vx` |
| `FX0A` | `LD Vx, K` | **Implemented but not tested** | Wait for keypress, then store in `Vx` |
| `FX15` | `LD DT, Vx` | **Tested + Implemented** | Write delay timer from `Vx` |
| `FX18` | `LD ST, Vx` | **Tested + Implemented** | Write sound timer from `Vx` (activates sound) |
| `FX1E` | `ADD I, Vx` | **Implemented but not tested** | Add register `Vx` to index `I` |
| `FX29` | `LD F, Vx` | **Implemented but not tested** | Point `I` to 5-byte font character `Vx` |
| `FX33` | `LD B, Vx` | **Tested + Implemented** | Store BCD representation of `Vx` at `I..I+2` |
| `FX55` | `LD [I], Vx` | **Implemented but not tested** | Store registers `V0..Vx` to RAM starting at `I` |
| `FX65` | `LD Vx, [I]` | **Implemented but not tested** | Load registers `V0..Vx` from RAM starting at `I` |
