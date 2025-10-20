# Lexical Analyzer for C Compiler
# Written in x86_64 Assembly (AT&T syntax)

.section .data
    # Token types
    .global TOKEN_NUMBER
    .global TOKEN_IDENTIFIER
    .global TOKEN_KEYWORD
    .global TOKEN_OPERATOR
    .global TOKEN_DELIMITER
    .global TOKEN_EOF
    
    TOKEN_NUMBER:    .quad 1
    TOKEN_IDENTIFIER: .quad 2
    TOKEN_KEYWORD:   .quad 3
    TOKEN_OPERATOR:  .quad 4
    TOKEN_DELIMITER: .quad 5
    TOKEN_EOF:       .quad 6
    
    # Keywords
    keywords:
        .string "int"
        .string "return"
        .string "if"
        .string "else"
        .string "while"
        .string "for"
        .string ""          # End marker
    
    # Current character and position
    current_char:    .byte 0
    current_pos:     .quad 0
    input_buffer:    .space 4096  # Input buffer
    token_buffer:    .space 256   # Current token buffer
    
    # Error messages
    err_invalid_char: .string "Error: Invalid character\n"
    
.section .text
    .global lexer_init
    .global get_next_token
    .global skip_whitespace
    .global read_number
    .global read_identifier
    .global is_keyword
    .global strcmp_simple

# Initialize lexer with input buffer
# Parameters: %rdi = pointer to input string
lexer_init:
    pushq %rbp
    movq %rsp, %rbp
    
    # Copy input to our buffer
    movq %rdi, %rsi          # Source
    movq $input_buffer, %rdi # Destination
    movq $4095, %rcx         # Max copy size
    rep movsb                # Copy string
    
    # Reset position
    movq $0, current_pos
    
    # Load first character
    movq $input_buffer, %rax
    movb (%rax), %bl
    movb %bl, current_char
    
    popq %rbp
    ret

# Skip whitespace characters
skip_whitespace:
    pushq %rbp
    movq %rsp, %rbp
    
skip_loop:
    movb current_char, %al
    cmpb $32, %al           # Space
    je skip_char
    cmpb $9, %al            # Tab
    je skip_char
    cmpb $10, %al           # Newline
    je skip_char
    cmpb $13, %al           # Carriage return
    je skip_char
    jmp skip_done
    
skip_char:
    # Advance to next character
    incq current_pos
    movq current_pos, %rax
    movq $input_buffer, %rbx
    addq %rax, %rbx
    movb (%rbx), %al
    movb %al, current_char
    jmp skip_loop
    
skip_done:
    popq %rbp
    ret

# Read a number token
# Returns: %rax = token type, %rdx = pointer to token string
read_number:
    pushq %rbp
    movq %rsp, %rbp
    
    movq $token_buffer, %rdi  # Token buffer pointer
    movq $0, %rcx             # Token length
    
read_digit_loop:
    movb current_char, %al
    cmpb $48, %al             # '0'
    jl read_number_done
    cmpb $57, %al             # '9'
    jg read_number_done
    
    # Store digit in token buffer
    movb %al, (%rdi, %rcx)
    incq %rcx
    
    # Advance to next character
    incq current_pos
    movq current_pos, %rax
    movq $input_buffer, %rbx
    addq %rax, %rbx
    movb (%rbx), %al
    movb %al, current_char
    
    jmp read_digit_loop
    
read_number_done:
    # Null terminate token
    movb $0, (%rdi, %rcx)
    
    # Return token type and pointer
    movq TOKEN_NUMBER, %rax
    movq $token_buffer, %rdx
    
    popq %rbp
    ret

# Read an identifier or keyword
# Returns: %rax = token type, %rdx = pointer to token string  
read_identifier:
    pushq %rbp
    movq %rsp, %rbp
    
    movq $token_buffer, %rdi  # Token buffer pointer
    movq $0, %rcx             # Token length
    
read_id_loop:
    movb current_char, %al
    
    # Check if alphanumeric or underscore
    cmpb $95, %al             # '_'
    je store_char
    cmpb $65, %al             # 'A'
    jl check_digit
    cmpb $90, %al             # 'Z'
    jle store_char
    cmpb $97, %al             # 'a'
    jl check_digit
    cmpb $122, %al            # 'z'
    jle store_char
    
check_digit:
    cmpb $48, %al             # '0'
    jl read_id_done
    cmpb $57, %al             # '9'
    jg read_id_done
    
