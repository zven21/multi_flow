# Contributing to MultiFlow

Thank you for your interest in contributing to MultiFlow! We welcome contributions of all kinds, including but not limited to:

- 🐛 Bug reports
- 💡 Feature suggestions
- 📝 Documentation improvements
- 🧪 Test cases
- 🔧 Code contributions

## How to Contribute

### 1. Reporting Issues

If you find a bug or have a feature suggestion, please:

1. Check if the issue already exists in [Issues](https://github.com/zven21/multi_flow/issues)
2. Create a new Issue with:
   - Clear problem description
   - Steps to reproduce
   - Expected behavior
   - Actual behavior
   - Environment information (Elixir version, Ecto version, etc.)

### 2. Code Contributions

#### Setting up Development Environment

```bash
# Clone the repository
git clone https://github.com/zven21/multi_flow.git
cd multi_flow

# Install dependencies
mix deps.get

# Run tests
mix test

# Generate documentation
mix docs
```

#### Development Workflow

1. **Fork the repository** to your GitHub account
2. **Create a branch** for your feature or fix:
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/your-bug-fix
   ```
3. **Write code** and ensure:
   - Code follows Elixir style guidelines
   - Add necessary tests
   - Update relevant documentation
4. **Run tests** to ensure all tests pass:
   ```bash
   mix test
   mix format
   ```
5. **Commit changes**:
   ```bash
   git add .
   git commit -m "Add: your feature description"
   ```
6. **Push branch**:
   ```bash
   git push origin feature/your-feature-name
   ```
7. **Create Pull Request**

#### Code Standards

- Use `mix format` to format code
- Follow Elixir community best practices
- Add documentation comments for public functions
- Write clear test cases
- Maintain backward compatibility

#### Testing Requirements

- New features must have corresponding test cases
- Test coverage should be maintained above 90%
- Use descriptive test names
- Tests should cover normal cases and edge cases

### 3. Documentation Contributions

Documentation contributions include:

- Improving existing documentation
- Adding usage examples
- Fixing errors in documentation
- Translating documentation

Documentation files are located in the `guides/` directory and use Markdown format.

### 4. Release Process

If you have release permissions, the process for releasing a new version:

1. Update version number in `mix.exs`
2. Update `CHANGELOG.md`
3. Run tests to ensure everything is working
4. Create Git tag
5. Publish to hex.pm

## Development Guide

### Project Structure

```
lib/
├── multi_flow/
│   ├── builders.ex    # Builder pattern implementation
│   ├── dsl.ex         # DSL implementation
│   └── utils.ex       # Utility functions
└── multi_verse.ex     # Main module

test/
├── multi_flow/
│   ├── builders_test.exs
│   └── dsl_test.exs
└── multi_flow_test.exs

guides/
├── getting_started.md
├── dsl_guide.md
├── builder_guide.md
└── real_world_examples.md
```

### Core Concepts

MultiFlow provides two usage patterns:

1. **DSL Pattern** (`MultiFlow.DSL`): Uses `use MultiFlow` and `transaction` macro
2. **Builder Pattern** (`MultiFlow.Builders`): Uses chained method calls

### Testing Strategy

- Unit tests: Test individual module functionality
- Integration tests: Test complete transaction flows
- Edge case tests: Test error conditions and boundary cases

## Community Guidelines

### Code of Conduct

- Be friendly and respectful
- Welcome contributors from different backgrounds
- Focus on the issue, not the person
- Accept constructive criticism

### Communication Channels

- GitHub Issues: For bug reports and feature suggestions
- GitHub Discussions: For general discussions and questions
- Pull Requests: For code review and discussion

## License

By contributing code, you agree that your contributions will be released under the MIT License.

## Acknowledgments

Thank you to all developers who have contributed to the MultiFlow project!

---

If you have any questions, please feel free to ask in GitHub Issues. We're happy to help you get started with contributing!
