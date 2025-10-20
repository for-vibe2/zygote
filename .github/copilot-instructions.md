# C Compiler Project Instructions

This project is a primitive C compiler written entirely in x86_64 assembly language.

## Project Structure
- `src/` - Assembly source files for the compiler
- `examples/` - Sample C programs to test compilation
- `tests/` - Test cases for compiler components
- `docs/` - Documentation and design notes

## Architecture
The compiler follows a traditional multi-pass design:
1. **Lexer** - Tokenizes C source code
2. **Parser** - Builds Abstract Syntax Tree
3. **Code Generator** - Outputs x86_64 assembly
4. **Main Driver** - Coordinates all phases

## Development Guidelines
- Use AT&T assembly syntax for x86_64
- Follow System V ABI calling conventions
- Implement minimal C subset: variables, arithmetic, if/while, functions
- Target Linux x86_64 platform
- Keep memory management simple with static allocation

## Build Process
- Use GNU assembler (gas) and linker (ld)
- Create position-independent executables
- Link against standard C library for I/O operations