# -*- coding: utf-8 -*-
"""菜单堆辅助：只封装"选菜单项"这一稳定动作，不封装每题都变的交互细节。"""


class HeapMenu:
    """菜单堆的菜单导航助手。

    只负责"在菜单提示后发送对应功能编号"这一固定步骤，即:
        io.sendlineafter(menu_prompt, str(<opt>))

    至于 add/edit 后续要发的 idx / size / content 等每题都不同的内容，
    由调用方在 exp 里自行接着写。

    用法::

        m = HeapMenu(io, menu_prompt=b"> ", add_opt=1, edit_opt=2,
                     show_opt=3, delete_opt=4)
        m.add()                  # 自动 sla(b"> ", "1")
        sla(b"index: ", str(0))  # 之后的交互自己写

    各 *_opt 与 menu_prompt 也可在构造后再赋值::

        m = HeapMenu(io)
        m.menu_prompt = b"> "
        m.add_opt = 1
    """

    def __init__(
        self,
        io,
        menu_prompt=None,
        add_opt=None,
        edit_opt=None,
        show_opt=None,
        delete_opt=None,
    ):
        self.io = io
        self.menu_prompt = menu_prompt
        self.add_opt = add_opt
        self.edit_opt = edit_opt
        self.show_opt = show_opt
        self.delete_opt = delete_opt

    def _select(self, opt, name):
        """等待菜单提示后发送功能编号。"""
        if self.menu_prompt is None:
            raise ValueError("menu_prompt 未设置")
        if opt is None:
            raise ValueError(f"{name}_opt 未设置")
        self.io.sendlineafter(self.menu_prompt, str(opt).encode())

    def add(self):
        self._select(self.add_opt, "add")

    def edit(self):
        self._select(self.edit_opt, "edit")

    def show(self):
        self._select(self.show_opt, "show")

    def delete(self):
        self._select(self.delete_opt, "delete")
