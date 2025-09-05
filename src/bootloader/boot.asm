org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A

; FAT12 header
jmp short start
nop

oem:		db 'BOREAx64'	; 8 bytes
bytes_per_sect:	dw 512		; Bytes per sector
sect_per_clust: db 1		; Sectors per cluster
reserved_sect:	dw 1		; Reserved sectors
fat_count:	db 2		; Num of file allocation tables on the storage media
dir_count:	dw 0E0h		; Number of directory entries
total_sects:	dw 2880		; 2880 * 512 = 1.44MB
desc_type:	db 0F0h		; 3.5" Floppy
sect_per_fat:	dw 9		; 9 Sectors per FAT
sect_per_track:	dw 18		; Sectors per track
heads:		dw 2		; Number of heads on storage media
hidden_sects:	dd 0		; Number of hidden sectors
large_sect:	dd 0		; Large sector count

; Extended boot record
ebr_drive_num:		db 0			; 0x00: floppy, 0x80: HDD
			db 0			; Reserved
ebr_signature:		db 29h
ebr_volume_id:		db 12h, 34h, 56h, 78h	; Serial number, value doesn't matter
ebr_volume_label:	db 'BOREA64__OS'	; 11 bytes
ebr_system_id:		db 'FAT12   '		; 8 bytes

; Code start
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

	; Read something from floppy
	; BIOS should set DL to drive number
	mov [ebr_drive_num], dl

	mov ax, 1		; LBA=1, Second sector from disk
	mov cl, 1		; 1 Sector to read
	mov bx, 0x7E00		; Data should be after the bootloader
	call disk_read

	; Print message
	mov si, BOOTMSG
	call puts
	
	cli
	hlt

; Error handlers
floppy_error:
	mov si, READFAIL
	call puts
	jmp wait_key_and_reboot

wait_key_and_reboot:
	mov ah, 0
	int 16h		; Wait for keypress
	jmp 0FFFFh:0	; Jump to BIOS start, should reboot

.halt:
	cli	; Disable interrupts
	jmp .halt

; Disk routines

; Converts an LBA address to a CHS address
; Parameters: ax: LBA address
; Returns: 
; - cx [bits 0-5]:	sector number
; - cx [bits 6-15]:	cylinder
; - dh:			head

lba_to_chs:
	push ax
	push dx

	xor dx, dx			; dx = 0
	div word [sect_per_track]	; ax = LBA / Sectors per track
					; dx = LBA % Sectors per track
	inc dx				; dx = (LBA % Sectors per track + 1) = sector
	mov cx, dx			; cx = sector

	xor dx, dx			; dx = 0
	div word [heads]		; ax = (LBA / Sectors per track) / Heads = cylinder
					; dx = (LBA / Sectors per track) % Heads = head
	mov dh, dl			; dh = head
	mov ch, al			; ch = cylinder (lower 8 bits)
	shl ah, 6
	or cl, ah			; Put upper 2 bits of cylinder in CL

	pop ax
	mov dl, al			; Restore DL
	pop ax
	ret

; Reads sectors from a disk
; Parameters: 
; - ax:		LBA Address
; - cl:		Number of sectors to read (up to 128)
; - dl:		Drive number
; - es:bx:	Memory address where to store read data
disk_read:
	push ax		; Save registers we will modify
	push bx
	push cx
	push dx
	push di

	push cx			; Temporarily save CL (number of sectors to read)
	call lba_to_chs		; Compute CHS
	pop ax			; AL = number of sectors to read

	mov ah, 02h
	mov di, 3		; Retry count

.retry:
	pusha			; Save all registers, we don't know what BIOS modifies
	stc			; Set carry flag, some BIOS' don't set it	
	int 13h			; Carry flag cleared = success
	jnc .done		; Jump if carry not set

	; Read Failed
	popa
	call disk_reset

	dec di
	test di, di
	jnz .retry

.fail:
	jmp floppy_error

.done:
	popa

	pop di
	pop dx
	pop cx
	pop bx
	pop ax		; Restore modified registers
	ret

; Resets disk controller
; Parameters: dl: drive number
disk_reset:
	pusha
	mov ah, 0
	stc
	int 13h
	jc floppy_error
	popa
	ret
	
	

BOOTMSG:	db "Bootloader: OK", ENDL, 0
READFAIL:	db "Disk: READ FAILURE", ENDL, 0

times 510 - ($ - $$) db 0	; Pad with 0
dw 0xAA55			; Signature
