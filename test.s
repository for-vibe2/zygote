.section .text
.globl _start
_start:
	call main
	movq %rax, %rdi
	movq $60, %rax
	syscall

.globl main
main:
	pushq %rbp
	movq %rsp, %rbp
	movq $, %rax
	popq %rbp
	ret
