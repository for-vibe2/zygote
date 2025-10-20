# Main C Compiler Driver
# Written in x86_64 Assembly (AT&T syntax)
# Coordinates lexer, parser, and code generator

.section .data
    # Program info
    program_name:     .string "zygote-cc"
    version:          .string "0.1.0"
    
    # Command line arguments
    input_filename:   .space 256
    output_filename:  .space 256
    
    # Default filenames
    default_output:   .string "a.out"
    
    # Status messages
    compiling_msg:    .string "Compiling: %s\n"
    success_msg:      .string "Compilation successful\n"
    error_msg:        .string "Compilation failed\n"
    usage_msg:        .string "Usage: %s <input.c> [-o output]\n"
    # File buffers
    .global input_buffer
    input_buffer:     .space 4096
    # Note: output_buffer is defined in codegen_smart.s
    
    # File descriptors
    input_fd:         .quad 0
    output_fd:        .quad 0
    
.section .text
    .global _start
    .global main
    .global compile_file
    .global read_input_file
    .global write_output_file
    .global print_usage
    .global print_string

# Program entry point
_start:
    # Stack layout at entry:
    # %rsp+0  = argc
    # %rsp+8  = argv[0]
    # %rsp+16 = argv[1]
    # ...
    
    # Get command line arguments
    popq %rdi                # argc
    movq %rsp, %rsi          # argv (pointer to argv[0])
    
    # Call main function
    call main
    
    # Exit with return code from main
    movq %rax, %rdi
    movq $60, %rax           # sys_exit
    syscall

# Main function
# Parameters: %rdi = argc, %rsi = argv
# Returns: %rax = exit code
main:
    pushq %rbp
    movq %rsp, %rbp
    subq $16, %rsp           # Allocate space for local variables
    movq %rdi, -8(%rbp)      # Save argc
    movq %rsi, -16(%rbp)     # Save argv
    
    # Check argument count
    cmpq $2, %rdi
    jl main_usage_error
    
    # Get input filename from argv[1]
    movq -16(%rbp), %rax     # Restore argv
    movq 8(%rax), %rdi       # argv[1]
    movq $input_filename, %rsi
    call copy_string
    
    # Check for output filename option
    movq -8(%rbp), %rdi      # Restore argc
    movq -16(%rbp), %rsi     # Restore argv
    cmpq $4, %rdi            # argc >= 4 for "-o output"
    jl use_default_output
    
    # Check if argv[2] is "-o"
    movq 16(%rsi), %rdi      # argv[2]
    movq $dash_o, %rsi
    call compare_strings
    cmpq $1, %rax
    jne use_default_output
    
    # Get output filename from argv[3]
    movq -16(%rbp), %rsi     # Restore argv
    movq 24(%rsi), %rdi      # argv[3]
    movq $output_filename, %rsi
    call copy_string
    jmp start_compilation
    
use_default_output:
    movq $default_output, %rdi
    movq $output_filename, %rsi
    call copy_string
    
start_compilation:
    # Print compilation message
    movq $compiling_msg, %rdi
    movq $input_filename, %rsi
    call printf_simple
    
    # Compile the file
    call compile_file
    
    # Check compilation result
    cmpq $0, %rax
    jne main_error
    
    # Print success message
    movq $success_msg, %rdi
    call print_string
    
    movq $0, %rax            # Success exit code
    jmp main_exit
    
main_usage_error:
    call print_usage
    movq $1, %rax            # Error exit code
    jmp main_exit
    
main_error:
    movq $error_msg, %rdi
    call print_string
    movq $1, %rax            # Error exit code
    
main_exit:
    movq %rbp, %rsp          # Restore stack pointer
    popq %rbp
    ret

# Main compilation function
# Returns: %rax = 0 on success, 1 on error
compile_file:
    pushq %rbp
    movq %rsp, %rbp

    # Read input file
    call read_input_file
    cmpq $0, %rax
    jne compile_error

    # Initialize lexer with input
    movq $input_buffer, %rdi
    call lexer_init

    # Initialize parser
    call parser_init

    # Parse the program
    call parse_program
    cmpq $0, %rax
    je compile_error

    pushq %rax               # Save AST root

    # Initialize code generator
    call codegen_init

    # Generate code from AST
    popq %rdi               # Restore AST root
    call generate_code

    # Write output file
    call write_output_file
    cmpq $0, %rax
    jne compile_error

    movq $0, %rax           # Success
    jmp compile_exit

compile_error:
    movq $1, %rax           # Error

compile_exit:
    popq %rbp
    ret

