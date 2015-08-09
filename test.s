
; light threading

section .text
global _start
_start:
	; attempt to mmap stack space
	mov rax, 9 ; mmap
	mov rdi, 0
	mov rsi, mmap.size
	mov rdx, 0x3
	mov r10, 0x22
	mov r8, -1
	mov r9, 0
	syscall

	cmp rax, 0
	jle .mmap.err

	add rax, mmap.size
	mov rsp, rax
	mov rbp, rsp

	call Thread.routine

	mov rdi, 8
	call malloc

	mov rax, 60
	xor rdi, rdi
	syscall

.mmap.err:
	; write mmap error message
	mov rax, 1
	mov rdi, 1
	mov rsi, mmap.errmsg
	mov rdx, mmap.errmsg.len
	syscall

	; exit with err
	mov rdi, rax
	neg rdi
	mov rax, 60
	syscall

global Thread.routine
Thread.routine:
	; prologue
	push rbp
	mov rbp, rsp

	mov rax, 1
	mov rdi, 1
	mov rsi, msg
	mov rdx, msg.len
	syscall

	; epilogue
	pop rbp
	ret

; Uses stack space to create a string,
; prints that string
global printx
printx:
	push rbp
	mov rbp, rsp

	mov rdx, rdi
	mov rdi, rsp
.lp:
	; power of two divide
	mov rax, rdx
	and rax, 0xb ; % 8
	shr rdx, 4 ; >> 3
	; convert to letter, put on stack
	cmp rax, 9
	jg .hex
	lea rbx, [rax + '0']
	jmp .nohex
.hex:
	lea rbx, [rax + 'f']
.nohex:
	mov [rdi], bl
	inc rdi
	; if rdi is still not zero
	test rdx, rdx
	jnz .lp

	mov rax, 1
	mov rsi, rsp ; base ptr
	mov rdx, rdi
	sub rdx, rsp ; calculate len
	mov rdi, 1
.sys:
	syscall

	pop rbp
	ret

global malloc
malloc:
	push rbp
	mov rbp, rsp

	; rdi has size needed
	mov rbx, rdi
	mov rax, 0x7
	and rbx, rax ; align
	test rbx, rbx
	jz .noadd
	inc rdi
.noadd:
	add rdi, 0x10 ; room for header

	mov rax, freelist
.lp:
	; n != null
	test rax, rax
	jz .notfound
	mov rbx, [rax] ; first qword is size
	cmp rbx, rdi ; compare size
	jge .found
	; next element
	mov rax, [rax + 8] ; second qword is next ptr
	jmp .lp
.found:
	mov rax, rbx
	jmp .end
.end:
	pop rbp
	ret
.notfound:
	; allocate more memory
	; mmap's gonna take a sec, so we make
	; the find branch linear.
	; write mmap error message
	call printx ; rdi already set

	mov rax, 1
	mov rdi, 1
	mov rsi, malloc.errmsg
	mov rdx, malloc.errmsg.len
	syscall
	jmp .end

malloc.errmsg: db ": malloc didn't have any memory of that size", 10
malloc.errmsg.len: equ $-malloc.errmsg

mmap.size: dd 0x1000
mmap.errmsg: db "mmap returned an error", 10
mmap.errmsg.len: equ $-mmap.errmsg

msg: db "Hello, World!", 10
msg.len: equ $-msg

section .bss
freelist: resq 1
