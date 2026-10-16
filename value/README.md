# value

Cell、符号表、Series 缓冲区和 Frame 槽。

## 不变量

- 复制 cell 会复制 series 的下标，不会复制缓冲区。
- word 的相等比较的是符号编号。符号表用 ASCII 大小写折叠后的规范形做键，cell 另存原始拼写。
- 绑定写在 word cell 里。修改绑定是整格写回，不在数组元素上改字段。

## 不做

扫描、求值、对块做 Bind_Block、mold。
