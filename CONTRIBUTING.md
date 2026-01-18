# Contributing to smolagents-ruby

Everyone is welcome to contribute, and we value everybody's contribution. Code
contributions are not the only way to help the community. Answering questions, helping
others, and improving the documentation are also immensely valuable.

It also helps us if you spread the word! Reference the library in blog posts
about the awesome projects it made possible, shout out on social media every time it has
helped you, or simply ⭐️ the repository to say thank you.

However you choose to contribute, please be mindful and respect our
[code of conduct](CODE_OF_CONDUCT.md).

## Ways to contribute

There are several ways you can contribute to smolagents-ruby:

* Submit issues related to bugs or desired new features.
* Contribute to the examples or to the documentation.
* Fix outstanding issues with the existing code.
* Add new tools or improve existing ones.
* Improve test coverage.

> All contributions are equally valuable to the community. 🥰

## Submitting a bug-related issue or feature request

At any moment, feel welcome to open an issue, citing your exact error traces and gem versions if it's a bug.
It's often even better to open a PR with your proposed fixes/changes!

Do your best to follow these guidelines when submitting a bug-related issue or a feature
request. It will make it easier for us to come back to you quickly and with good
feedback.

### Did you find a bug?

The smolagents-ruby library is robust and reliable thanks to users who report the problems they encounter.

Before you report an issue, we would really appreciate it if you could **make sure the bug was not
already reported** (use the search bar on GitHub under Issues). Your issue should also be related to bugs in the
library itself, and not your code.

Once you've confirmed the bug hasn't already been reported, please include the following information in your issue so
we can quickly resolve it:

* Your **OS type and version**, as well as your Ruby version and gem versions.
* A short, self-contained, code snippet that allows us to reproduce the bug.
* The *full* traceback if an exception is raised.
* Attach any other additional information, like screenshots, you think may help.

### Do you want a new feature?

If there is a new feature you'd like to see in smolagents-ruby, please open an issue and describe:

1. What is the *motivation* behind this feature? Is it related to a problem or frustration with the library? Is it
   a feature related to something you need for a project? Is it something you worked on and think it could benefit
   the community?

   Whatever it is, we'd love to hear about it!

2. Describe your requested feature in as much detail as possible. The more you can tell us about it, the better
   we'll be able to help you.
3. Provide a *code snippet* that demonstrates the feature's usage.
4. If the feature is related to a paper, please include a link.

If your issue is well written we're already 80% of the way there by the time you create it.

## Do you want to add documentation?

We're always looking for improvements to the documentation that make it more clear and accurate. Please let us know
how the documentation can be improved such as typos and any content that is missing, unclear or inaccurate. We'll be
happy to make the changes or help you make a contribution if you're interested!

## Development Setup

### Prerequisites

- Ruby 4.0 or higher
- Bundler

### Installation

Clone the repository and install dependencies:

```bash
git clone https://github.com/yourusername/smolagents-ruby.git
cd smolagents-ruby
bundle install
```

### Running Tests

Run the full test suite:

```bash
bundle exec rspec
```

Run specific test files:

```bash
bundle exec rspec spec/smolagents/tools/tool_spec.rb
```

Run tests with coverage:

```bash
bundle exec rspec --format documentation
```

### Code Quality

We use RuboCop for code quality checks. Run it with:

```bash
bundle exec rubocop
```

Auto-fix issues where possible:

```bash
bundle exec rubocop -a
```

### Making Changes

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Write or update tests for your changes
5. Ensure all tests pass (`bundle exec rspec`)
6. Ensure RuboCop passes (`bundle exec rubocop`)
7. Commit your changes with a descriptive message
8. Push to your fork
9. Open a Pull Request

### Pull Request Guidelines

- Keep changes focused - one feature or fix per PR
- Write clear commit messages
- Add tests for new functionality
- Update documentation as needed
- Ensure all CI checks pass

## Project Structure

```
lib/smolagents/
├── smolagents.rb              # Main entry point
├── tools/                     # Tool framework
├── default_tools/             # Built-in tools
├── models/                    # Model integrations
├── agents/                    # Agent implementations
└── executors/                 # Code execution

spec/                          # RSpec tests
examples/                      # Usage examples
```

## Adding New Tools

To add a new tool:

1. Create a new file in `lib/smolagents/default_tools/`
2. Subclass `Smolagents::Tool`
3. Define `tool_name`, `description`, `inputs`, and `output_type`
4. Implement the `forward` method
5. Add tests in `spec/smolagents/default_tools/`
6. Update `lib/smolagents/default_tools.rb` to register the tool

See existing tools for examples.

## License

By contributing, you agree that your contributions will be licensed under the Apache License 2.0.

## Questions?

Feel free to open an issue with the `question` label if you need help or clarification!

---

**This is a Ruby port of [HuggingFace smolagents](https://github.com/huggingface/smolagents), originally created by the HuggingFace team.**
