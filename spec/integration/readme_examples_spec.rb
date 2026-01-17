# README Examples Testing
#
# Tests code examples from README.md to catch documentation rot.
# Examples run with implicit setup (MockModel, mock tools) so they stay concise.
#
# The README stays clean and readable while we verify examples work.
#
require "English"

# rubocop:disable RSpec/DescribeClass -- integration test, not testing a class # -- SKIP_PATTERNS used for dynamic test generation # -- dynamic context names from README line numbers
# rubocop:disable RSpec/LeakyLocalVariable -- dynamic test generation needs shared state
RSpec.describe "README Examples", :integration do
  # Skip patterns - examples that are illustrative only
  SKIP_PATTERNS = [
    /OpenAIModel\.new/,           # Requires API key
    /AnthropicModel\.new/,        # Requires API key
    /LiteLLMModel\.new/,          # Requires API key
    /api_key:/,                   # Requires API key
    /lm_studio/,                  # Requires local server
    /ollama/,                     # Requires local server
    /llama_cpp/,                  # Requires local server
    /localhost/,                  # Requires local server
    /class \w+Tool\s*</,          # Class definitions (incomplete)
    /def forward/,                # Method definitions (incomplete)
    /def execute/,                # Method definitions (incomplete)
    /agent\.run/,                 # Would need full agent setup
    /\.run\(/,                    # Would need full agent setup
    /\.run_fiber/,                # Would need full agent setup
    /fiber\.resume/,              # Fiber execution
    /result\.output/,             # Needs agent result
    /result\.steps/,              # Needs agent result
    /team\.run/,                  # Needs multi-agent setup
    /spawn\(/,                    # Needs multi-agent setup
    /^#\s*Gemfile/,               # Gemfile comments
    /^gem\s+['"]smolagents/,      # Gem declarations
    /^gem\s+['"]ruby-/,           # Dependency declarations
    /\.tools\(:search/,           # Toolkit expansion (illustrative)
    /\.tools\(:web/,              # Toolkit expansion (illustrative)
    /\.tools\(:data/,             # Toolkit expansion (illustrative)
    /\.tools\(:research/,         # Toolkit expansion (illustrative)
    /my_model/,                   # Placeholder variable
    /\.on\(:tool_call\)/,         # Event handlers (needs model)
    /expect\s*\{/,                # RSpec examples
    /it\s+["']/,                  # RSpec test definitions
    /^\./,                        # DSL fragments (method chaining without receiver)
    /^bundle\s+exec/              # Shell commands
  ].freeze

  # Extract code blocks using regex (works with GitHub-flavored markdown)
  def self.extract_ruby_blocks(content)
    blocks = []
    # Match ```ruby ... ``` blocks
    content.scan(/^```ruby\n(.*?)^```/m) do |match|
      code = match[0].strip
      # Approximate line number by counting newlines before this match
      position = $LAST_MATCH_INFO.begin(0)
      line = content[0...position].count("\n") + 1
      blocks << { code:, line: }
    end
    blocks
  end

  # Pre-parse README and extract code blocks at load time
  readme_path = File.join(__dir__, "../../README.md")

  if File.exist?(readme_path)
    readme_content = File.read(readme_path)
    code_blocks = extract_ruby_blocks(readme_content)

    # Generate test for each block
    code_blocks.each_with_index do |block, index|
      code = block[:code]
      line = block[:line]

      # Check if should skip
      skip_reason = SKIP_PATTERNS.find { |pattern| code.match?(pattern) }

      context "block #{index + 1} (line #{line})" do
        if skip_reason
          it "is illustrative (skipped)" do
            skip "Illustrative example matching: #{skip_reason.source[0..30]}..."
          end
        else
          # Implicit setup for README examples
          let(:mock_model) do
            Smolagents::Testing::MockModel.new.tap do |m|
              m.queue_final_answer("Example result")
              m.queue_final_answer("Example result") # Extra for multi-step
            end
          end
          let(:model) { mock_model }

          before do
            # Stub executor to avoid actual code execution
            executor = instance_double(Smolagents::LocalRubyExecutor)
            allow(executor).to receive(:send_tools)
            allow(executor).to receive(:send_variables)
            allow(executor).to receive(:execute).and_return(
              Smolagents::Executors::Executor::ExecutionResult.success(
                output: "Example result", logs: "", is_final_answer: true
              )
            )
            allow(Smolagents::LocalRubyExecutor).to receive(:new).and_return(executor)

            # Reset configuration
            Smolagents.reset_configuration!
          end

          it "executes without error" do
            # Build a context with implicit variables
            # rubocop:disable Security/Eval
            expect do
              # Create an isolated binding with our helpers
              b = binding
              b.local_variable_set(:model, mock_model)
              b.local_variable_set(:mock_model, mock_model)
              eval(code, b, "README.md", line)
            end.not_to raise_error
            # rubocop:enable Security/Eval
          end
        end
      end
    end
  else
    it "README.md exists" do
      skip "README.md not found at #{readme_path}"
    end
  end
end
# rubocop:enable RSpec/DescribeClass, RSpec/LeakyLocalVariable
