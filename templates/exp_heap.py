#!/bin/python
# _*_ coding: utf-8 _*_

import sys
from pwn import *

sys.path.insert(0, "[PWNKIT_PATH]")
from pwnkit import HeapMenu

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

# ===== heap menu =====
# 只负责"选菜单项"，idx/size/content 等每题都变的部分在下面就地改
hm = HeapMenu(io, menu_prompt=b"...",
              add_opt=1, edit_opt=2, show_opt=3, delete_opt=4)

def add(idx, size, content):
    hm.add()
    sla(b"...", str(idx))
    sla(b"...", str(size))
    # sla(b"...", str(len(content)))   # len 型题目解开注释
    sa(content)

def edit(idx, content):
    hm.edit()
    sla(b"...", str(idx))
    sa(content)

def show(idx):
    hm.show()
    sla(b"...", str(idx))

def delete(idx):
    hm.delete()
    sla(b"...", str(idx))

# ===== main =====
def main():

# ===== exec =====
if __name__ == '__main__':
    main()
    ti()
