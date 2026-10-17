# eval

`Do_Next`、`do`、`do/next`、中缀、`func` / `does`、`make object!`、路径、`reduce`、`mold` / `form`、`type?`、`try`、`if` / `either`、`return`、`while` / `until` / `loop` 和 `break`。

## 不变量

中缀没有优先级表：`1 + 2 * 3` 的结果是 9。paren 会求值，block 当数据。`do/next` 推进的是同一条 series 的下标。

`func` 复制函数体。参数钉到新的 frame，其余 word 保持定义时的绑定。`make object!` 先收集规格块顶层的 set-word，绑到新 frame，再求值。路径里，对象按字段取值；块里的 word 取它后面的那一项，整数按下标取。`reduce` 逐个表达式求值，丢掉 unset。`try` 接住块里的失败，装成 `error!`，但会把 `return` 继续抛出。`if` 和 `either` 只求值被选中的块；条件为假时 `if` 得到 `none`。`return` 停在当前用户函数，没有函数接住它时 `run` 得到 `return` 错误。`break` 停在最内层循环，循环结果是 `none`；没有循环接住它时 `run` 得到 `break` 错误。`try` 会把这两条退出继续抛出。

## 不做

端口、脚本文件和 parse。
