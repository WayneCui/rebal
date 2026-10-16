# value

Cell、符号表、Series 缓冲区和 Frame 槽。

## 不变量

- 下标在 cell 上，缓冲区在 `Series` 上。复制 cell 会复制下标，并继续指向同一条 `Series`。
- word 的相等比较的是符号编号。符号表用 ASCII 大小写折叠后的规范形做键，cell 另存原始拼写。
- 重新绑定会换掉 series 里的那一格 `Word`。此前复制出去的 word 仍保留原来的绑定。嵌套块在 `copy_from` 之后仍然共享；word 会做成新的一份。

## 不做

扫描、求值、对块做 Bind_Block、mold。
