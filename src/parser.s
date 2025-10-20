# Minimal parser for simple C subset
# Handles: int main() { ... }

.section .data
    .global NODE_PROGRAM
    .global NODE_FUNCTION
    .global NODE_BLOCK
    .global current_token_type
    .global current_token_value

    NODE_PROGRAM:     .quad 1
    NODE_FUNCTION:    .quad 2
    NODE_BLOCK:       .quad 10

    str_int:         .string "int"
    str_lparen:      .string "("
    str_rparen:      .string ")"
    str_lbrace:      .string "{"
    str_rbrace:      .string "}"

    current_token_type: .quad 0
    current_token_value: .quad 0

    last_token_storage: .space 256

    ast_heap:         .space 8192
    ast_heap_ptr:     .quad ast_heap

    ast_string_pool:  .space 4096
    ast_string_ptr:   .quad ast_string_pool

.section .text
    .global parser_init
    .global parse_program
    .global parse_function
    .global parse_block
    .global expect_token
    .global advance_token
    .global create_node
    .global store_token_string

parser_init:
    pushq %rbp
    movq %rsp, %rbp

    call get_next_token
    movq %rax, current_token_type
    movq %rdx, current_token_value

    movq $ast_heap, %rax
    movq %rax, ast_heap_ptr

    movq $ast_string_pool, %rax
    movq %rax, ast_string_ptr

    popq %rbp
    ret

advance_token:
    pushq %rbp
    movq %rsp, %rbp

    call get_next_token
    movq %rax, current_token_type
    movq %rdx, current_token_value

    popq %rbp
    ret

expect_token:
    pushq %rbp
    movq %rsp, %rbp

    movq current_token_type, %rax
    cmpq %rdi, %rax
    jne expect_fail

    cmpq $0, %rsi
    je expect_copy

    movq current_token_value, %rdx

expect_compare_loop:
    movb (%rsi), %al
    movb (%rdx), %cl
    cmpb %al, %cl
    jne expect_fail
    cmpb $0, %al
    je expect_copy
    incq %rsi
    incq %rdx
    jmp expect_compare_loop

expect_copy:
    movq current_token_value, %rsi
    leaq last_token_storage(%rip), %rdi

copy_loop:
    movb (%rsi), %al
    movb %al, (%rdi)
    cmpb $0, %al
    je copy_done
    incq %rsi
    incq %rdi
    jmp copy_loop

copy_done:
    call advance_token
    movq $1, %rax
    jmp expect_exit

expect_fail:
    movq $0, %rax

expect_exit:
    popq %rbp
    ret

create_node:
    pushq %rbp
    movq %rsp, %rbp

    movq ast_heap_ptr, %rax
    movq %rdi, (%rax)
    movq %rsi, 8(%rax)
    movq $0, 16(%rax)
    movq $0, 24(%rax)
    movq $0, 32(%rax)

    addq $40, %rax
    movq %rax, ast_heap_ptr

    movq ast_heap_ptr, %rax
    subq $40, %rax

    popq %rbp
    ret

parse_program:
    pushq %rbp
    movq %rsp, %rbp

    movq NODE_PROGRAM(%rip), %rdi
    movq $0, %rsi
    call create_node
    movq %rax, %rbx

    call parse_function
    cmpq $0, %rax
    je program_error

    movq current_token_type, %rcx
    movq TOKEN_EOF(%rip), %rdx
    cmpq %rdx, %rcx
    jne program_error

    movq %rax, 16(%rbx)
    movq %rbx, %rax
    popq %rbp
    ret

program_error:
    movq $0, %rax
    popq %rbp
    ret

parse_function:
    pushq %rbp
    movq %rsp, %rbp

    movq TOKEN_KEYWORD(%rip), %rdi
    leaq str_int(%rip), %rsi
    call expect_token
    cmpq $0, %rax
    je function_error

    movq TOKEN_IDENTIFIER(%rip), %rdi
    movq $0, %rsi
    call expect_token
    cmpq $0, %rax
    je function_error
    leaq last_token_storage(%rip), %rdi
    call store_token_string
    movq %rax, %rsi

    movq NODE_FUNCTION(%rip), %rdi
    call create_node
    movq %rax, %rbx

    movq TOKEN_DELIMITER(%rip), %rdi
    leaq str_lparen(%rip), %rsi
    call expect_token       # '('
    cmpq $0, %rax
    je function_error

    movq TOKEN_DELIMITER(%rip), %rdi
    leaq str_rparen(%rip), %rsi
    call expect_token       # ')'
    cmpq $0, %rax
    je function_error

    call parse_block
    cmpq $0, %rax
    je function_error

    movq %rax, 16(%rbx)
    movq %rbx, %rax
    popq %rbp
    ret

function_error:
    movq $0, %rax
    popq %rbp
    ret

parse_block:
    pushq %rbp
    movq %rsp, %rbp
    pushq %r12

    movq TOKEN_DELIMITER(%rip), %rdi
    leaq str_lbrace(%rip), %rsi
    call expect_token       # '{'
    cmpq $0, %rax
    je block_error

    movq NODE_BLOCK(%rip), %rdi
    movq $0, %rsi
    call create_node
    movq %rax, %rbx

    movq $1, %r12           # brace depth

block_loop:
    movq current_token_type, %rax
    movq TOKEN_EOF(%rip), %rdx
    cmpq %rdx, %rax
    je block_error

    movq TOKEN_DELIMITER(%rip), %rdx
    cmpq %rdx, %rax
    jne block_advance

    movq current_token_value, %rdi
    movb (%rdi), %al
    cmpb $123, %al          # '{'
    jne block_check_close

    movq TOKEN_DELIMITER(%rip), %rdi
    leaq str_lbrace(%rip), %rsi
    call expect_token
    cmpq $0, %rax
    je block_error
    incq %r12
    jmp block_loop

block_check_close:
    cmpb $125, %al          # '}'
    jne block_advance

    movq TOKEN_DELIMITER(%rip), %rdi
    leaq str_rbrace(%rip), %rsi
    call expect_token
    cmpq $0, %rax
    je block_error
    decq %r12
    cmpq $0, %r12
    jne block_loop
    jmp block_done

block_advance:
    call advance_token
    jmp block_loop

block_done:
    movq %rbx, %rax
    popq %r12
    popq %rbp
    ret

block_error:
    movq $0, %rax
    popq %r12
    popq %rbp
    ret

store_token_string:
    pushq %rbp
    movq %rsp, %rbp

    movq ast_string_ptr, %rsi
    movq %rsi, %rax

store_loop:
    movb (%rdi), %al
    movb %al, (%rsi)
    incq %rdi
    incq %rsi
    cmpb $0, %al
    jne store_loop

    movq %rsi, ast_string_ptr

    popq %rbp
    ret

.section .data
