# scan

把源码 transcode 成值块。

## 不变量

扫描结果是值，没有语法树。`[]` 和 `()` 都是 series，类型分别是 block 和 paren。

## 不做

求值。本轮不扫描日期、时间、pair、tuple、money、file、email、url、tag、issue 和构造语法。
