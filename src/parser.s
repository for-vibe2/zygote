# Parser for C Compiler
# Written in x86_64 Assembly (AT&T syntax)
# Implements recursive descent parser for simple C subset

.section .data
    # AST Node types
    .global NODE_PROGRAM
    .global NODE_FUNCTION
    .global NODE_VARIABLE
    .global NODE_NUMBER
    .global NODE_BINARY_OP
    .global NODE_ASSIGNMENT
    .global NODE_RETURN
    .global NODE_IF
    .global NODE_WHILE
    .global NODE_BLOCK
    
    NODE_PROGRAM:     .quad 1
    NODE_FUNCTION:    .quad 2
    NODE_VARIABLE:    .quad 3
    NODE_NUMBER:      .quad 4
    NODE_BINARY_OP:   .quad 5
    NODE_ASSIGNMENT:  .quad 6
    NODE_RETURN:      .quad 7
    NODE_IF:          .quad 8
    NODE_WHILE:       .quad 9
    NODE_BLOCK:       .quad 10
    
    # Current token info
    current_token_type: .quad 0
    current_token_value: .quad 0
    
    # AST Node structure (simplified)
    # Each node: [type:8] [value_ptr:8] [left:8] [right:8] [next:8]
    ast_heap:         .space 8192    # Simple heap for AST nodes
    ast_heap_ptr:     .quad ast_heap
    
    # Symbol table (simplified)
    symbol_table:     .space 2048
    symbol_count:     .quad 0
    
    # Error messages
    parse_error_msg:  .string "Parse error: unexpected token\n"
    
.section .text
    .global parser_init
    .global parse_program
    .global parse_function
    .global parse_statement
    .global parse_expression
    .global expect_token
    .global advance_token
    .global create_node

# Initialize parser
parser_init:
    pushq %rbp
    movq %rsp, %rbp
    
    # Initialize lexer first
    call lexer_init
    
    # Get first token
    call get_next_token
    movq %rax, current_token_type
    movq %rdx, current_token_value
    
    # Reset AST heap pointer
    movq $ast_heap, %rax
    movq %rax, ast_heap_ptr
    
    popq %rbp
    ret

# Advance to next token
advance_token:
    pushq %rbp
    movq %rsp, %rbp
    
    call get_next_token
    movq %rax, current_token_type
    movq %rdx, current_token_value
    
    popq %rbp
    ret

# Expect specific token type
# Parameters: %rdi = expected token type
# Returns: %rax = 1 if match, 0 if not
expect_token:
    pushq %rbp
    movq %rsp, %rbp
    
    movq current_token_type, %rax
    cmpq %rdi, %rax
    je token_match
    
    # Token mismatch - error
    movq $0, %rax
    jmp expect_exit
    
token_match:
    call advance_token
    movq $1, %rax
    
expect_exit:
    popq %rbp
    ret

# Create new AST node
# Parameters: %rdi = node type, %rsi = value pointer
# Returns: %rax = pointer to new node
create_node:
    pushq %rbp
    movq %rsp, %rbp
    
    # Get current heap pointer
    movq ast_heap_ptr, %rax
    
    # Store node type
    movq %rdi, (%rax)
    
    # Store value pointer
    movq %rsi, 8(%rax)
    
    # Initialize other fields to 0
    movq $0, 16(%rax)     # left child
    movq $0, 24(%rax)     # right child
    movq $0, 32(%rax)     # next sibling
    
    # Advance heap pointer
    addq $40, %rax
    movq %rax, ast_heap_ptr
    
    # Return pointer to created node
    movq ast_heap_ptr, %rax
    subq $40, %rax
    
    popq %rbp
    ret

# Parse program (top level)
# Returns: %rax = pointer to program AST node
parse_program:
    pushq %rbp
    movq %rsp, %rbp
    subq $16, %rsp               # Local storage for program node and last child

    # Create program node
    movq NODE_PROGRAM, %rdi
    movq $0, %rsi
    call create_node
    movq %rax, -8(%rbp)          # Store program node
    movq $0, -16(%rbp)           # Last child = 0

    # Parse functions until EOF
