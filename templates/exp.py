#!/bin/python
# _*_ coding: utf-8 _*_

from pwn import *

context(arch = '[ARCH]', os = 'linux')
context.terminal = ['konsole', '-e']
context.log_level = 'debug'
context.binary = '[ELF_PATH]'
e = ELF('[ELF_PATH]')
libc = e.libc
# libc = ELF('')
host = "127.0.0.1"
post = 9999
if args['RE']:
    io = remote(host, post)
else:
    io = process('[ELF_PATH]')

def debug():
    gdb.attach(io)
    pause()

# ===== lambda =====
sa  = lambda s, d: io.sendafter(s, d)       # send after
sla = lambda s, d: io.sendlineafter(s, d)   # sendline after  
sl  = lambda d:    io.sendline(d)           # sendline
sd  = lambda d:    io.send(d)               # send
ru  = lambda s:    io.recvuntil(s)          # recvuntil
rc  = lambda n:    io.recv(n)               # recv n bytes
rl  = lambda :     io.recvline()            # recvline
ti  = lambda :     io.interactive()         # interactive
lg  = lambda s, v:    log.info('\033[1;32m %s --> 0x%x \033[0m' % (s, v))

# ===== main =====
def main():

# ===== exec =====
if __name__ == '__main__':
    main() 
    ti()
