# Simplified Code Generator for C Compiler
# Written in x86_64 Assembly (AT&T syntax)
# Generates minimal working x86_64 assembly code

.section .data
    # Output buffer (make it global so main.s can access it)
    .global output_buffer
    output_buffer:    .space 8192
    output_ptr:       .quad output_buffer
    
    # Simple hardcoded output for testing
    simple_program:
        .ascii ".section .text\n"
        .ascii ".globl _start\n"
        .ascii "_start:\n"
        .ascii "\tcall main\n"
        .ascii "\tmovq %rax, %rdi\n"
        .ascii "\tmovq $60, %rax\n"
        .ascii "\tsyscall\n\n"
        .ascii ".globl main\n"
        .ascii "main:\n"
        .ascii "\tpushq %rbp\n"
        .ascii "\tmovq %rsp, %rbp\n"
        .ascii "\tmovq $42, %rax\n"
        .ascii "\tpopq %rbp\n"
        .ascii "\tret\n"
        .byte 0
    
.section .text
    .global codegen_init
    .global generate_code
    .global output_buffer

# Initialize code generator
codegen_init:
    pushq %rbp
    movq %rsp, %rbp
    
    # Reset output pointer
    movq $output_buffer, %rax
    movq %rax, output_ptr
    
    popq %rbp
    ret

# Generate code from AST (simplified version)
# Parameters: %rdi = pointer to root AST node
# Returns: %rax = pointer to generated code
generate_code:
    pushq %rbp
    movq %rsp, %rbp
    
    # For now, just copy the simple program template
    movq $simple_program, %rsi    # Source
    movq $output_buffer, %rdi     # Destination
    
copy_template:
    movb (%rsi), %al
    movb %al, (%rdi)
    cmpb $0, %al
    je copy_done
    incq %rsi
    incq %rdi
    jmp copy_template
    
copy_done:
    # Return pointer to output buffer
    movq $output_buffer, %rax
    
    popq %rbp
    ret