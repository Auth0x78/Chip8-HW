# CHIP-8 Opcodes

This file gives a quick reference for the CHIP-8 instruction set used by the project. It is meant to be a practical guide while implementing the CPU decoder and execution logic.

## Notation

- `N` = 4-bit value
- `NN` = 8-bit value
- `NNN` = 12-bit address
- `x` = high nibble register index
- `y` = low nibble register index
- `Vx` = register `x`
- `Vy` = register `y`

> This reference covers the classic CHIP-8 base instruction set. Extended variants such as SCHIP and XO-CHIP are not included here.

## 00E0 – Clear display

```text
00E0
```

Clear the display.

## 00EE – Return from subroutine

```text
00EE
```

Return from a subroutine by popping the return address from the stack.

## 1NNN – Jump

```text
1NNN
```

Set `PC` to address `NNN`.

## 2NNN – Call subroutine

```text
2NNN
```

Call subroutine at `NNN`; store return address on stack.

## 3xNN – Skip if equal

```text
3xNN
```

If `Vx == NN`, skip the next instruction.

## 4xNN – Skip if not equal

```text
4xNN
```

If `Vx != NN`, skip the next instruction.

## 5xy0 – Skip if equal registers

```text
5xy0
```

If `Vx == Vy`, skip the next instruction.

## 6xNN – Load immediate

```text
6xNN
```

Set `Vx = NN`.

## 7xNN – Add immediate

```text
7xNN
```

Set `Vx = Vx + NN`.

## 8xy0 – Load register

```text
8xy0
```

Set `Vx = Vy`.

## 8xy1 – OR register

```text
8xy1
```

Set `Vx = Vx OR Vy`.

## 8xy2 – AND register

```text
8xy2
```

Set `Vx = Vx AND Vy`.

## 8xy3 – XOR register

```text
8xy3
```

Set `Vx = Vx XOR Vy`.

## 8xy4 – Add register

```text
8xy4
```

Set `Vx = Vx + Vy`, and set `VF` to carry.

## 8xy5 – Subtract register

```text
8xy5
```

Set `Vx = Vx - Vy`, and set `VF` to no borrow.

## 8xy6 – Shift right

```text
8xy6
```

Set `Vx = Vx >> 1`, and `VF` gets the shifted-out bit.

## 8xy7 – Subtract reversed

```text
8xy7
```

Set `Vx = Vy - Vx`, and set `VF` to no borrow.

## 8xyE – Shift left

```text
8xyE
```

Set `Vx = Vx << 1`, and `VF` gets the shifted-out bit.

## 9xy0 – Skip if not equal registers

```text
9xy0
```

If `Vx != Vy`, skip the next instruction.

## ANNN – Load index register

```text
ANNN
```

Set `I = NNN`.

## BNNN – Jump with offset

```text
BNNN
```

Set `PC = NNN + V0`.

## CxNN – Random AND immediate

```text
CxNN
```

Set `Vx = random_byte & NN`.

## Dxyn – Draw sprite

```text
dxyn
```

Draw an `n`-byte sprite at `(Vx, Vy)` from memory at address `I`.

- XOR the sprite into VRAM
- set `VF` if pixels are erased
- wrap coordinates as needed

## Ex9E – Skip if key pressed

```text
Ex9E
```

If key `Vx` is pressed, skip the next instruction.

## ExA1 – Skip if key not pressed

```text
ExA1
```

If key `Vx` is not pressed, skip the next instruction.

## Fx07 – Load delay timer

```text
Fx07
```

Set `Vx = DT`.

## Fx0A – Wait for key press

```text
Fx0A
```

Wait for a key press, then store the key value in `Vx`.

## Fx15 – Set delay timer

```text
Fx15
```

Set `DT = Vx`.

## Fx18 – Set sound timer

```text
Fx18
```

Set `ST = Vx`.

## Fx1E – Add to index register

```text
Fx1E
```

Set `I = I + Vx`.

## Fx29 – Set I to font sprite

```text
Fx29
```

Set `I` to the memory location of the sprite for digit `Vx`.

## Fx33 – BCD store

```text
Fx33
```

Store the BCD representation of `Vx` at memory addresses `I`, `I+1`, and `I+2`.

## Fx55 – Store registers to memory

```text
Fx55
```

Store registers `V0` to `Vx` in memory starting at `I`.

## Fx65 – Load registers from memory

```text
Fx65
```

Load registers `V0` to `Vx` from memory starting at `I`.

## Summary table

| Opcode | Meaning |
| :--- | :--- |
| `00E0` | Clear display |
| `00EE` | Return from subroutine |
| `1NNN` | Jump |
| `2NNN` | Call subroutine |
| `3xNN` | Skip if `Vx == NN` |
| `4xNN` | Skip if `Vx != NN` |
| `5xy0` | Skip if `Vx == Vy` |
| `6xNN` | Set `Vx = NN` |
| `7xNN` | `Vx += NN` |
| `8xy*` | Register arithmetic and bitwise ops |
| `9xy0` | Skip if `Vx != Vy` |
| `ANNN` | Set `I = NNN` |
| `BNNN` | Jump with `V0` offset |
| `CxNN` | Random AND |
| `Dxyn` | Draw sprite |
| `Ex9E` | Skip if key pressed |
| `ExA1` | Skip if key not pressed |
| `Fx07` | `Vx = DT` |
| `Fx0A` | Wait for key press |
| `Fx15` | `DT = Vx` |
| `Fx18` | `ST = Vx` |
| `Fx1E` | `I += Vx` |
| `Fx29` | Font sprite address |
| `Fx33` | BCD store |
| `Fx55` | Store registers |
| `Fx65` | Load registers |

This reference is intended to support the decoder design and CPU execution logic in the current project.