parse_program_loop:
    movq current_token_type, %rax
    movq TOKEN_EOF, %rbx
    cmpq %rbx, %rax
    je parse_program_done

    # Parse function
    call parse_function
    cmpq $0, %rax
    je parse_program_error

    movq %rax, %rcx              # Function node pointer

    # Attach to program node list
    movq -16(%rbp), %rdx         # Last child
    cmpq $0, %rdx
    jne program_attach_existing

    # First child
    movq -8(%rbp), %rsi
    movq %rcx, 16(%rsi)
    movq %rcx, -16(%rbp)
    jmp parse_program_loop

program_attach_existing:
    movq %rcx, 32(%rdx)
    movq %rcx, -16(%rbp)
    jmp parse_program_loop

parse_program_error:
    movq $0, %rax
    jmp parse_program_exit

parse_program_done:
    movq -8(%rbp), %rax

parse_program_exit:
    movq %rbp, %rsp
    popq %rbp
    ret

# Parse function definition
# Returns: %rax = pointer to function AST node
parse_function:
    pushq %rbp
    movq %rsp, %rbp
    subq $16, %rsp               # Local storage for function name and node

    # Expect "int" keyword
    movq current_token_type, %rax
    movq TOKEN_KEYWORD, %rbx
    cmpq %rbx, %rax
    jne parse_function_error

    movq current_token_value, %rdi
    movq $int_keyword, %rsi
    call strcmp_simple
    cmpq $1, %rax
    jne parse_function_error

    call advance_token

    # Expect function name (identifier)
    movq current_token_type, %rax
    movq TOKEN_IDENTIFIER, %rbx
    cmpq %rbx, %rax
    jne parse_function_error

    movq current_token_value, %rax
    movq %rax, -8(%rbp)          # Store identifier pointer
    call advance_token

    # Expect '('
    movq current_token_type, %rax
    movq TOKEN_DELIMITER, %rbx
    cmpq %rbx, %rax
    jne parse_function_error
    movq current_token_value, %rdi
    movb (%rdi), %al
    cmpb $'(', %al
    jne parse_function_error
    call advance_token

    # Expect ')'
    movq current_token_type, %rax
    movq TOKEN_DELIMITER, %rbx
    cmpq %rbx, %rax
    jne parse_function_error
    movq current_token_value, %rdi
    movb (%rdi), %al
    cmpb $')', %al
    jne parse_function_error
    call advance_token

    # Create function node
    movq NODE_FUNCTION, %rdi
    movq -8(%rbp), %rsi
    call create_node
    movq %rax, -16(%rbp)         # Store function node

    # Parse function body (block statement)
    call parse_statement
    cmpq $0, %rax
    je parse_function_error

    movq -16(%rbp), %rbx
    movq %rax, 16(%rbx)          # Body as left child
    movq %rbx, %rax
    jmp parse_function_exit

parse_function_error:
    movq $0, %rax

parse_function_exit:
    movq %rbp, %rsp
    popq %rbp
    ret

# Parse statement
# Returns: %rax = pointer to statement AST node
parse_statement:
    pushq %rbp
    movq %rsp, %rbp

    movq current_token_type, %rax

    # Check for block statement '{'
    movq TOKEN_DELIMITER, %rbx
    cmpq %rbx, %rax
    jne check_keyword_statement

    movq current_token_value, %rdi
    movb (%rdi), %al
    cmpb $'{', %al
    jne check_keyword_statement

    call parse_block
    jmp parse_statement_exit

check_keyword_statement:
    movq current_token_type, %rax
    movq TOKEN_KEYWORD, %rbx
    cmpq %rbx, %rax
    jne expression_statement

    # Determine which keyword
    movq current_token_value, %rdi
    movq $return_keyword, %rsi
    call strcmp_simple
    cmpq $1, %rax
    jne check_if_keyword

    call parse_return
    jmp parse_statement_exit

