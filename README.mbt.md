# Rebal

Rebol3 语义的解释器内核，用 MoonBit 实现。脚本后缀 `.rebal`。

语义对照 Oldes Rebol3。本仓库不移植端口、加密、完整 mezz 和 parse。

## 包

依赖只有一个方向：`eval` 调用 `action`，`action` 不调用求值器。

```text
value
  ^
series  scan  bind  mold
  ^       ^     ^     ^
  +-------+-----+-----+
              ^
            action
              ^
             eval
              ^
           cmd/repl
```

| 包 | 职责 |
| --- | --- |
| `value` | Cell、符号、Series 缓冲区、Frame 槽 |
| `series` | copy、next、append、find 等序列动作 |
| `scan` | 源码 transcode 成值块 |
| `bind` | Bind_Block |
| `mold` | mold 与 form |
| `action` | 按类型分派，不进入求值器 |
| `eval` | Do_Next、func、对象、路径 |
| `cmd/repl` | 对一段源码 do 并打印 |
