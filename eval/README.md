# eval

`Do_Next`、`do`、`do/next`、中缀、`func`、`make object!`、路径和 `reduce`。

## 不变量

中缀没有优先级表：`1 + 2 * 3` 的结果是 9。paren 会求值，block 当数据。`do/next` 推进的是同一条 series 的下标。

## 不做

端口、脚本文件和 parse。
