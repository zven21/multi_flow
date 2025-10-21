# MultiFlow 发布到 hex.pm 指南

## 发布前准备

### 1. 检查 hex.pm 账户

首先确保你有 hex.pm 账户并已认证：

```bash
# 检查是否已登录
mix hex.user

# 如果没有账户，先注册
mix hex.user register

# 登录账户
mix hex.user auth
```

### 2. 验证包配置

你的 `mix.exs` 已经配置得很好，包含：
- ✅ 版本号 (`@version "1.0.0"`)
- ✅ 描述 (`description()`)
- ✅ 包信息 (`package()`)
- ✅ 许可证 (`MIT`)
- ✅ 文件列表
- ✅ GitHub 链接

### 3. 运行测试

确保所有测试通过：

```bash
# 运行所有测试
mix test

# 运行特定测试
mix test test/multi_flow/
```

### 4. 代码质量检查

```bash
# 格式化代码
mix format

# 检查代码风格
mix credo --strict

# 运行 Dialyzer（如果有配置）
mix dialyzer
```

### 5. 生成文档

```bash
# 生成文档
mix docs

# 检查文档是否生成成功
ls doc/
```

## 发布步骤

### 1. 检查包状态

```bash
# 检查包是否可以发布
mix hex.publish --dry-run
```

### 2. 发布包

```bash
# 发布包到 hex.pm
mix hex.publish
```

### 3. 发布文档（可选）

```bash
# 发布文档到 hexdocs.pm
mix hex.docs
```

## 发布后验证

### 1. 检查包是否成功发布

访问 https://hex.pm/packages/multi_flow 查看你的包

### 2. 测试安装

在另一个项目中测试安装：

```bash
# 创建测试项目
mix new test_multi_flow
cd test_multi_flow

# 添加依赖
echo '{:multi_flow, "~> 1.0"}' >> mix.exs

# 获取依赖
mix deps.get

# 测试使用
iex -S mix
```

## 版本管理

### 语义化版本

遵循 [语义化版本](https://semver.org/lang/zh-CN/) 规范：

- **主版本号** (1.0.0): 不兼容的 API 修改
- **次版本号** (1.1.0): 向下兼容的功能性新增
- **修订号** (1.0.1): 向下兼容的问题修正

### 更新版本

1. 更新 `mix.exs` 中的版本号
2. 更新 `CHANGELOG.md`
3. 提交更改
4. 创建 Git 标签
5. 发布新版本

```bash
# 更新版本号
# 编辑 mix.exs 中的 @version

# 更新 CHANGELOG.md
# 添加新版本的变更记录

# 提交更改
git add .
git commit -m "Release v1.0.1"
git tag v1.0.1
git push origin main --tags

# 发布新版本
mix hex.publish
```

## 常见问题

### 1. 包名冲突

如果包名已存在，需要：
- 更改包名（在 `mix.exs` 的 `package()` 中）
- 或者联系 hex.pm 支持

### 2. 版本已存在

如果版本号已存在：
- 更新版本号
- 重新发布

### 3. 文档发布失败

检查：
- 文档是否生成成功
- 是否有语法错误
- 网络连接是否正常

## 最佳实践

### 1. 发布前检查清单

- [ ] 所有测试通过
- [ ] 代码格式化完成
- [ ] 文档更新完整
- [ ] CHANGELOG.md 更新
- [ ] 版本号正确
- [ ] 许可证文件存在
- [ ] README.md 完整

### 2. 版本发布流程

1. 开发功能
2. 编写测试
3. 更新文档
4. 更新 CHANGELOG
5. 更新版本号
6. 提交代码
7. 创建标签
8. 发布包

### 3. 维护建议

- 定期更新依赖
- 及时修复安全问题
- 保持文档同步
- 响应社区反馈

## 自动化发布

可以考虑使用 GitHub Actions 自动化发布流程：

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: erlang/setup-beam@v1
        with:
          elixir-version: '1.14'
      - run: mix deps.get
      - run: mix test
      - run: mix hex.publish
        env:
          HEX_API_KEY: ${{ secrets.HEX_API_KEY }}
```

## 总结

发布到 hex.pm 的步骤：

1. **准备阶段**: 检查账户、验证配置、运行测试
2. **发布阶段**: 使用 `mix hex.publish` 发布包
3. **验证阶段**: 检查包是否成功发布
4. **维护阶段**: 持续更新和版本管理

你的 MultiFlow 项目配置已经很完善，可以直接发布！🚀
