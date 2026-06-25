# pwn-scripts

存放 pwn (CTF二进制利用) 的小工具集合。

## 工具清单

### chLibc
快速更换 ELF 文件的 glibc 版本。

```bash
chLibc ./pwn 2.23
```

依赖: patchelf, glibc-all-in-one

### GDB glibc debug symbols
让 GDB / pwndbg 在调试切换过 glibc 的题目时，自动加载对应 libc 的调试符号，便于查看堆结构和 `main_arena` 等符号。

先创建本地配置文件：

```bash
cp gdb/config.example.json gdb/config.json
```

编辑 `gdb/config.json`，填入本机 glibc 库目录：

```json
{
  "glibc_libs_dir": "/absolute/path/to/glibcs/libs"
}
```

也可以临时用环境变量覆盖：

```bash
export PWN_GLIBC_LIBS_DIR=/absolute/path/to/glibcs/libs
```

`install.sh` 会自动在 `~/.gdbinit` 中加载 `gdb/glibc-debug.py`。之后使用 `gdb.attach` 时，GDB 启动阶段会扫描配置的 glibc 目录并设置 `debug-file-directory` 与 `libthread-db-search-path`。

### pwninit
初始化 pwn 题目环境，自动生成 exp.py 模板。

```bash
pwninit ./pwn
```

会检测架构、运行 checksec、复制模板到当前目录。

## 安装

```bash
bash install.sh
```

自动将 bin/ 目录添加到 PATH，并在 `~/.gdbinit` 中加载 GDB glibc 调试符号脚本。

## 目录结构

```
.
├── bin/           # 可执行脚本
├── src/
│   ├── python/    # Python 脚本源码
│   └── shell/     # Shell 脚本源码
├── gdb/           # GDB 辅助脚本与本地配置模板
├── templates/     # exp.py 模板
└── install.sh     # 安装脚本
```
