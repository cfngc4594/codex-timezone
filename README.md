# Codex时区

给 Codex 单独指定时区，不修改 macOS 系统时区。适合要让 Codex 的时区与节点所在地一致的情况。

Launch Codex in a chosen timezone without changing the macOS system timezone. Use it when Codex should follow a network node's timezone.

## 安装

```bash
curl -fsSL https://raw.githubusercontent.com/cfngc4594/codex-timezone/main/install.sh | bash
```

安装时用上下键选择节点所在时区，回车确认。当前时区会预先选中。其他时区可以选「手动输入」，再填写城市代码（如 `LAX`、`NRT`）或 IANA 时区名，例如 `America/Los_Angeles`。需要 UTC 时选 UTC，配置里会写成 `Etc/UTC`。

只影响通过本工具启动的 Codex。

During install, choose a timezone with the arrow keys and confirm with Enter. An existing choice stays selected. Choose 手动输入 to enter a city code or an IANA timezone name. UTC is stored as `Etc/UTC`. Only Codex launched through this tool is affected.
