format ELF64 executable 3

;; constants
define sys$read         0
define sys$write        1
define sys$open         2
define sys$close        3
define sys$lseek        8
define sys$stat         4
define sys$fstat        5
define sys$access       21
define sys$creat        85
define sys$unlink       87
define sys$rename       82
define sys$chmod        90
define sys$mmap         9
define sys$munmap       11
define sys$mprotect     10
define sys$brk          12
define sys$exit         60
define sys$exit_group   231
define sys$fork         57
define sys$execve       59
define sys$wait4        61
define sys$ioctl        16
define sys$select       23
define sys$poll         7
define sys$signal       48
define sys$sigaction    13
define sys$sigprocmask  14
cls db 27, '[2J', 27, '[H'
clslen = $ - cls
define rdonly  0
define wronly  1
define rdwr    2
define creat   64
define trunc   512
define append  1024
define S_IRUSR   0400h
define S_IWUSR   0200h
define S_IRGRP   0040h
define S_IROTH   0004h
define stdin  0
define stdout 1
define stderr 2
define tcgets 0x5401
define tcsets 0x5402

segment readable executable
entry main

main:
    ; --- Save current terminal settings ---
    mov     rax, sys$ioctl
    mov     rdi, stdin
    mov     rsi, tcgets
    lea     rdx, [origtermios]
    syscall

    ; --- Copy orig_termios to new_termios ---
    lea     rsi, [origtermios]
    lea     rdi, [newtermios]
    mov     rcx, 64 / 8
copyloop:
    mov     rax, [rsi]
    mov     [rdi], rax
    add     rsi, 8
    add     rdi, 8
    loop    copyloop

    ; --- Modify c_lflag in new_termios ---
    ; c_lflag offset = 12
    lea     rdi, [newtermios + 12]
    mov     eax, [rdi]
    and     eax, not 0x0002          ; ~ICANON
    and     eax, not 0x0008          ; ~ECHO
    mov     [rdi], eax

    ; --- Apply modified termios ---
    mov     rax, sys$ioctl
    mov     rdi, stdin
    mov     rsi, tcsets
    lea     rdx, [newtermios]
    syscall

    ; --- Clear screen ---
    mov     rax, sys$write
    mov     rdi, stdout
    mov     rsi, cls
    mov     rdx, clslen
    syscall

    ; --- Print prompt ---
    mov     rax, sys$write
    mov     rdi, stdout
    mov     rsi, prompt
    mov     rdx, 1
    syscall

readloop:
    ; Read 1 byte
    mov     rax, sys$read
    mov     rdi, stdin
    lea     rsi, [inputbuf]
    mov     rdx, 1
    syscall

    ; Check for ESC key (0x1B)
    cmp     byte [inputbuf], 27
    jne     readloop$print_key

    ; Check esc_flag
    cmp     byte [escflag], 1
    je      input_done      ; double ESC

    ; Set esc_flag = 1
    mov     byte [escflag], 1

printesc:
    ; Print '$'
    mov     rax, sys$write
    mov     rdi, stdout
    mov     rsi, escsym
    mov     rdx, 1
    syscall

    jmp     readloop

readloop$print_key:
    ; Clear esc_flag
    mov     byte [escflag], 0

    ; Echo typed character
    mov     rax, sys$write
    mov     rdi, stdout
    lea     rsi, [inputbuf]
    mov     rdx, 1
    syscall

    jmp     readloop

input_done:
    call restore_terminal
    jmp exit

cmdhandler:
    

restore_terminal:
    mov     rax, sys$ioctl
    mov     rdi, stdin
    mov     rsi, tcsets
    lea     rdx, [origtermios]
    syscall
    ret

exit:
    mov     rax, sys$exit
    xor     rdi, rdi
    syscall

segment readable writeable
prompt db "*"
origtermios rb 64
newtermios rb 64
inputbuf rb 255
escsym db '$'
escflag db 0