check_if_keyword:
    movq current_token_value, %rdi
    movq $if_keyword, %rsi
    call strcmp_simple
    cmpq $1, %rax
    jne check_int_keyword

    call parse_if
    jmp parse_statement_exit

check_int_keyword:
    movq current_token_value, %rdi
    movq $int_keyword, %rsi
    call strcmp_simple
    cmpq $1, %rax
    jne statement_error

    call parse_variable_declaration
    jmp parse_statement_exit

expression_statement:
    call parse_expression
    cmpq $0, %rax
    je statement_error

    pushq %rax

    # Expect semicolon
    movq current_token_type, %rbx
    movq TOKEN_DELIMITER, %rcx
    cmpq %rcx, %rbx
    jne statement_error_restore
    movq current_token_value, %rdi
    movb (%rdi), %al
    cmpb $';', %al
    jne statement_error_restore
    call advance_token

    popq %rax
    jmp parse_statement_exit

statement_error_restore:
    popq %rax

statement_error:
    movq $0, %rax

parse_statement_exit:
    movq %rbp, %rsp
    popq %rbp
    ret

# Parse block statement
# Returns: %rax = pointer to block AST node
parse_block:
    pushq %rbp
    movq %rsp, %rbp
    subq $24, %rsp

    # Expect '{'
    movq current_token_type, %rax
    movq TOKEN_DELIMITER, %rbx
    cmpq %rbx, %rax
    jne parse_block_error
    movq current_token_value, %rdi
    movb (%rdi), %al
    cmpb $'{', %al
    jne parse_block_error
    call advance_token

    # Create block node
    movq NODE_BLOCK, %rdi
    movq $0, %rsi
    call create_node
    movq %rax, -8(%rbp)
    movq $0, -16(%rbp)          # Last statement

    # Parse statements until '}'
parse_block_loop:
    movq current_token_type, %rax
    movq TOKEN_DELIMITER, %rbx
    cmpq %rbx, %rax
    jne parse_block_statement

    movq current_token_value, %rdi
    movb (%rdi), %al
    cmpb $'}', %al
    je parse_block_done

parse_block_statement:
    call parse_statement
    cmpq $0, %rax
    je parse_block_error

    movq %rax, %rcx
    movq -16(%rbp), %rdx
    cmpq $0, %rdx
    jne block_attach_existing

    movq -8(%rbp), %rsi
    movq %rcx, 16(%rsi)
    movq %rcx, -16(%rbp)
    jmp parse_block_loop

block_attach_existing:
    movq %rcx, 32(%rdx)
    movq %rcx, -16(%rbp)
    jmp parse_block_loop

parse_block_done:
    call advance_token
    movq -8(%rbp), %rax
    jmp parse_block_exit

parse_block_error:
    movq $0, %rax

parse_block_exit:
    movq %rbp, %rsp
    popq %rbp
    ret

# Parse return statement
# Returns: %rax = pointer to return AST node
parse_return:
    pushq %rbp
    movq %rsp, %rbp

    # Advance past "return" keyword
    call advance_token

    # Parse expression
    call parse_expression
    cmpq $0, %rax
    je parse_return_error
    pushq %rax               # Save expression node

    # Create return node
    movq NODE_RETURN, %rdi
    movq $0, %rsi
    call create_node

    popq %rbx               # Restore expression node
    movq %rbx, 16(%rax)     # Set expression as left child
    pushq %rax               # Save return node

    # Expect semicolon
    movq current_token_type, %rbx
    movq TOKEN_DELIMITER, %rcx
    cmpq %rcx, %rbx
    jne parse_return_error_restore
    movq current_token_value, %rdi
    movb (%rdi), %al
    cmpb $';', %al
    jne parse_return_error_restore
    call advance_token

    popq %rax
    jmp parse_return_exit

parse_return_error_restore:
    popq %rax

parse_return_error:
    movq $0, %rax

parse_return_exit:
    movq %rbp, %rsp
    popq %rbp
    ret

