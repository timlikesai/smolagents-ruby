# Ruby Code Validation & AST Analysis for Security

Comprehensive research on validating LLM-generated Ruby code before execution in an agent framework.

## Table of Contents
1. [Ripper (Built-in Parser)](#1-ripper-built-in-parser)
2. [Parser Gem](#2-parser-gem)
3. [Static Analysis Patterns](#3-static-analysis-patterns)
4. [Common Evasion Techniques](#4-common-evasion-techniques)
5. [Production Examples](#5-production-examples)
6. [Implementation Recommendations](#6-implementation-recommendations)

---

## 1. Ripper (Built-in Parser)

### Overview
Ripper is Ruby's built-in AST parser (available since Ruby 1.9). It's a C-based parser that provides event-based access to the parse tree.

**Pros:**
- Built into Ruby stdlib (no dependencies)
- Fast: 11.3 iterations/second in benchmarks (2.75x faster than parser gem)
- Zero setup required

**Cons:**
- Output is harder to work with than parser gem
- Event-based API is more complex
- Doesn't catch all syntax errors consistently

### Basic Usage

```ruby
require 'ripper'

code = <<~RUBY
  def dangerous_method(input)
    eval(input)
  end
RUBY

# Parse to S-expression
ast = Ripper.sexp(code)
# => [:program, [[:def, [:@ident, "dangerous_method", [2, 6]], ...]]]
```

### Detecting Dangerous Method Calls

```ruby
require 'ripper'

class DangerousMethodDetector < Ripper::SexpBuilderPP
  DANGEROUS_METHODS = %i[
    eval instance_eval class_eval module_eval
    system exec spawn `
    load require require_relative
    send __send__ public_send
    const_get const_set
    instance_variable_get instance_variable_set
    class_variable_get class_variable_set
    remove_const remove_method undef_method
    define_method define_singleton_method
  ].freeze

  DANGEROUS_CLASSES = %w[
    File IO Dir Kernel Process
    Marshal ObjectSpace Binding
  ].freeze

  def initialize(code)
    @dangerous_calls = []
    super(code)
  end

  def on_command(method_name, args)
    method = method_name[1] # Extract method name from [:@ident, "eval", [...]]
    if DANGEROUS_METHODS.include?(method.to_sym)
      @dangerous_calls << { type: :command, method: method, line: method_name[2][0] }
    end
    super
  end

  def on_vcall(method_name)
    method = method_name[1]
    if DANGEROUS_METHODS.include?(method.to_sym)
      @dangerous_calls << { type: :vcall, method: method, line: method_name[2][0] }
    end
    super
  end

  def on_call(receiver, dot, method_name)
    method = method_name[1]
    if DANGEROUS_METHODS.include?(method.to_sym)
      @dangerous_calls << { type: :call, method: method, line: method_name[2][0] }
    end
    super
  end

  attr_reader :dangerous_calls
end

# Usage
detector = DangerousMethodDetector.new("eval('puts 1')")
detector.parse
puts detector.dangerous_calls
# => [{:type=>:command, :method=>"eval", :line=>1}]
```

### Finding require/load Statements

```ruby
class RequireDetector < Ripper::SexpBuilderPP
  def initialize(code)
    @requires = []
    super(code)
  end

  def on_command(method_name, args)
    method = method_name[1]
    if %w[require require_relative load].include?(method)
      # Extract the required file from args
      file = extract_string_from_args(args)
      @requires << { method: method, file: file, line: method_name[2][0] }
    end
    super
  end

  private

  def extract_string_from_args(args)
    # args structure: [:args_add_block, [[:string_literal, ...]], false]
    return nil unless args && args[0] == :args_add_block
    string_node = args[1]&.first
    return nil unless string_node && string_node[0] == :string_literal
    # Extract string content
    content_node = string_node[1]
    if content_node[0] == :string_content
      content_node[1]&.dig(1) # [:@tstring_content, "file_name", [...]]
    end
  end

  attr_reader :requires
end

# Usage
code = <<~RUBY
  require 'socket'
  require_relative 'dangerous_lib'
  load '/etc/passwd'
RUBY

detector = RequireDetector.new(code)
detector.parse
puts detector.requires
# => [
#   {:method=>"require", :file=>"socket", :line=>1},
#   {:method=>"require_relative", :file=>"dangerous_lib", :line=>2},
#   {:method=>"load", :file=>"/etc/passwd", :line=>3}
# ]
```

### Identifying File/IO Operations

```ruby
class FileIODetector < Ripper::SexpBuilderPP
  FILE_IO_METHODS = %i[
    open read write
    readlines foreach
    delete unlink rename
    chmod chown
    mkdir rmdir
  ].freeze

  FILE_IO_CLASSES = %w[File IO Dir Pathname].freeze

  def initialize(code)
    @file_operations = []
    super(code)
  end

  def on_call(receiver, dot, method_name)
    method = method_name[1]

    # Check if it's a File/IO class method
    if receiver && receiver[0] == :var_ref
      const_name = receiver[1][1] if receiver[1][0] == :@const
      if FILE_IO_CLASSES.include?(const_name) && FILE_IO_METHODS.include?(method.to_sym)
        @file_operations << {
          class: const_name,
          method: method,
          line: method_name[2][0]
        }
      end
    end

    super
  end

  attr_reader :file_operations
end

# Usage
code = <<~RUBY
  File.read('/etc/passwd')
  IO.open('dangerous.txt', 'w')
  Dir.delete('important')
RUBY

detector = FileIODetector.new(code)
detector.parse
puts detector.file_operations
# => [
#   {:class=>"File", :method=>"read", :line=>1},
#   {:class=>"IO", :method=>"open", :line=>2},
#   {:class=>"Dir", :method=>"delete", :line=>3}
# ]
```

---

## 2. Parser Gem

### Overview
The parser gem (whitequark/parser) is a production-ready Ruby parser written in pure Ruby. Starting in Ruby 3.4+, Prism is recommended as it's built into Ruby itself.

**Pros:**
- More convenient API than Ripper
- Better structured output
- Widely used by RuboCop, Brakeman, etc.
- Excellent documentation

**Cons:**
- 2.75x slower than Ripper (2.3 iterations/second)
- 12.06x slower when parsing + walking AST
- External dependency

**Modern Alternative (Ruby 3.4+):**
- **Prism** (formerly YARP) is 12x faster than parser gem
- Built into Ruby 3.4+
- Nearly 2x faster than Ripper in some cases

### Installation

```ruby
# Gemfile
gem 'parser'
```

### Basic Usage

```ruby
require 'parser/current'

code = <<~RUBY
  def risky(input)
    eval(input)
  end
RUBY

ast = Parser::CurrentRuby.parse(code)
# => s(:def, :risky,
#     s(:args, s(:arg, :input)),
#     s(:send, nil, :eval, s(:lvar, :input)))
```

### AST Node Structure

Common node types:
- `(send nil :method_name args...)` - Method call without explicit receiver
- `(send receiver :method_name args...)` - Method call with receiver
- `(const nil :ClassName)` - Constant reference
- `(lvar :variable)` - Local variable
- `(dstr ...)` - Interpolated string

### Detecting Dangerous Methods

```ruby
require 'parser/current'

class SecurityScanner
  DANGEROUS_METHODS = %i[
    eval instance_eval class_eval module_eval
    system exec spawn `
    send __send__ public_send
    const_get const_set
    constantize safe_constantize
    load require require_relative
  ].freeze

  DANGEROUS_CLASSES = %i[
    File IO Dir Kernel Process Marshal ObjectSpace Binding
  ].freeze

  def self.scan(code)
    ast = Parser::CurrentRuby.parse(code)
    issues = []
    scan_node(ast, issues)
    issues
  rescue Parser::SyntaxError => e
    [{ type: :syntax_error, message: e.message }]
  end

  def self.scan_node(node, issues)
    return unless node.is_a?(Parser::AST::Node)

    case node.type
    when :send, :csend
      check_send_node(node, issues)
    when :const
      check_const_node(node, issues)
    end

    # Recursively scan children
    node.children.each do |child|
      scan_node(child, issues)
    end
  end

  def self.check_send_node(node, issues)
    receiver, method_name, *args = node.children

    # Check for dangerous method calls
    if DANGEROUS_METHODS.include?(method_name)
      issues << {
        type: :dangerous_method,
        method: method_name,
        line: node.loc.line,
        severity: :high
      }
    end

    # Check for File/IO operations
    if receiver&.type == :const &&
       DANGEROUS_CLASSES.include?(receiver.children.last)
      issues << {
        type: :dangerous_class,
        class: receiver.children.last,
        method: method_name,
        line: node.loc.line,
        severity: :high
      }
    end

    # Check for Kernel.open / URI.open
    if method_name == :open
      issues << {
        type: :dangerous_open,
        line: node.loc.line,
        severity: :high,
        message: "Kernel#open can execute commands with pipe prefix"
      }
    end
  end

  def self.check_const_node(node, issues)
    const_name = node.children.last
    if DANGEROUS_CLASSES.include?(const_name)
      issues << {
        type: :dangerous_const,
        const: const_name,
        line: node.loc.line,
        severity: :medium
      }
    end
  end
end

# Usage
code = <<~RUBY
  eval(user_input)
  File.read('/etc/passwd')
  send(params[:method])
RUBY

issues = SecurityScanner.scan(code)
issues.each do |issue|
  puts "#{issue[:severity].upcase}: #{issue[:type]} at line #{issue[:line]}"
end
# => HIGH: dangerous_method at line 1
# => HIGH: dangerous_class at line 2
# => HIGH: dangerous_method at line 3
```

### Advanced AST Processor

```ruby
require 'parser/current'
require 'ast'

class AdvancedSecurityScanner < AST::Processor
  def initialize
    @issues = []
  end

  attr_reader :issues

  def on_send(node)
    receiver, method_name, *args = node.children

    # Detect eval with any argument type
    if method_name == :eval
      unless safe_eval?(node)
        @issues << {
          type: :eval,
          line: node.loc.line,
          message: "eval() detected - serious security risk"
        }
      end
    end

    # Detect send/public_send with string interpolation
    if %i[send __send__ public_send].include?(method_name)
      if args.any? { |arg| dynamic_string?(arg) }
        @issues << {
          type: :dynamic_send,
          line: node.loc.line,
          message: "send() with dynamic method name"
        }
      end
    end

    # Detect const_get with user input
    if method_name == :const_get
      @issues << {
        type: :const_get,
        line: node.loc.line,
        message: "const_get() can lead to RCE"
      }
    end

    super # Continue processing children
  end

  private

  def safe_eval?(node)
    # Only safe if argument is a literal string (not interpolated)
    _receiver, _method, arg = node.children
    arg&.type == :str
  end

  def dynamic_string?(node)
    return false unless node
    # Check for interpolated strings
    node.type == :dstr ||
      # Check for string concatenation
      (node.type == :send && node.children[1] == :+)
  end
end

# Usage
code = <<~RUBY
  eval("1 + 1")  # Safe (literal string)
  eval(params[:code])  # Dangerous
  send("method_" + user_input, args)  # Dangerous
RUBY

ast = Parser::CurrentRuby.parse(code)
scanner = AdvancedSecurityScanner.new
scanner.process(ast)

scanner.issues.each do |issue|
  puts "Line #{issue[:line]}: #{issue[:message]}"
end
```

---

## 3. Static Analysis Patterns

### Whitelist vs Blacklist Approaches

**Blacklist Approach** (NOT RECOMMENDED):
- Tries to block known dangerous operations
- Prone to bypasses
- Requires constant updates
- Ruby's security documentation warns: "Blacklisting is almost impossible to do without leaving gaps"

**Whitelist Approach** (RECOMMENDED):
- Only allows explicitly permitted operations
- More secure by default
- Harder to bypass
- Used by safe_ruby and production sandboxes

### Whitelist Implementation

```ruby
class WhitelistValidator
  # Only these classes can be instantiated
  ALLOWED_CLASSES = %w[
    String Integer Float Array Hash
    Time Date DateTime
    TrueClass FalseClass NilClass
    Range Regexp
  ].freeze

  # Only these methods can be called
  ALLOWED_METHODS = %i[
    + - * / % **
    << >> & | ^
    == != < > <= >= <=>
    to_s to_i to_f to_a to_h
    size length empty? include?
    first last each map select reject
    sort reverse join split
    upcase downcase capitalize
    strip chomp gsub
  ].freeze

  # Only these constants can be accessed
  ALLOWED_CONSTANTS = %w[
    Math
  ].freeze

  def self.validate(code)
    ast = Parser::CurrentRuby.parse(code)
    validator = new
    validator.validate_node(ast)
    validator.errors
  rescue Parser::SyntaxError => e
    [{ type: :syntax_error, message: e.message }]
  end

  def initialize
    @errors = []
  end

  attr_reader :errors

  def validate_node(node)
    return unless node.is_a?(Parser::AST::Node)

    case node.type
    when :send, :csend
      validate_send(node)
    when :const
      validate_const(node)
    when :def, :defs
      # Allow method definitions
    when :class, :module
      @errors << { type: :class_definition, line: node.loc.line }
    end

    node.children.each { |child| validate_node(child) }
  end

  private

  def validate_send(node)
    receiver, method_name, *_args = node.children

    # Check if method is in whitelist
    unless ALLOWED_METHODS.include?(method_name)
      @errors << {
        type: :forbidden_method,
        method: method_name,
        line: node.loc.line
      }
    end

    # Check receiver is allowed class
    if receiver&.type == :const
      const_name = receiver.children.last
      unless ALLOWED_CLASSES.include?(const_name.to_s)
        @errors << {
          type: :forbidden_class,
          class: const_name,
          line: node.loc.line
        }
      end
    end
  end

  def validate_const(node)
    const_name = node.children.last
    unless ALLOWED_CONSTANTS.include?(const_name.to_s) ||
           ALLOWED_CLASSES.include?(const_name.to_s)
      @errors << {
        type: :forbidden_constant,
        constant: const_name,
        line: node.loc.line
      }
    end
  end
end

# Usage
safe_code = <<~RUBY
  result = [1, 2, 3].map { |x| x * 2 }
  result.join(", ")
RUBY

unsafe_code = <<~RUBY
  File.read('/etc/passwd')
  eval(user_input)
RUBY

puts "Safe code errors: #{WhitelistValidator.validate(safe_code).size}"
# => Safe code errors: 0

puts "Unsafe code errors: #{WhitelistValidator.validate(unsafe_code).size}"
# => Unsafe code errors: 2
```

### Hybrid Approach (Practical)

```ruby
class HybridValidator
  # Critical blocklist - absolutely never allow
  CRITICAL_BLOCKLIST = %i[
    eval instance_eval class_eval module_eval binding
    system exec spawn `` fork
  ].freeze

  # Method whitelist for common operations
  SAFE_METHODS = %i[
    + - * / % **
    to_s to_i to_f inspect
    size length count empty?
    each map select reject filter
    sort reverse uniq compact
    upcase downcase capitalize strip
    split join gsub sub
  ].freeze

  def self.validate(code)
    ast = Parser::CurrentRuby.parse(code)
    errors = []

    # First pass: Check critical blocklist
    scan_for_critical(ast, errors)
    return errors if errors.any?

    # Second pass: Check against whitelist
    scan_for_allowed(ast, errors)
    errors
  rescue Parser::SyntaxError => e
    [{ type: :syntax_error, message: e.message }]
  end

  def self.scan_for_critical(node, errors)
    return unless node.is_a?(Parser::AST::Node)

    if node.type == :send
      method_name = node.children[1]
      if CRITICAL_BLOCKLIST.include?(method_name)
        errors << {
          type: :critical_violation,
          method: method_name,
          line: node.loc.line,
          severity: :critical
        }
      end
    end

    node.children.each { |child| scan_for_critical(child, errors) }
  end

  def self.scan_for_allowed(node, errors)
    return unless node.is_a?(Parser::AST::Node)

    if node.type == :send
      receiver, method_name = node.children[0..1]

      # Allow methods on literals and local variables
      safe_receiver = receiver.nil? ||
                     receiver.type == :lvar ||
                     literal?(receiver)

      unless safe_receiver && SAFE_METHODS.include?(method_name)
        errors << {
          type: :potentially_unsafe,
          method: method_name,
          line: node.loc.line,
          severity: :medium
        }
      end
    end

    node.children.each { |child| scan_for_allowed(child, errors) }
  end

  def self.literal?(node)
    %i[str int float true false nil array hash].include?(node.type)
  end
end
```

---

## 4. Common Evasion Techniques

### String Concatenation

```ruby
# Evasion
eval("ev" + "al", "1 + 1")  # Bypasses simple string matching

# Detection
class EvasionDetector
  def self.detect_string_concat_in_send(node)
    return false unless node.type == :send

    _receiver, method_name, *args = node.children

    # Check if any argument is string concatenation
    args.any? do |arg|
      arg.type == :send && arg.children[1] == :+ &&
        arg.children[0]&.type == :str &&
        arg.children[2]&.type == :str
    end
  end
end

# Better: Detect any dynamic method name construction
def dynamic_method_call?(node)
  return false unless node.type == :send

  # Check if method name argument (for send/public_send) is not a literal
  if %i[send __send__ public_send].include?(node.children[1])
    method_arg = node.children[2]
    return true unless method_arg&.type == :sym
  end

  false
end
```

### Method Dispatch (send/public_send)

```ruby
# Evasion attempts
1.send(:eval, "dangerous code")
obj.__send__(:system, "rm -rf /")
Object.public_send(:const_get, :File)

# Detection
class SendEvasionDetector < AST::Processor
  def initialize
    @violations = []
  end

  attr_reader :violations

  def on_send(node)
    receiver, method_name, *args = node.children

    # Detect send family
    if %i[send __send__ public_send method].include?(method_name)
      method_arg = args[0]

      # Flag if method name is:
      # 1. Dynamic (not a symbol literal)
      # 2. Or a dangerous method even if literal
      if !literal_symbol?(method_arg) || dangerous_symbol?(method_arg)
        @violations << {
          type: :send_evasion,
          line: node.loc.line,
          method: method_name,
          target: extract_symbol_value(method_arg)
        }
      end
    end

    super
  end

  private

  def literal_symbol?(node)
    node&.type == :sym
  end

  def dangerous_symbol?(node)
    return false unless node&.type == :sym
    dangerous_methods = %i[eval system exec spawn const_get instance_eval]
    dangerous_methods.include?(node.children[0])
  end

  def extract_symbol_value(node)
    node&.type == :sym ? node.children[0] : :dynamic
  end
end
```

### Constant Manipulation

```ruby
# Evasion attempts
Object.const_get(:File).read('/etc/passwd')
Object.const_get("Fi" + "le").open('dangerous')
Module.const_get(:Kernel).system("ls")

# Detection
class ConstGetDetector < AST::Processor
  def initialize
    @violations = []
  end

  attr_reader :violations

  def on_send(node)
    receiver, method_name, *args = node.children

    # Detect const_get or qualified_const_get
    if %i[const_get qualified_const_get].include?(method_name)
      const_arg = args[0]

      @violations << {
        type: :const_get_usage,
        line: node.loc.line,
        receiver: describe_receiver(receiver),
        target: describe_const_arg(const_arg),
        severity: dynamic_const?(const_arg) ? :critical : :high
      }
    end

    # Also detect constantize (Rails)
    if %i[constantize safe_constantize].include?(method_name)
      @violations << {
        type: :constantize_usage,
        line: node.loc.line,
        severity: :critical,
        message: "Can lead to RCE"
      }
    end

    super
  end

  private

  def dynamic_const?(node)
    # Not a literal string or symbol
    !%i[str sym].include?(node&.type)
  end

  def describe_receiver(node)
    return :implicit if node.nil?
    return node.children.last if node.type == :const
    :dynamic
  end

  def describe_const_arg(node)
    case node&.type
    when :str, :sym
      node.children[0]
    when :send
      if node.children[1] == :+
        :concatenated
      else
        :dynamic
      end
    else
      :unknown
    end
  end
end
```

### Instance Variable Manipulation

```ruby
# Evasion attempts
obj.instance_variable_get(:@dangerous)
obj.instance_variable_set(:@value, malicious)

# Detection
class InstanceVarDetector < AST::Processor
  DANGEROUS_REFLECTION = %i[
    instance_variable_get
    instance_variable_set
    class_variable_get
    class_variable_set
    remove_instance_variable
  ].freeze

  def initialize
    @violations = []
  end

  attr_reader :violations

  def on_send(node)
    _receiver, method_name = node.children

    if DANGEROUS_REFLECTION.include?(method_name)
      @violations << {
        type: :reflection_method,
        method: method_name,
        line: node.loc.line,
        severity: :high
      }
    end

    super
  end
end
```

### Combined Evasion Detection

```ruby
class ComprehensiveEvasionDetector
  def self.scan(code)
    ast = Parser::CurrentRuby.parse(code)

    detectors = [
      SendEvasionDetector.new,
      ConstGetDetector.new,
      InstanceVarDetector.new
    ]

    detectors.each { |d| d.process(ast) }

    {
      send_evasions: detectors[0].violations,
      const_get_usage: detectors[1].violations,
      reflection_methods: detectors[2].violations
    }
  rescue Parser::SyntaxError => e
    { syntax_error: e.message }
  end
end

# Usage
evasive_code = <<~RUBY
  obj.send(:eval, user_input)
  Object.const_get("Fi" + "le").read('/etc/passwd')
  instance_variable_set(:@hack, malicious_value)
RUBY

results = ComprehensiveEvasionDetector.scan(evasive_code)
results.each do |category, violations|
  puts "#{category}: #{violations.size} violations"
  violations.each do |v|
    puts "  Line #{v[:line]}: #{v[:type]} - #{v[:severity]}"
  end
end
```

---

## 5. Production Examples

### RuboCop Security Cops

RuboCop's security cops are defined in the `rubocop/cop/security/` directory. Key implementations:

#### Security/Eval

```ruby
# Simplified version of RuboCop::Cop::Security::Eval
module RuboCop
  module Cop
    module Security
      class Eval < Base
        MSG = 'The use of `eval` is a serious security risk.'

        # Matches: eval(...), binding.eval(...), Kernel.eval(...)
        def_node_matcher :eval?, <<~PATTERN
          (send
            {nil? (send nil? :binding) (const {cbase nil?} :Kernel)}
            :eval
            $!str
            ...)
        PATTERN

        def on_send(node)
          eval?(node) do |code|
            # Skip if it's an interpolated string with only literals
            return if code.dstr_type? && code.recursive_literal?

            add_offense(node.loc.selector)
          end
        end
      end
    end
  end
end
```

**Detection Pattern:**
- Uses `def_node_matcher` DSL for pattern matching
- Matches three forms: direct eval, binding.eval, Kernel.eval
- Allows literal strings but flags dynamic eval
- The `!str` means "not a string literal"

#### Security/JSONLoad

```ruby
module RuboCop
  module Cop
    module Security
      class JSONLoad < Base
        MSG = 'Prefer `JSON.parse` over `JSON.load`.'

        def_node_matcher :json_load?, <<~PATTERN
          (send
            (const {nil? cbase} :JSON)
            :load
            ...)
        PATTERN

        def on_send(node)
          json_load?(node) do
            add_offense(node.loc.selector)
          end
        end
      end
    end
  end
end
```

#### Security/Open

```ruby
module RuboCop
  module Cop
    module Security
      class Open < Base
        MSG = 'The use of `Kernel#open` is a serious security risk.'

        def_node_matcher :open?, <<~PATTERN
          (send {nil? (const {nil? cbase} :Kernel) (const {nil? cbase} :URI)} :open ...)
        PATTERN

        def on_send(node)
          open?(node) do
            add_offense(node.loc.selector)
          end
        end
      end
    end
  end
end
```

**Why dangerous:** `open("| ls")` executes shell commands!

### Brakeman Scanner

Brakeman performs deeper analysis than RuboCop, including data flow tracking.

#### Key Features:
1. **Data Flow Analysis** - Tracks user input through the application
2. **Confidence Levels** - High/Medium/Weak based on certainty
3. **Rails-Aware** - Understands Rails patterns and conventions

#### CheckUnsafeReflection

From Brakeman's source (`lib/brakeman/checks/check_unsafe_reflection.rb`):

```ruby
# Simplified conceptual implementation
class CheckUnsafeReflection < BaseCheck
  def run_check
    # Check for constantize/safe_constantize
    tracker.find_call(:method => [:constantize, :safe_constantize]).each do |result|
      check_unsafe_reflection(result, :constantize)
    end

    # Check for const_get/qualified_const_get
    tracker.find_call(:method => [:const_get, :qualified_const_get]).each do |result|
      check_unsafe_reflection(result, :const_get)
    end
  end

  def check_unsafe_reflection(result, type)
    call = result[:call]

    # Check if the argument comes from user input
    if include_user_input?(call.first_arg)
      warn :result => result,
           :warning_type => "Remote Code Execution",
           :message => "Unsafe reflection method #{type} called with user input",
           :confidence => get_confidence(call),
           :cwe_id => 470  # CWE-470: Unsafe Reflection
    end
  end

  def include_user_input?(arg)
    # Brakeman tracks whether values originate from:
    # - params[]
    # - cookies[]
    # - request.env
    # - External sources
    user_input?(arg) || has_immediate_user_input?(arg)
  end

  def get_confidence(call)
    if directly_from_params?(call.first_arg)
      :high
    elsif indirectly_from_params?(call.first_arg)
      :medium
    else
      :weak
    end
  end
end
```

**Brakeman Confidence Levels:**
- **High**: Direct unsafe usage, boolean-level warnings
- **Medium**: Unsafe variable usage, input status uncertain
- **Weak**: Indirect user input in potentially unsafe contexts

### Safe Ruby Implementation

From the safe_ruby gem:

```ruby
# Simplified conceptual implementation
class SafeRuby
  ALLOWED_CONSTANTS = %w[
    Object Array Hash String Integer Float Symbol
    TrueClass FalseClass NilClass
    Regexp Range Math
  ].freeze

  ALLOWED_METHODS = %i[
    # Basic operations
    + - * / % **
    # Comparisons
    == != < > <= >= <=>
    # Conversions
    to_s to_i to_f to_a to_h
    # Array/Hash operations
    each map select reject size length
    # String operations
    upcase downcase split join
  ].freeze

  def self.eval(code, timeout: 5)
    # Execute in separate process
    read, write = IO.pipe

    pid = fork do
      read.close

      # Set up sandbox environment
      setup_sandbox

      # Execute code with timeout
      result = Timeout.timeout(timeout) do
        evaluate_with_whitelist(code)
      end

      Marshal.dump(result, write)
      write.close
      exit!(0)
    end

    write.close
    Process.wait(pid)

    Marshal.load(read)
  rescue Timeout::Error
    raise "Execution timed out after #{timeout}s"
  ensure
    read.close unless read.closed?
    Process.kill('KILL', pid) if pid rescue nil
  end

  def self.setup_sandbox
    # Remove dangerous constants
    dangerous = Object.constants - ALLOWED_CONSTANTS
    dangerous.each { |const| Object.send(:remove_const, const) rescue nil }

    # Override dangerous methods
    Kernel.send(:define_method, :system) { |*| "system is unavailable" }
    Kernel.send(:define_method, :exec) { |*| "exec is unavailable" }
    Kernel.send(:define_method, :`) { |*| "backticks are unavailable" }
  end

  def self.evaluate_with_whitelist(code)
    # Pre-validate with AST
    validator = CodeValidator.new
    violations = validator.validate(code)

    raise SecurityError, violations.inspect if violations.any?

    # Execute in clean binding
    binding.eval(code)
  end
end
```

**Key Techniques:**
1. **Process Isolation** - Separate process for execution
2. **Timeout Protection** - Kill runaway processes
3. **Constant Whitelisting** - Remove dangerous classes
4. **Method Overriding** - Replace dangerous methods with stubs
5. **Pre-execution Validation** - AST scan before eval

---

## 6. Implementation Recommendations

### Recommended Approach for LLM-Generated Code

```ruby
class LLMCodeValidator
  # Phase 1: Syntax Check
  def self.validate(code)
    validator = new(code)
    validator.validate_syntax
    validator.validate_security
    validator.result
  end

  def initialize(code)
    @code = code
    @errors = []
    @warnings = []
    @ast = nil
  end

  attr_reader :errors, :warnings

  def result
    {
      valid: @errors.empty?,
      errors: @errors,
      warnings: @warnings,
      severity: calculate_severity
    }
  end

  # Phase 1: Syntax validation
  def validate_syntax
    @ast = Parser::CurrentRuby.parse(@code)
  rescue Parser::SyntaxError => e
    @errors << {
      type: :syntax_error,
      message: e.message,
      severity: :critical
    }
  end

  # Phase 2: Security validation
  def validate_security
    return if @ast.nil?

    # Critical blocklist (absolutely forbidden)
    check_critical_methods

    # Evasion techniques
    check_obfuscation

    # Whitelist validation (recommended methods)
    check_whitelist if @errors.empty?
  end

  private

  def check_critical_methods
    CriticalMethodDetector.new.tap do |detector|
      detector.process(@ast)
      @errors.concat(detector.violations)
    end
  end

  def check_obfuscation
    EvasionDetector.new.tap do |detector|
      detector.process(@ast)
      @errors.concat(detector.violations.select { |v| v[:severity] == :critical })
      @warnings.concat(detector.violations.select { |v| v[:severity] != :critical })
    end
  end

  def check_whitelist
    WhitelistChecker.new.tap do |checker|
      checker.process(@ast)
      @warnings.concat(checker.violations)
    end
  end

  def calculate_severity
    return :critical if @errors.any? { |e| e[:severity] == :critical }
    return :high if @errors.any?
    return :medium if @warnings.any?
    :safe
  end
end

# Critical methods (never allow)
class CriticalMethodDetector < AST::Processor
  CRITICAL = %i[
    eval instance_eval class_eval module_eval binding
    system exec spawn `` fork exit exit!
    load require require_relative autoload
  ].freeze

  def initialize
    @violations = []
  end

  attr_reader :violations

  def on_send(node)
    _receiver, method_name = node.children

    if CRITICAL.include?(method_name)
      @violations << {
        type: :critical_method,
        method: method_name,
        line: node.loc.line,
        severity: :critical,
        message: "Method '#{method_name}' is forbidden"
      }
    end

    super
  end
end

# Evasion detection
class EvasionDetector < AST::Processor
  def initialize
    @violations = []
  end

  attr_reader :violations

  def on_send(node)
    check_send_family(node)
    check_const_get(node)
    check_reflection_methods(node)
    super
  end

  private

  def check_send_family(node)
    _receiver, method_name, *args = node.children

    if %i[send __send__ public_send method].include?(method_name)
      @violations << {
        type: :dynamic_dispatch,
        method: method_name,
        line: node.loc.line,
        severity: :critical,
        message: "Dynamic method dispatch detected"
      }
    end
  end

  def check_const_get(node)
    _receiver, method_name = node.children

    if %i[const_get qualified_const_get constantize safe_constantize].include?(method_name)
      @violations << {
        type: :dynamic_constant,
        method: method_name,
        line: node.loc.line,
        severity: :critical,
        message: "Dynamic constant access can lead to RCE"
      }
    end
  end

  def check_reflection_methods(node)
    _receiver, method_name = node.children

    reflection_methods = %i[
      instance_variable_get instance_variable_set
      class_variable_get class_variable_set
      remove_const remove_method undef_method
      define_method define_singleton_method
    ]

    if reflection_methods.include?(method_name)
      @violations << {
        type: :reflection,
        method: method_name,
        line: node.loc.line,
        severity: :high,
        message: "Reflection method can bypass security"
      }
    end
  end
end

# Whitelist checker
class WhitelistChecker < AST::Processor
  SAFE_METHODS = %i[
    + - * / % **
    == != < > <= >= <=>
    to_s to_i to_f to_a to_h inspect
    size length count empty? nil? any? all?
    each map select reject filter compact uniq
    sort reverse shuffle first last
    upcase downcase capitalize strip chomp
    split join gsub sub match
    abs round ceil floor
    keys values merge fetch dig
  ].freeze

  SAFE_CLASSES = %w[
    String Integer Float Array Hash
    Time Date DateTime
    TrueClass FalseClass NilClass
    Range Regexp Math
  ].freeze

  def initialize
    @violations = []
  end

  attr_reader :violations

  def on_send(node)
    receiver, method_name = node.children

    # Skip safe methods
    return super if SAFE_METHODS.include?(method_name)

    # Check if calling on safe class
    if receiver&.type == :const
      const_name = receiver.children.last.to_s
      return super if SAFE_CLASSES.include?(const_name)
    end

    # Flag potentially unsafe method
    @violations << {
      type: :unknown_method,
      method: method_name,
      line: node.loc.line,
      severity: :medium,
      message: "Method '#{method_name}' not in whitelist"
    }

    super
  end

  def on_const(node)
    const_name = node.children.last.to_s

    unless SAFE_CLASSES.include?(const_name)
      @violations << {
        type: :unknown_constant,
        constant: const_name,
        line: node.loc.line,
        severity: :medium,
        message: "Constant '#{const_name}' not in whitelist"
      }
    end

    super
  end
end
```

### Usage Example

```ruby
# Validate LLM-generated code
llm_code = <<~RUBY
  numbers = [1, 2, 3, 4, 5]
  result = numbers.map { |n| n * 2 }.select { |n| n > 5 }
  result.join(", ")
RUBY

result = LLMCodeValidator.validate(llm_code)

if result[:valid]
  puts "Code is safe to execute"
  # Execute in sandbox
else
  puts "Code validation failed:"
  result[:errors].each do |error|
    puts "  #{error[:severity].upcase}: #{error[:message]} (line #{error[:line]})"
  end
end

# Dangerous code example
dangerous_code = <<~RUBY
  user_input = gets
  eval(user_input)  # CRITICAL
  File.read('/etc/passwd')  # Not in whitelist
RUBY

result = LLMCodeValidator.validate(dangerous_code)
# => errors: [
#      {type: :critical_method, method: :eval, severity: :critical, ...},
#      {type: :unknown_constant, constant: "File", severity: :medium, ...}
#    ]
```

### Performance Considerations

**Parser Selection:**
- **Ripper**: 2.75x faster, use for high-throughput validation
- **Parser gem**: More convenient API, better for complex analysis
- **Prism** (Ruby 3.4+): Best of both worlds - fast AND convenient

**Optimization Tips:**
```ruby
# Cache parsed AST if validating multiple times
class CachedValidator
  def initialize(code)
    @code = code
    @ast = Parser::CurrentRuby.parse(code)
  end

  def validate_security
    # Run multiple detectors on cached AST
    [
      CriticalMethodDetector.new,
      EvasionDetector.new,
      WhitelistChecker.new
    ].flat_map { |d| d.process(@ast); d.violations }
  end
end

# Parallel validation for multiple code snippets
require 'parallel'

codes = [code1, code2, code3]
results = Parallel.map(codes) { |code| LLMCodeValidator.validate(code) }
```

### Integration with Agent Framework

```ruby
class SafeCodeExecutor
  def self.execute(llm_generated_code, timeout: 5)
    # Step 1: Validate
    validation = LLMCodeValidator.validate(llm_generated_code)

    unless validation[:valid]
      return {
        success: false,
        error: "Code validation failed",
        details: validation[:errors]
      }
    end

    # Step 2: Execute in sandbox
    result = SafeRuby.eval(llm_generated_code, timeout: timeout)

    {
      success: true,
      result: result,
      warnings: validation[:warnings]
    }
  rescue SecurityError => e
    {
      success: false,
      error: "Security violation during execution",
      message: e.message
    }
  rescue Timeout::Error
    {
      success: false,
      error: "Execution timeout",
      message: "Code exceeded #{timeout}s time limit"
    }
  rescue StandardError => e
    {
      success: false,
      error: "Runtime error",
      message: e.message,
      backtrace: e.backtrace.first(5)
    }
  end
end
```

---

## Summary & Best Practices

### Key Takeaways

1. **Use Parser Gem** (or Prism for Ruby 3.4+) over Ripper for security scanning
   - More convenient API
   - Better for complex pattern matching
   - Widely used in production tools

2. **Prefer Whitelist over Blacklist**
   - Blacklisting is nearly impossible to do safely
   - Whitelisting is more secure by default
   - Hybrid approach for practical implementations

3. **Multi-Layer Defense**
   - AST validation (pre-execution)
   - Process isolation (during execution)
   - Timeout protection (resource limits)

4. **Watch for Evasion Techniques**
   - String concatenation: `"ev" + "al"`
   - Dynamic dispatch: `send(:eval)`
   - Constant manipulation: `const_get(:File)`
   - Reflection: `instance_variable_get`

5. **Learn from Production Tools**
   - RuboCop: Pattern matching with node matchers
   - Brakeman: Data flow tracking and confidence levels
   - safe_ruby: Process isolation and whitelisting

### Critical Methods to Block

```ruby
ALWAYS_BLOCK = %i[
  eval instance_eval class_eval module_eval binding
  system exec spawn `` fork exit exit!
  send __send__ public_send method
  const_get qualified_const_get constantize safe_constantize
  load require require_relative autoload
  instance_variable_get instance_variable_set
  class_variable_get class_variable_set
  remove_const remove_method undef_method
  define_method define_singleton_method
  Marshal ObjectSpace
]
```

### Safe Methods for LLM Code

```ruby
SAFE_FOR_LLM = %i[
  # Arithmetic
  + - * / % **
  # Comparison
  == != < > <= >= <=>
  # Type conversion
  to_s to_i to_f to_a to_h inspect
  # Collection operations
  each map select reject filter compact uniq
  sort sort_by reverse shuffle
  first last take drop
  size length count empty? any? all? none?
  # String operations
  upcase downcase capitalize strip chomp
  split join slice concat
  gsub sub match scan
  # Hash operations
  keys values merge dig fetch
  # Numeric operations (via Math)
  abs round ceil floor sqrt
]
```

### Recommended Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     LLM Code Generation                     │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
         ┌────────────────────────┐
         │   Syntax Validation    │ ◄── Parser gem / Prism
         │   (Parse to AST)       │
         └────────┬───────────────┘
                  │
                  ▼
         ┌────────────────────────┐
         │  Security Validation   │
         ├────────────────────────┤
         │ 1. Critical Blocklist  │ ◄── Block eval, system, etc.
         │ 2. Evasion Detection   │ ◄── Detect send, const_get, etc.
         │ 3. Whitelist Check     │ ◄── Allow safe methods only
         └────────┬───────────────┘
                  │
                  ▼
            ┌─────────┐
            │ Valid?  │
            └────┬────┘
                 │
        ┌────────┴────────┐
        │                 │
       NO                YES
        │                 │
        ▼                 ▼
   ┌─────────┐    ┌──────────────────┐
   │ Reject  │    │  Execute in      │
   │ & Log   │    │  Sandbox         │
   └─────────┘    │  (Process        │
                  │   Isolation      │
                  │   + Timeout)     │
                  └──────────────────┘
```

---

## Sources

### Documentation
- [Ruby Ripper Documentation](https://rubyreferences.github.io/rubyref/stdlib/development/ripper.html)
- [Parser Gem Repository](https://github.com/whitequark/parser)
- [RuboCop AST Documentation](https://docs.rubocop.org/rubocop-ast/)
- [Ruby Security Documentation](https://docs.ruby-lang.org/en/3.2/security_rdoc.html)

### Performance Benchmarks
- [Rewriting the Ruby Parser](https://railsatscale.com/2023-06-12-rewriting-the-ruby-parser/)
- [Benchmarking Ruby Parsers](https://eregon.me/blog/2024/10/27/benchmarking-ruby-parsers.html)

### Security Tools
- [RuboCop Security Cops](https://docs.rubocop.org/rubocop/cops_security.html)
- [Brakeman Security Scanner](https://brakemanscanner.org/)
- [Safe Ruby Sandbox](https://github.com/ukutaht/safe_ruby)

### Security Research
- [Ruby Unsafe Reflection Vulnerabilities](https://www.praetorian.com/blog/ruby-unsafe-reflection-vulnerabilities/)
- [Brakeman Remote Code Execution](https://brakemanscanner.org/docs/warning_types/remote_code_execution/)
- [Ruby Security Guide](https://rubyreferences.github.io/rubyref/advanced/security.html)

### Static Analysis
- [Static Analysis in Ruby - RubyGuides](https://www.rubyguides.com/2015/08/static-analysis-in-ruby/)
- [Using Ruby Parser and AST](https://blog.arkency.com/using-ruby-parser-and-ast-tree-to-find-deprecated-syntax/)
- [Custom Static Analysis Rules](https://blog.includesecurity.com/2021/01/custom-static-analysis-rules-showdown-brakeman-vs-semgrep/)