store_char:
    # Store character in token buffer
    movb %al, (%rdi, %rcx)
    incq %rcx
    
    # Advance to next character
    incq current_pos
    movq current_pos, %rax
    movq $input_buffer, %rbx
    addq %rax, %rbx
    movb (%rbx), %al
    movb %al, current_char
    
    jmp read_id_loop
    
read_id_done:
    # Null terminate token
    movb $0, (%rdi, %rcx)
    
    # Check if it's a keyword
    call is_keyword
    cmpq $1, %rax
    je return_keyword
    
    # Return as identifier
    movq TOKEN_IDENTIFIER, %rax
    movq $token_buffer, %rdx
    jmp read_id_exit
    
return_keyword:
    movq TOKEN_KEYWORD, %rax
    movq $token_buffer, %rdx
    
read_id_exit:
    popq %rbp
    ret

# Check if current token is a keyword
# Returns: %rax = 1 if keyword, 0 if not
is_keyword:
    pushq %rbp
    movq %rsp, %rbp
    
    movq $keywords, %rsi      # Keywords list
    
keyword_loop:
    # Check if we reached end of keywords
    movb (%rsi), %al
    cmpb $0, %al
    je not_keyword
    
    # Compare strings
    movq $token_buffer, %rdi
    call strcmp_simple
    cmpq $1, %rax
    je is_keyword_found
    
    # Move to next keyword
keyword_next:
    movb (%rsi), %al
    incq %rsi
    cmpb $0, %al
    jne keyword_next
    jmp keyword_loop
    
is_keyword_found:
    movq $1, %rax
    jmp is_keyword_exit
    
not_keyword:
    movq $0, %rax
    
is_keyword_exit:
    popq %rbp
    ret

# Simple string comparison
# Parameters: %rdi = string1, %rsi = string2
# Returns: %rax = 1 if equal, 0 if not
strcmp_simple:
    pushq %rbp
    movq %rsp, %rbp
    
strcmp_loop:
    movb (%rdi), %al
    movb (%rsi), %bl
    cmpb %bl, %al
    jne strcmp_not_equal
    
    # Check if we reached end of both strings
    cmpb $0, %al
    je strcmp_equal
    
    incq %rdi
    incq %rsi
    jmp strcmp_loop
    
strcmp_equal:
    movq $1, %rax
    jmp strcmp_exit
    
strcmp_not_equal:
    movq $0, %rax
    
strcmp_exit:
    popq %rbp
    ret

# Get next token from input
# Returns: %rax = token type, %rdx = pointer to token string
get_next_token:
    pushq %rbp
    movq %rsp, %rbp
    
    # Skip whitespace
    call skip_whitespace
    
    # Check for end of input
    movb current_char, %al
    cmpb $0, %al
    je return_eof
    
    # Check for numbers
    cmpb $48, %al             # '0'
    jl check_identifier
    cmpb $57, %al             # '9'
    jg check_identifier
    call read_number
    jmp get_token_exit
    
check_identifier:
    # Check for letters or underscore
    cmpb $95, %al             # '_'
    je read_id
    cmpb $65, %al             # 'A'
    jl check_operators
    cmpb $90, %al             # 'Z'
    jle read_id
    cmpb $97, %al             # 'a'
    jl check_operators
    cmpb $122, %al            # 'z'
    jle read_id
    jmp check_operators
    
read_id:
    call read_identifier
    jmp get_token_exit
    
check_operators:
    # Handle single character operators/delimiters
    movq $token_buffer, %rdi
    movb %al, (%rdi)
    movb $0, 1(%rdi)
    
    # Advance position
    incq current_pos
    movq current_pos, %rbx
    movq $input_buffer, %rcx
    addq %rbx, %rcx
    movb (%rcx), %bl
    movb %bl, current_char
    
    # Determine token type based on character
    cmpb $40, %al             # '('
    je return_delimiter
    cmpb $41, %al             # ')'
    je return_delimiter
    cmpb $123, %al            # '{'
    je return_delimiter
    cmpb $125, %al            # '}'
    je return_delimiter
    cmpb $59, %al             # ';'
    je return_delimiter
    
    # Default to operator
    movq TOKEN_OPERATOR, %rax
    movq $token_buffer, %rdx
    jmp get_token_exit
    
return_delimiter:
    movq TOKEN_DELIMITER, %rax
    movq $token_buffer, %rdx
    jmp get_token_exit
    
return_eof:
    movq TOKEN_EOF, %rax
    movq $0, %rdx
    
get_token_exit:
    popq %rbp
    ret