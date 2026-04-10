# pwn-scripts

存放 pwn (CTF二进制利用) 的小工具集合。

## 工具清单

### chLibc
快速更换 ELF 文件的 glibc 版本。

```bash
chLibc ./pwn 2.23
```

依赖: patchelf, glibc-all-in-one

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

自动将 bin/ 目录添加到 PATH。

## 目录结构

```
.
├── bin/           # 可执行脚本
├── src/
│   ├── python/    # Python 脚本源码
│   └── shell/     # Shell 脚本源码
├── templates/     # exp.py 模板
└── install.sh     # 安装脚本
```
