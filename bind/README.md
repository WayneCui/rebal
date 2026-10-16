# bind

`Bind_Block`：把块里的 word 钉到指定 frame 的槽上。

## 不变量

一次只绑到传入的那个 frame。命中的 word 整格写回；未命中的保持原绑定。从 cell 当前下标走到尾，并走进嵌套的块、paren 和 path。块里再次出现正在绑定的同一条 series 时停住。

## 不做

求值，也不在这里做跨 frame 的向上查找。
