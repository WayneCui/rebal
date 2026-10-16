# bind

`Bind_Block`：把块里的 word 钉到指定 frame 的槽上。

## 不变量

一次只绑到传入的那个 frame。命中的 word 整格写回；未命中的保持原绑定。

## 不做

求值，也不在这里做跨 frame 的向上查找。