# Parse variable declaration
# Returns: %rax = pointer to variable AST node
parse_variable_declaration:
    pushq %rbp
    movq %rsp, %rbp
    subq $16, %rsp

    # Advance past "int" keyword
    call advance_token

    # Expect identifier
    movq current_token_type, %rax
    movq TOKEN_IDENTIFIER, %rbx
    cmpq %rbx, %rax
    jne parse_var_error

    movq current_token_value, %rax
    movq %rax, -8(%rbp)
    call advance_token

    # Create variable node
    movq NODE_VARIABLE, %rdi
    movq -8(%rbp), %rsi
    call create_node
    movq %rax, -16(%rbp)

    # Expect semicolon
    movq current_token_type, %rbx
    movq TOKEN_DELIMITER, %rcx
    cmpq %rcx, %rbx
    jne parse_var_error
    movq current_token_value, %rdi
    movb (%rdi), %al
    cmpb $';', %al
    jne parse_var_error
    call advance_token

    movq -16(%rbp), %rax
    jmp parse_var_exit

parse_var_error:
    movq $0, %rax

parse_var_exit:
    movq %rbp, %rsp
    popq %rbp
    ret

# Parse expression (simplified - just numbers for now)
# Returns: %rax = pointer to expression AST node
parse_expression:
    pushq %rbp
    movq %rsp, %rbp

    call parse_assignment

    movq %rbp, %rsp
    popq %rbp
    ret

# Parse assignment expressions (right associative)
parse_assignment:
    pushq %rbp
    movq %rsp, %rbp

    call parse_relational
    movq %rax, %rbx               # Left expression
    cmpq $0, %rax
    je parse_assignment_exit

    movq current_token_type, %rcx
    movq TOKEN_OPERATOR, %rdx
    cmpq %rdx, %rcx
    jne parse_assignment_noop

    movq current_token_value, %rdi
    movb (%rdi), %al
    cmpb $'=', %al
    jne parse_assignment_noop

    call advance_token

    pushq %rbx
    call parse_assignment
    cmpq $0, %rax
    je parse_assignment_error
    movq %rax, %rcx               # Right expression
    popq %rbx

    movq NODE_ASSIGNMENT, %rdi
    movq $assign_operator, %rsi
    call create_node
    movq %rbx, 16(%rax)
    movq %rcx, 24(%rax)
    jmp parse_assignment_exit

parse_assignment_noop:
    movq %rbx, %rax
    jmp parse_assignment_exit

parse_assignment_error:
    popq %rbx
    movq $0, %rax

parse_assignment_exit:
    movq %rbp, %rsp
    popq %rbp
    ret

# Parse relational expressions
parse_relational:
    pushq %rbp
    movq %rsp, %rbp

    call parse_additive
    movq %rax, %rbx
    cmpq $0, %rax
    je parse_relational_exit

parse_relational_loop:
    movq current_token_type, %rcx
    movq TOKEN_OPERATOR, %rdx
    cmpq %rdx, %rcx
    jne parse_relational_done

    movq current_token_value, %rdi
    movb (%rdi), %al
    cmpb $'>', %al
    je parse_relational_gt
    cmpb $'<', %al
    je parse_relational_lt
    jmp parse_relational_done

parse_relational_gt:
    call advance_token
    pushq %rbx
    call parse_additive
    cmpq $0, %rax
    je parse_relational_error_pop
    movq %rax, %rcx
    popq %rbx
    movq NODE_BINARY_OP, %rdi
    movq $gt_operator, %rsi
    call create_node
    movq %rbx, 16(%rax)
    movq %rcx, 24(%rax)
    movq %rax, %rbx
    jmp parse_relational_loop

parse_relational_lt:
    call advance_token
    pushq %rbx
    call parse_additive
    cmpq $0, %rax
    je parse_relational_error_pop
    movq %rax, %rcx
    popq %rbx
    movq NODE_BINARY_OP, %rdi
    movq $lt_operator, %rsi
    call create_node
    movq %rbx, 16(%rax)
    movq %rcx, 24(%rax)
    movq %rax, %rbx
    jmp parse_relational_loop

parse_relational_error_pop:
    popq %rbx

parse_relational_error:
    movq $0, %rax
    jmp parse_relational_exit

