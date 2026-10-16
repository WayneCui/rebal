# eval

`Do_Next`、`do`、`do/next`、中缀、`func` / `does`、`make object!`、路径和 `reduce`。

## 不变量

中缀没有优先级表：`1 + 2 * 3` 的结果是 9。paren 会求值，block 当数据。`do/next` 推进的是同一条 series 的下标。

`func` 复制函数体。参数钉到新的 frame，其余 word 保持定义时的绑定。`make object!` 先收集规格块顶层的 set-word，绑到新 frame，再求值。路径里，对象按字段取值；块里的 word 取它后面的那一项，整数按下标取。`reduce` 逐个表达式求值，丢掉 unset。

## 不做

端口、脚本文件、parse、mold。
