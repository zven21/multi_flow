# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-10-21

### Added

- 🎉 Initial release of MultiFlow
- 🌊 DSL for declarative transaction definitions
- 🔧 Builder pattern for functional transaction composition
- 📝 Comprehensive documentation and guides
- 🧪 Full test coverage
- 🎯 Real-world examples (sales order, user registration, inventory)
- 🛡️ Type specs for Dialyzer support
- 📖 Getting Started guide
- 📖 DSL guide
- 📖 Builder guide
- 📖 Real-world examples guide

### Features

#### DSL Style
```elixir
use MultiFlow

transaction do
  step :order, insert(order_changeset)
  step :items, &create_items/1
  step :delivery, &create_delivery/1
end
```

#### Builder Style
```elixir
MultiFlow.new()
|> add_step(:order, insert: order_changeset)
|> add_step(:items, &create_items/1)
|> execute()
```

### Key Benefits

- 🌊 **Flow naturally** - Write transactions that read like prose
- 🎯 **DSL & Builder** - Choose your preferred style
- 🔗 **Dependency tracking** - Automatic step dependency management
- 🛡️ **Type safe** - Full Dialyzer support
- 📝 **Readable** - Self-documenting code
- 🧪 **Testable** - Easy to test individual steps
- 🚀 **Zero overhead** - Compiles to raw Ecto.Multi

---

**"Make Ecto.Multi flow like water"** 🌊

