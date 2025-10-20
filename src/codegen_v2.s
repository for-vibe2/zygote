# Improved Code Generator for C Compiler
# Written in x86_64 Assembly (AT&T syntax)
# Generates x86_64 assembly code from AST

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
    
    # Temporary buffer for number to string conversion
    num_buffer:       .space 32
    
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

# Convert number to string and emit
# Parameters: %rdi = pointer to number string (from token)
emit_number:
    pushq %rbp
    movq %rsp, %rbp
    
    # The number is already a string in the token, just emit it
    call emit_string
    
    popq %rbp
    ret

# Generate code from AST
# Parameters: %rdi = pointer to root AST node
# Returns: %rax = pointer to generated code
generate_code:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    
    movq %rdi, %r12          # Save AST root
    
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
    
    # Process AST to find return value
    # For now, we look for NODE_RETURN in the tree
    movq %r12, %rdi
    call find_return_value
    pushq %rax               # Save return value pointer
    
    # Emit movq $VALUE, %rax
    movq $movq_template, %rdi
    call emit_string
    
    popq %rdi               # Restore return value
    cmpq $0, %rdi
    je emit_default_return
    
    call emit_number
    jmp continue_epilogue
    
emit_default_return:
    movq $default_ret, %rdi
    call emit_string
    
continue_epilogue:
    movq $rax_suffix, %rdi
    call emit_string
    
    # Emit function epilogue
    movq $pop_rbp, %rdi
    call emit_string
    
    movq $ret_inst, %rdi
    call emit_string
    
    # Return pointer to output buffer
    movq $output_buffer, %rax
    
    popq %r12
    popq %rbx
    popq %rbp
    ret

# Find return value in AST
# Parameters: %rdi = AST node pointer
# Returns: %rax = pointer to number string, or 0 if not found
find_return_value:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    
    cmpq $0, %rdi
    je return_not_found
    
    movq %rdi, %r12          # Save node pointer
    
    # Check node type
    movq (%r12), %rax        # Get node type
    
    # Check if it's NODE_NUMBER (4)
    cmpq $4, %rax
    je found_number
    
    # Check if it's NODE_RETURN (7)
    cmpq $7, %rax
    je check_return_child
    
    # Otherwise, recursively check children
    # Check left child (offset 16)
    movq 16(%r12), %rdi
    cmpq $0, %rdi
    je check_right
    call find_return_value
    cmpq $0, %rax
    jne found_value
    
check_right:
    # Check right child (offset 24)
    movq 24(%r12), %rdi
    cmpq $0, %rdi
    je check_next
    call find_return_value
    cmpq $0, %rax
    jne found_value
    
check_next:
    # Check next sibling (offset 32)
    movq 32(%r12), %rdi
    cmpq $0, %rdi
    je return_not_found
    call find_return_value
    jmp found_value
    
check_return_child:
    # For return node, check its child (the expression)
    movq 16(%r12), %rdi
    cmpq $0, %rdi
    je return_not_found
    call find_return_value
    jmp found_value
    
found_number:
    # Return the value pointer (offset 8)
    movq 8(%r12), %rax
    jmp found_value
    
return_not_found:
    movq $0, %rax
    
found_value:
    popq %r12
    popq %rbx
    popq %rbp
    ret

.section .data
    default_ret: .string "0"
