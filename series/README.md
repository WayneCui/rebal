# series

块、字符串、二进制上的序列动作：`copy`、`next`、`head`、`tail`、`skip`、`at`、`pick`、`poke`、`insert`、`remove`、`append`、`find`，以及 `index?`、`tail?`、`length?`。

## 不变量

除 `copy` 以外，这些动作共享原来的缓冲区。`copy` 复制从当前下标到尾部的内容，新 series 的下标从 0 开始。`index?` 从 1 计。`skip` 和 `at` 把位置夹在头和尾之间。`append` / `insert` 遇到块或字符串时拼接其中的元素；拼接前先复制，所以块可以追加自己。字符串里的整数按数字字符查找，`find "123" 2` 得到 `"23"`。

## 不做

求值、绑定、mold。
