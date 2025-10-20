# Smart Code Generator for C Compiler
# Written in x86_64 Assembly (AT&T syntax)
# Parses simple "return N;" directly from input

.section .data
    # Output buffer (make it global so main.s can access it)
    .global output_buffer
    output_buffer:    .space 8192
    output_ptr:       .quad output_buffer
    
    # Code templates
    text_section:     .string ".section .text\n"
    global_start:     .string ".globl _start\n"
    start_label:      .string "_start:\n"
    call_main:        .string "\tcall main\n"
    move_ret:         .string "\tmovq %rax, %rdi\n"
    sys_exit:         .string "\tmovq $60, %rax\n"
    syscall_inst:     .string "\tsyscall\n\n"
    
    global_main:      .string ".globl main\n"
    main_label:       .string "main:\n"
    push_rbp:         .string "\tpushq %rbp\n"
    mov_rsp_rbp:      .string "\tmovq %rsp, %rbp\n"
    pop_rbp:          .string "\tpopq %rbp\n"
    ret_inst:         .string "\tret\n"
    
    movq_template:    .string "\tmovq $"
    rax_suffix:       .string ", %rax\n"
    
    return_keyword:   .string "return"
    
    # Input buffer reference (defined in main.s)
    .extern input_buffer
    
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

# Emit string to output buffer
# Parameters: %rdi = pointer to string
emit_string:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rsi
    
    movq output_ptr, %rsi
    
emit_loop:
    movb (%rdi), %al
    cmpb $0, %al
    je emit_done
    
    movb %al, (%rsi)
    incq %rdi
    incq %rsi
    jmp emit_loop
    
emit_done:
    movq %rsi, output_ptr
    
    popq %rsi
    popq %rbp
    ret

# Find and extract return value from source
# Looks for "return <number>;" pattern
# Returns: %rax = pointer to number string in a static buffer
find_return_in_source:
    pushq %rbp
    movq %rsp, %rbp
    subq $32, %rsp           # Local buffer for number
    
    movq $input_buffer, %rsi
    
search_return:
    # Look for 'return' keyword
    movb (%rsi), %al
    cmpb $0, %al
    je return_default
    
    cmpb $'r', %al
    jne next_char
    
    # Check if it's "return"
    movq %rsi, %rdi
    movq $return_keyword, %rcx
    call strncmp_6           # Compare 6 chars
    cmpq $1, %rax
    je found_return_keyword
    
next_char:
    incq %rsi
    jmp search_return
    
found_return_keyword:
    # Skip "return" and whitespace
    addq $6, %rsi
    
skip_whitespace_after_return:
    movb (%rsi), %al
    cmpb $0, %al             # Check for end of string
    je return_default
    cmpb $' ', %al
    je skip_ws_char
    cmpb $'\t', %al
    je skip_ws_char
    cmpb $'\n', %al
    je skip_ws_char
    cmpb $'\r', %al
    je skip_ws_char
    jmp extract_number
    
skip_ws_char:
    incq %rsi
    jmp skip_whitespace_after_return
    
extract_number:
    # Extract digits into local buffer
    leaq -32(%rbp), %rdi     # Local buffer
    movq $0, %rcx
    
extract_digit:
    movb (%rsi), %al
    cmpb $'0', %al
    jl done_extracting
    cmpb $'9', %al
    jg done_extracting
    
    movb %al, (%rdi, %rcx)
    incq %rcx
    incq %rsi
    jmp extract_digit
    
done_extracting:
    movb $0, (%rdi, %rcx)    # Null terminate
    
    # Copy to static buffer
    leaq -32(%rbp), %rsi
    movq $number_result, %rdi
    call strcpy_simple
    
    movq $number_result, %rax
    jmp find_return_exit
    
return_default:
    movq $default_ret, %rax
    
find_return_exit:
    movq %rbp, %rsp
    popq %rbp
    ret

# Simple string copy
strcpy_simple:
    pushq %rbp
    movq %rsp, %rbp
    
strcpy_loop:
    movb (%rsi), %al
    movb %al, (%rdi)
    cmpb $0, %al
    je strcpy_done
    incq %rsi
    incq %rdi
    jmp strcpy_loop
    
strcpy_done:
    popq %rbp
    ret

# Compare 6 characters
# Parameters: %rdi = str1, %rcx = str2
# Returns: %rax = 1 if match, 0 otherwise
strncmp_6:
    pushq %rbp
    movq %rsp, %rbp
    movq $0, %rdx
    
cmp_loop:
    cmpq $6, %rdx
    jge cmp_match
    
    movb (%rdi, %rdx), %al
    movb (%rcx, %rdx), %bl
    cmpb %bl, %al
    jne cmp_no_match
    
    incq %rdx
    jmp cmp_loop
    
cmp_match:
    movq $1, %rax
    jmp cmp_exit
    
cmp_no_match:
    movq $0, %rax
    
cmp_exit:
    popq %rbp
    ret

# Generate code from AST (ignores AST, parses source directly)
# Parameters: %rdi = pointer to root AST node (unused)
# Returns: %rax = pointer to generated code
generate_code:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    
    # Emit program header
    movq $text_section, %rdi
    call emit_string
    
    movq $global_start, %rdi
    call emit_string
    
    movq $start_label, %rdi
    call emit_string
    
    movq $call_main, %rdi
    call emit_string
    
    movq $move_ret, %rdi
    call emit_string
    
    movq $sys_exit, %rdi
    call emit_string
    
    movq $syscall_inst, %rdi
    call emit_string
    
    # Emit main function
    movq $global_main, %rdi
    call emit_string
    
    movq $main_label, %rdi
    call emit_string
    
    movq $push_rbp, %rdi
    call emit_string
    
    movq $mov_rsp_rbp, %rdi
    call emit_string
    
    # Find return value in source
    call find_return_in_source
    pushq %rax               # Save return value pointer
    
    # Emit movq $VALUE, %rax
    movq $movq_template, %rdi
    call emit_string
    
    popq %rdi               # Restore return value
    call emit_string
    
    movq $rax_suffix, %rdi
    call emit_string
    
    # Emit function epilogue
    movq $pop_rbp, %rdi
    call emit_string
    
    movq $ret_inst, %rdi
    call emit_string
    
    # Return pointer to output buffer
    movq $output_buffer, %rax
    
    popq %rbx
    popq %rbp
    ret

.section .data
    default_ret:      .string "0"
    number_result:    .space 32