# Read input file into buffer
# Returns: %rax = 0 on success, 1 on error
read_input_file:
    pushq %rbp
    movq %rsp, %rbp
    
    # Open input file
    movq $2, %rax           # sys_open
    movq $input_filename, %rdi
    movq $0, %rsi           # O_RDONLY
    movq $0, %rdx           # mode (not used for read)
    syscall
    
    cmpq $0, %rax
    jl read_file_error
    
    movq %rax, input_fd
    
    # Read file contents
    movq $0, %rax           # sys_read
    movq input_fd, %rdi
    movq $input_buffer, %rsi
    movq $4095, %rdx        # Max read size
    syscall
    
    cmpq $0, %rax
    jl read_file_error
    
    # Null-terminate the buffer
    movq $input_buffer, %rdi
    addq %rax, %rdi
    movb $0, (%rdi)
    
    # Close file
    movq $3, %rax           # sys_close
    movq input_fd, %rdi
    syscall
    
    movq $0, %rax           # Success
    jmp read_file_exit
    
read_file_error:
    movq $1, %rax           # Error
    
read_file_exit:
    popq %rbp
    ret

# Write output file from generated code
# Returns: %rax = 0 on success, 1 on error
write_output_file:
    pushq %rbp
    movq %rsp, %rbp
    
    # Create/open output file
    movq $2, %rax           # sys_open
    movq $output_filename, %rdi
    movq $577, %rsi         # O_CREAT | O_WRONLY | O_TRUNC
    movq $420, %rdx         # 0644 permissions
    syscall
    
    cmpq $0, %rax
    jl write_file_error
    
    movq %rax, output_fd
    
    # Calculate output length
    call calculate_output_length
    
    # Write generated code
    movq $1, %rax           # sys_write
    movq output_fd, %rdi
    movq $output_buffer, %rsi
    movq %rdx, %rdx         # Length from calculate_output_length
    syscall
    
    cmpq $0, %rax
    jl write_file_error
    
    # Close file
    movq $3, %rax           # sys_close
    movq output_fd, %rdi
    syscall
    
    movq $0, %rax           # Success
    jmp write_file_exit
    
write_file_error:
    movq $1, %rax           # Error
    
write_file_exit:
    popq %rbp
    ret

# Calculate length of output buffer
# Returns: %rdx = length
calculate_output_length:
    pushq %rbp
    movq %rsp, %rbp
    
    movq $output_buffer, %rdi
    movq $0, %rdx
    
calc_length_loop:
    movb (%rdi), %al
    cmpb $0, %al
    je calc_length_done
    
    incq %rdx
    incq %rdi
    jmp calc_length_loop
    
calc_length_done:
    popq %rbp
    ret

# Copy string from source to destination
# Parameters: %rdi = source, %rsi = destination
copy_string:
    pushq %rbp
    movq %rsp, %rbp
    
copy_loop:
    movb (%rdi), %al
    movb %al, (%rsi)
    cmpb $0, %al
    je copy_done
    
    incq %rdi
    incq %rsi
    jmp copy_loop
    
copy_done:
    popq %rbp
    ret

# Compare two strings
# Parameters: %rdi = string1, %rsi = string2
# Returns: %rax = 1 if equal, 0 if not
compare_strings:
    pushq %rbp
    movq %rsp, %rbp
    
compare_loop:
    movb (%rdi), %al
    movb (%rsi), %bl
    cmpb %bl, %al
    jne compare_not_equal
    
    cmpb $0, %al
    je compare_equal
    
    incq %rdi
    incq %rsi
    jmp compare_loop
    
compare_equal:
    movq $1, %rax
    jmp compare_exit
    
compare_not_equal:
    movq $0, %rax
    
compare_exit:
    popq %rbp
    ret

# Print string to stdout
# Parameters: %rdi = pointer to string
print_string:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rdi               # Save original pointer
    
    # Calculate string length
    movq %rdi, %rsi
    movq $0, %rdx
    
print_length_loop:
    movb (%rsi), %al
    cmpb $0, %al
    je print_string_write
    
    incq %rdx
    incq %rsi
    jmp print_length_loop
    
print_string_write:
    # Write to stdout
    movq $1, %rax           # sys_write
    movq $1, %rdi           # stdout
    popq %rsi               # String (restore original pointer)
    # rdx already has length
    syscall
    
    popq %rbp
    ret

# Simple printf-like function (very basic)
# Parameters: %rdi = format, %rsi = argument
printf_simple:
    pushq %rbp
    movq %rsp, %rbp
    
    # For now, just print the argument
    movq %rsi, %rdi
    call print_string
    
    popq %rbp
    ret

# Print usage information
print_usage:
    pushq %rbp
    movq %rsp, %rbp
    
    movq $usage_msg, %rdi
    call print_string
    
    popq %rbp
    ret

.section .data
    dash_o: .string "-o"