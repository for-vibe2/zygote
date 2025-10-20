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
    
    # Create program node
    movq NODE_PROGRAM, %rdi
    movq $0, %rsi
    call create_node
    pushq %rax               # Save program node
    
    # Parse functions until EOF
parse_program_loop:
    movq current_token_type, %rax
    movq TOKEN_EOF, %rbx
    cmpq %rbx, %rax
    je parse_program_done
    
    # Parse function
    call parse_function
    # TODO: Add function to program's child list
    
    jmp parse_program_loop
    
parse_program_done:
    popq %rax               # Restore program node
    
    popq %rbp
    ret

# Parse function definition
# Returns: %rax = pointer to function AST node
parse_function:
    pushq %rbp
    movq %rsp, %rbp
    
    # Expect "int" keyword
    movq TOKEN_KEYWORD, %rdi
    call expect_token
    cmpq $0, %rax
    je parse_function_error
    
    # Expect function name (identifier)
    movq TOKEN_IDENTIFIER, %rdi
    call expect_token
    cmpq $0, %rax
    je parse_function_error
    
    # Create function node
    movq NODE_FUNCTION, %rdi
    movq current_token_value, %rsi
    call create_node
    pushq %rax               # Save function node
    
    # Expect '('
    movq TOKEN_DELIMITER, %rdi
    call expect_token
    cmpq $0, %rax
    je parse_function_error
    
    # For now, skip parameter parsing
    # Expect ')'
    movq TOKEN_DELIMITER, %rdi
    call expect_token
    cmpq $0, %rax
    je parse_function_error
    
    # Parse function body (block statement)
    call parse_statement
    
    popq %rbx               # Restore function node
    movq %rax, 16(%rbx)     # Set body as left child
    movq %rbx, %rax         # Return function node
    
    jmp parse_function_exit
    
parse_function_error:
    movq $0, %rax
    
parse_function_exit:
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
    jne check_return
    
    # Parse block
    call parse_block
    jmp parse_statement_exit
    
check_return:
    # Check for return statement
    movq TOKEN_KEYWORD, %rbx
    cmpq %rbx, %rax
    jne check_variable
    
    # Check if keyword is "return"
    movq current_token_value, %rdi
    movq $return_keyword, %rsi
    call strcmp_simple
    cmpq $1, %rax
    jne check_variable
    
    # Parse return statement
    call parse_return
    jmp parse_statement_exit
    
check_variable:
    # Check for variable declaration (int identifier)
    movq TOKEN_KEYWORD, %rbx
    cmpq %rbx, %rax
    jne check_expression
    
    # Parse variable declaration
    call parse_variable_declaration
    jmp parse_statement_exit
    
check_expression:
    # Default to expression statement
    call parse_expression
    
    # Expect semicolon
    movq TOKEN_DELIMITER, %rdi
    call expect_token
    
parse_statement_exit:
    popq %rbp
    ret

# Parse block statement
# Returns: %rax = pointer to block AST node
parse_block:
    pushq %rbp
    movq %rsp, %rbp
    
    # Expect '{'
    movq TOKEN_DELIMITER, %rdi
    call expect_token
    cmpq $0, %rax
    je parse_block_error
    
    # Create block node
    movq NODE_BLOCK, %rdi
    movq $0, %rsi
    call create_node
    pushq %rax               # Save block node
    
    # Parse statements until '}'
parse_block_loop:
    movq current_token_type, %rax
    movq TOKEN_DELIMITER, %rbx
    cmpq %rbx, %rax
    jne parse_block_statement
    
    # Check if it's closing brace
    movq current_token_value, %rdi
    movb (%rdi), %al
    cmpb $125, %al          # '}'
    je parse_block_done
    
parse_block_statement:
    call parse_statement
    # TODO: Add statement to block's statement list
    jmp parse_block_loop
    
parse_block_done:
    # Expect '}'
    movq TOKEN_DELIMITER, %rdi
    call expect_token
    
    popq %rax               # Restore block node
    jmp parse_block_exit
    
parse_block_error:
    movq $0, %rax
    
parse_block_exit:
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
    pushq %rax               # Save expression node
    
    # Create return node
    movq NODE_RETURN, %rdi
    movq $0, %rsi
    call create_node
    
    popq %rbx               # Restore expression node
    movq %rbx, 16(%rax)     # Set expression as left child
    
    # Expect semicolon
    movq TOKEN_DELIMITER, %rdi
    call expect_token
    
    popq %rbp
    ret

# Parse variable declaration
# Returns: %rax = pointer to variable AST node
parse_variable_declaration:
    pushq %rbp
    movq %rsp, %rbp
    
    # Advance past "int" keyword
    call advance_token
    
    # Expect identifier
    movq TOKEN_IDENTIFIER, %rdi
    call expect_token
    cmpq $0, %rax
    je parse_var_error
    
    # Create variable node
    movq NODE_VARIABLE, %rdi
    movq current_token_value, %rsi
    call create_node
    
    # Expect semicolon
    movq TOKEN_DELIMITER, %rdi
    call expect_token
    
    jmp parse_var_exit
    
parse_var_error:
    movq $0, %rax
    
parse_var_exit:
    popq %rbp
    ret

# Parse expression (simplified - just numbers for now)
# Returns: %rax = pointer to expression AST node
parse_expression:
    pushq %rbp
    movq %rsp, %rbp
    
    call parse_primary
    
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
    
    # Create number node
    movq NODE_NUMBER, %rdi
    movq current_token_value, %rsi
    call create_node
    
    call advance_token
    jmp parse_primary_exit
    
check_identifier_expr:
    # Check for identifier
    movq TOKEN_IDENTIFIER, %rbx
    cmpq %rbx, %rax
    jne parse_primary_error
    
    # Create variable reference node
    movq NODE_VARIABLE, %rdi
    movq current_token_value, %rsi
    call create_node
    
    call advance_token
    jmp parse_primary_exit
    
parse_primary_error:
    movq $0, %rax
    
parse_primary_exit:
    popq %rbp
    ret

.section .data
    return_keyword: .string "return"