parse_relational_done:
    movq %rbx, %rax

parse_relational_exit:
    movq %rbp, %rsp
    popq %rbp
    ret

# Parse additive expressions
parse_additive:
    pushq %rbp
    movq %rsp, %rbp

    call parse_term
    movq %rax, %rbx
    cmpq $0, %rax
    je parse_additive_exit

parse_additive_loop:
    movq current_token_type, %rcx
    movq TOKEN_OPERATOR, %rdx
    cmpq %rdx, %rcx
    jne parse_additive_done

    movq current_token_value, %rdi
    movb (%rdi), %al
    cmpb $'+', %al
    je parse_additive_plus
    cmpb $'-', %al
    je parse_additive_minus
    jmp parse_additive_done

parse_additive_plus:
    call advance_token
    pushq %rbx
    call parse_term
    cmpq $0, %rax
    je parse_additive_error_pop
    movq %rax, %rcx
    popq %rbx
    movq NODE_BINARY_OP, %rdi
    movq $plus_operator, %rsi
    call create_node
    movq %rbx, 16(%rax)
    movq %rcx, 24(%rax)
    movq %rax, %rbx
    jmp parse_additive_loop

parse_additive_minus:
    call advance_token
    pushq %rbx
    call parse_term
    cmpq $0, %rax
    je parse_additive_error_pop
    movq %rax, %rcx
    popq %rbx
    movq NODE_BINARY_OP, %rdi
    movq $minus_operator, %rsi
    call create_node
    movq %rbx, 16(%rax)
    movq %rcx, 24(%rax)
    movq %rax, %rbx
    jmp parse_additive_loop

parse_additive_error_pop:
    popq %rbx

parse_additive_error:
    movq $0, %rax
    jmp parse_additive_exit

parse_additive_done:
    movq %rbx, %rax

parse_additive_exit:
    movq %rbp, %rsp
    popq %rbp
    ret

# Parse term expressions (multiplication/division)
parse_term:
    pushq %rbp
    movq %rsp, %rbp

    call parse_factor
    movq %rax, %rbx
    cmpq $0, %rax
    je parse_term_exit

parse_term_loop:
    movq current_token_type, %rcx
    movq TOKEN_OPERATOR, %rdx
    cmpq %rdx, %rcx
    jne parse_term_done

    movq current_token_value, %rdi
    movb (%rdi), %al
    cmpb $'*', %al
    je parse_term_mul
    cmpb $'/', %al
    je parse_term_div
    jmp parse_term_done

parse_term_mul:
    call advance_token
    pushq %rbx
    call parse_factor
    cmpq $0, %rax
    je parse_term_error_pop
    movq %rax, %rcx
    popq %rbx
    movq NODE_BINARY_OP, %rdi
    movq $mul_operator, %rsi
    call create_node
    movq %rbx, 16(%rax)
    movq %rcx, 24(%rax)
    movq %rax, %rbx
    jmp parse_term_loop

parse_term_div:
    call advance_token
    pushq %rbx
    call parse_factor
    cmpq $0, %rax
    je parse_term_error_pop
    movq %rax, %rcx
    popq %rbx
    movq NODE_BINARY_OP, %rdi
    movq $div_operator, %rsi
    call create_node
    movq %rbx, 16(%rax)
    movq %rcx, 24(%rax)
    movq %rax, %rbx
    jmp parse_term_loop

parse_term_error_pop:
    popq %rbx

parse_term_error:
    movq $0, %rax
    jmp parse_term_exit

parse_term_done:
    movq %rbx, %rax

parse_term_exit:
    movq %rbp, %rsp
    popq %rbp
    ret

