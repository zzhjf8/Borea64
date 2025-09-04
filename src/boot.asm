org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A

start:
	jmp main

; Prints a string to the screen.
; Parameters: ds:si points to a string
puts:
	; Save registers we will modify
	push si
	push ax

.loop:
	lodsb		; Load next char in al
	or al, al	; Verify if next char is null
	jz .done

	mov ah, 0x0e	; Call BIOS interrupt
	int 0x10

	jmp .loop

.done:
	pop ax
	pop si
	ret

main:
	; Setup data segments
	mov ax, 0
	mov ds, ax	; Use ax since we can't write to ds/es directly
	mov es, ax

	; Setup stack
	mov ss, ax
	mov sp, 0x7C00	; Stack grows downwards

	; Print message
	mov si, BOOTMSG
	call puts

	hlt

.halt:
	jmp .halt

BOOTMSG: db "Bootloader: OK", ENDL, 0

times 510 - ($ - $$) db 0	; Pad with 0
dw 0xAA55			; Signature
