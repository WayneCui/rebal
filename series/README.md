# series

块、字符串、二进制上的序列动作：`copy`、`next`、`head`、`tail`、`skip`、`at`、`pick`、`poke`、`insert`、`remove`、`append`、`find`，以及 `index?`、`tail?`、`length?`。

## 不变量

除 `copy` 以外，这些动作共享原来的缓冲区。`copy` 复制从当前下标到尾部的内容，新 series 的下标从 0 开始。

## 不做

求值、绑定、mold。