# Parse factor (primary expressions with parentheses)
parse_factor:
    pushq %rbp
    movq %rsp, %rbp

    movq current_token_type, %rax
    movq TOKEN_DELIMITER, %rbx
    cmpq %rbx, %rax
    jne parse_factor_primary

    movq current_token_value, %rdi
    movb (%rdi), %al
    cmpb $'(', %al
    jne parse_factor_primary

    call advance_token
    call parse_expression
    cmpq $0, %rax
    je parse_factor_error
    pushq %rax

    movq current_token_type, %rbx
    movq TOKEN_DELIMITER, %rcx
    cmpq %rcx, %rbx
    jne parse_factor_error_restore
    movq current_token_value, %rdi
    movb (%rdi), %al
    cmpb $')', %al
    jne parse_factor_error_restore
    call advance_token

    popq %rax
    jmp parse_factor_exit

parse_factor_error_restore:
    popq %rax

parse_factor_error:
    movq $0, %rax
    jmp parse_factor_exit

parse_factor_primary:
    call parse_primary

parse_factor_exit:
    movq %rbp, %rsp
    popq %rbp
    ret

# Parse primary expression
# Returns: %rax = pointer to primary AST node
parse_primary:
    pushq %rbp
    movq %rsp, %rbp

    movq current_token_type, %rax

    # Check for number
    movq TOKEN_NUMBER, %rbx
    cmpq %rbx, %rax
    jne check_identifier_expr

    movq NODE_NUMBER, %rdi
    movq current_token_value, %rsi
    call create_node
    call advance_token
    jmp parse_primary_exit

check_identifier_expr:
    movq TOKEN_IDENTIFIER, %rbx
    cmpq %rbx, %rax
    jne parse_primary_error

    movq NODE_VARIABLE, %rdi
    movq current_token_value, %rsi
    call create_node
    call advance_token
    jmp parse_primary_exit

parse_primary_error:
    movq $0, %rax

parse_primary_exit:
    movq %rbp, %rsp
    popq %rbp
    ret

# Parse if statement
parse_if:
    pushq %rbp
    movq %rsp, %rbp
    subq $32, %rsp

    # Consume 'if'
    call advance_token

    movq $0, -24(%rbp)

    # Expect '('
    movq current_token_type, %rax
    movq TOKEN_DELIMITER, %rbx
    cmpq %rbx, %rax
    jne parse_if_error
    movq current_token_value, %rdi
    movb (%rdi), %al
    cmpb $'(', %al
    jne parse_if_error
    call advance_token

    # Parse condition
    call parse_expression
    cmpq $0, %rax
    je parse_if_error
    movq %rax, -8(%rbp)

    # Expect ')'
    movq current_token_type, %rax
    movq TOKEN_DELIMITER, %rbx
    cmpq %rbx, %rax
    jne parse_if_error
    movq current_token_value, %rdi
    movb (%rdi), %al
    cmpb $')', %al
    jne parse_if_error
    call advance_token

    # Parse then branch
    call parse_statement
    cmpq $0, %rax
    je parse_if_error
    movq %rax, -16(%rbp)

    # Check for optional else
    movq current_token_type, %rax
    movq TOKEN_KEYWORD, %rbx
    cmpq %rbx, %rax
    jne parse_if_create

    movq current_token_value, %rdi
    movq $else_keyword, %rsi
    call strcmp_simple
    cmpq $1, %rax
    jne parse_if_create

    call advance_token
    call parse_statement
    cmpq $0, %rax
    je parse_if_error
    movq %rax, -24(%rbp)

parse_if_create:
    movq NODE_IF, %rdi
    movq $0, %rsi
    call create_node
    movq -8(%rbp), %rbx
    movq %rbx, 16(%rax)
    movq -16(%rbp), %rbx
    movq %rbx, 24(%rax)
    movq -24(%rbp), %rbx
    movq %rbx, 8(%rax)          # Else branch stored in value field
    jmp parse_if_exit

parse_if_error:
    movq $0, %rax

parse_if_exit:
    movq %rbp, %rsp
    popq %rbp
    ret

.section .data
    return_keyword: .string "return"
    int_keyword:    .string "int"
    if_keyword:     .string "if"
    else_keyword:   .string "else"

    assign_operator: .string "="
    plus_operator:   .string "+"
    minus_operator:  .string "-"
    mul_operator:    .string "*"
    div_operator:    .string "/"
    gt_operator:     .string ">"
    lt_operator:     .string "<"
