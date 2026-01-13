require_relative "../concerns/result_formatting"

module Smolagents
  module Tools
    # A chainable, Enumerable wrapper for tool outputs that enables fluent data transformations.
    #
    # ToolResult wraps any data returned from a tool execution, providing a rich API for
    # filtering, transforming, and formatting the data. All transformation methods return
    # new ToolResult instances, enabling method chaining while preserving immutability.
    #
    # @example Creating results
    #   # Wrap array data
    #   result = ToolResult.new([{name: "Alice"}, {name: "Bob"}], tool_name: "list_users")
    #
    #   # Wrap a single value
    #   result = ToolResult.new("Hello, world!", tool_name: "greet")
    #
    #   # Create an empty result
    #   result = ToolResult.empty(tool_name: "search")
    #
    #   # Create an error result
    #   result = ToolResult.error("Connection timeout", tool_name: "fetch_data")
    #
    # @example Chaining operations (fluent API)
    #   users = ToolResult.new(
    #     [{name: "Alice", age: 30}, {name: "Bob", age: 25}, {name: "Carol", age: 35}],
    #     tool_name: "list_users"
    #   )
    #
    #   # Filter, sort, and limit
    #   young_users = users.select { |u| u[:age] < 32 }.sort_by { |u| u[:age] }.take(2)
    #   # => ToolResult with [{name: "Bob", age: 25}, {name: "Alice", age: 30}]
    #
    #   # Extract specific fields
    #   names = users.pluck(:name)
    #   # => ToolResult with ["Alice", "Bob", "Carol"]
    #
    #   # Map transformations
    #   greetings = users.map { |u| "Hello, #{u[:name]}!" }
    #   # => ToolResult with ["Hello, Alice!", "Hello, Bob!", "Hello, Carol!"]
    #
    # @example Pattern matching (Ruby 3.0+)
    #   result = some_tool.call(query: "test")
    #
    #   case result
    #   in ToolResult[data: Array, empty?: false]
    #     puts "Got #{result.size} items"
    #   in ToolResult[error?: true]
    #     puts "Error: #{result.metadata[:error]}"
    #   in ToolResult[data: nil]
    #     puts "No data returned"
    #   end
    #
    # @example Output formats
    #   items = ToolResult.new(
    #     [{title: "Ruby Guide", pages: 200}, {title: "Rails Tutorial", pages: 350}],
    #     tool_name: "list_books"
    #   )
    #
    #   # Markdown (default for to_s)
    #   puts items.as_markdown
    #   # **1.** **title:** Ruby Guide, **pages:** 200
    #   # **2.** **title:** Rails Tutorial, **pages:** 350
    #
    #   # ASCII table
    #   puts items.as_table
    #   # title          | pages
    #   # ---------------+------
    #   # Ruby Guide     | 200
    #   # Rails Tutorial | 350
    #
    #   # JSON
    #   puts items.to_json
    #   # [{"title":"Ruby Guide","pages":200},{"title":"Rails Tutorial","pages":350}]
    #
    #   # Bullet list
    #   puts items.as_list
    #   # - title: Ruby Guide, pages: 200
    #   # - title: Rails Tutorial, pages: 350
    #
    # @example Composition (combining results)
    #   users = ToolResult.new([{name: "Alice"}], tool_name: "users")
    #   admins = ToolResult.new([{name: "Bob"}], tool_name: "admins")
    #
    #   # Concatenate results
    #   all_people = users + admins
    #   # => ToolResult with [{name: "Alice"}, {name: "Bob"}]
    #
    # @example Error handling
    #   result = ToolResult.error("API rate limit exceeded", tool_name: "fetch")
    #
    #   if result.error?
    #     puts "Failed: #{result.metadata[:error]}"
    #   end
    #
    #   # Error results are empty but still chainable
    #   result.empty?  # => true
    #   result.take(5) # => ToolResult (empty, safe to chain)
    #
    # @example Aggregations
    #   sales = ToolResult.new([{amount: 100}, {amount: 200}, {amount: 150}], tool_name: "sales")
    #
    #   sales.average { |s| s[:amount] }  # => 150.0
    #   sales.min { |a, b| a[:amount] <=> b[:amount] }  # => {amount: 100}
    #   sales.max { |a, b| a[:amount] <=> b[:amount] }  # => {amount: 200}
    #
    # @see Tool The base class that produces ToolResult instances
    # @see Concerns::ResultFormatting Output formatting methods (as_markdown, as_table, etc.)
    # @see LazyToolResult Streaming/lazy evaluation variant for large datasets
    #
    # @!attribute [r] data
    #   @return [Object] The wrapped data (frozen). Can be Array, Hash, String, or any value.
    # @!attribute [r] tool_name
    #   @return [String] Name of the tool that produced this result.
    # @!attribute [r] metadata
    #   @return [Hash] Metadata including :created_at, :error, :success, :op, :parent.
    class ToolResult
      include Enumerable
      include Concerns::ResultFormatting

      attr_reader :data, :tool_name, :metadata

      # Creates a new ToolResult wrapping the given data.
      #
      # @param data [Object] The data to wrap (will be deep-frozen)
      # @param tool_name [String, Symbol] Name of the tool that produced this result
      # @param metadata [Hash] Additional metadata to attach
      # @option metadata [Time] :created_at Automatically set to current time
      # @option metadata [Boolean] :success Whether the operation succeeded
      # @option metadata [String] :error Error message if operation failed
      # @return [ToolResult] A new immutable result instance
      def initialize(data, tool_name:, metadata: {})
        @data = deep_freeze(data)
        @tool_name = tool_name.to_s.freeze
        @metadata = metadata.merge(created_at: Time.now).freeze
      end

      # @!group Enumerable Methods

      # Iterates over each element in the result.
      #
      # @yield [Object] Each element in the data
      # @return [Enumerator] If no block given
      # @return [self] If block given
      def each(&)
        return enum_for(:each) { size } unless block_given?

        enumerable_data.each(&)
      end

      # Returns the number of elements in the result.
      #
      # @return [Integer] Element count (0 for nil, 1 for scalar values)
      def size
        case @data
        when Array, Hash then @data.size
        when nil then 0
        else 1
        end
      end
      alias length size
      alias count size

      # @!endgroup

      # @!group Chainable Transformations
      # Methods that return new ToolResult instances, enabling method chaining.

      # Dynamically define chainable methods that delegate to the underlying data.
      # @!method select(&block)
      #   Filters elements matching the block.
      #   @yield [Object] Each element
      #   @return [ToolResult] New result with matching elements
      # @!method reject(&block)
      #   Filters elements not matching the block.
      #   @yield [Object] Each element
      #   @return [ToolResult] New result without matching elements
      # @!method compact
      #   Removes nil values from the result.
      #   @return [ToolResult] New result without nil values
      # @!method uniq
      #   Removes duplicate values.
      #   @return [ToolResult] New result with unique values
      # @!method reverse
      #   Reverses the order of elements.
      #   @return [ToolResult] New result with reversed order
      # @!method flatten
      #   Flattens nested arrays.
      #   @return [ToolResult] New result with flattened data
      %i[select reject compact uniq reverse flatten].each do |method|
        define_method(method) { |*args, &block| chain(method) { block ? @data.public_send(method, *args, &block) : @data.public_send(method, *args) } }
      end
      alias filter select

      # Transforms each element using the given block.
      #
      # @yield [Object] Each element to transform
      # @yieldreturn [Object] The transformed value
      # @return [ToolResult] New result with transformed data
      def map(&) = chain(:map) { @data.is_a?(Array) ? @data.map(&) : yield(@data) }
      alias collect map

      # Maps each element and flattens the result one level.
      #
      # @yield [Object] Each element
      # @yieldreturn [Array] Array of values to flatten
      # @return [ToolResult] New result with flattened mapped data
      def flat_map(&) = chain(:flat_map) { @data.flat_map(&) }

      # Sorts elements by the value returned from the block.
      #
      # @yield [Object] Each element
      # @yieldreturn [Comparable] Value to sort by
      # @return [ToolResult] New result with sorted data
      def sort_by(&) = chain(:sort_by) { @data.sort_by(&) }

      # Sorts elements using the given comparison block or default ordering.
      #
      # @yield [Object, Object] Two elements to compare
      # @yieldreturn [Integer] -1, 0, or 1
      # @return [ToolResult] New result with sorted data
      def sort(&block) = chain(:sort) { block ? @data.sort(&block) : @data.sort }

      # Returns the first n elements.
      #
      # @param count [Integer] Number of elements to take
      # @return [ToolResult] New result with first n elements
      def take(count) = chain(:take) { @data.take(count) }

      # Drops the first n elements.
      #
      # @param count [Integer] Number of elements to drop
      # @return [ToolResult] New result without first n elements
      def drop(count) = chain(:drop) { @data.drop(count) }

      # Takes elements while the block returns true.
      #
      # @yield [Object] Each element
      # @yieldreturn [Boolean] Whether to continue taking
      # @return [ToolResult] New result with taken elements
      def take_while(&) = chain(:take_while) { @data.take_while(&) }

      # Drops elements while the block returns true.
      #
      # @yield [Object] Each element
      # @yieldreturn [Boolean] Whether to continue dropping
      # @return [ToolResult] New result without dropped elements
      def drop_while(&) = chain(:drop_while) { @data.drop_while(&) }

      # Groups elements by the value returned from the block.
      #
      # @yield [Object] Each element
      # @yieldreturn [Object] The grouping key
      # @return [ToolResult] New result with Hash of grouped data
      def group_by(&) = chain(:group_by) { @data.group_by(&) }

      # Partitions elements into two results based on the block.
      #
      # @yield [Object] Each element
      # @yieldreturn [Boolean] Whether element belongs in first partition
      # @return [Array<ToolResult, ToolResult>] Two results: matching and non-matching
      def partition(&)
        matching, non_matching = @data.partition(&)
        [self.class.new(matching, tool_name: @tool_name, metadata: { parent: @metadata[:created_at], op: :partition }),
         self.class.new(non_matching, tool_name: @tool_name, metadata: { parent: @metadata[:created_at], op: :partition })]
      end

      # Extracts a specific key from each Hash element.
      #
      # @param key [Symbol, String] The key to extract
      # @return [ToolResult] New result with extracted values
      # @example
      #   users.pluck(:name) # => ToolResult with ["Alice", "Bob"]
      def pluck(key) = chain(:pluck) { @data.map { |item| item.is_a?(Hash) ? (item[key] || item[key.to_s]) : item } }

      # @!endgroup

      # @!group Aggregation Methods

      # Returns the minimum element.
      #
      # @yield [Object, Object] Optional comparison block
      # @return [Object] The minimum element
      def min(&) = enumerable_data.min(&)

      # Returns the maximum element.
      #
      # @yield [Object, Object] Optional comparison block
      # @return [Object] The maximum element
      def max(&) = enumerable_data.max(&)

      # Calculates the average of numeric values.
      #
      # @yield [Object] Optional block to extract numeric value from each element
      # @return [Float] The average value (0.0 if empty)
      # @example
      #   sales.average { |s| s[:amount] }  # => 150.0
      def average(&block)
        items = enumerable_data
        return 0.0 if items.empty?

        (block ? items.map(&block) : items).then { |values| values.sum.to_f / values.size }
      end

      # @!endgroup

      # @!group Element Access

      # Returns the first element(s).
      #
      # @overload first
      #   @return [Object] The first element
      # @overload first(count)
      #   @param count [Integer] Number of elements
      #   @return [ToolResult] New result with first n elements
      def first(count = nil) = count ? take(count) : enumerable_data.first

      # Returns the last element(s).
      #
      # @overload last
      #   @return [Object] The last element
      # @overload last(count)
      #   @param count [Integer] Number of elements
      #   @return [ToolResult] New result with last n elements
      def last(count = nil) = count ? chain(:last) { @data.last(count) } : enumerable_data.last

      # Navigates nested data structures.
      #
      # @param keys [Array<String, Symbol, Integer>] Keys/indices to navigate
      # @return [Object, nil] The value at the path, or nil if not found
      # @example
      #   result.dig(:users, 0, :name)  # => "Alice"
      def dig(*keys)
        @data.dig(*keys)
      rescue TypeError, NoMethodError => e
        warn "[ToolResult#dig] failed to navigate path #{keys.inspect}: #{e.class} - #{e.message}" if $DEBUG
        nil
      end

      # @!endgroup

      # @!group Status Methods

      # Returns true if the result contains no data.
      #
      # @return [Boolean] Whether the result is empty
      def empty? = @data.nil? || (@data.respond_to?(:empty?) && @data.empty?)

      # Returns true if the result contains a specific value.
      #
      # @param value [Object] The value to check for
      # @return [Boolean] Whether the value is present
      def include?(value) = (@data.respond_to?(:include?) && @data.include?(value)) || (error? && @metadata[:error].to_s.include?(value.to_s))
      alias member? include?

      # Returns true if this result represents an error.
      #
      # @return [Boolean] Whether this is an error result
      def error? = @metadata[:success] == false || @metadata.key?(:error)

      # Returns true if this result represents a successful operation.
      #
      # @return [Boolean] Whether this is a success result
      def success? = !error?

      # @!endgroup

      # @!group Conversion Methods

      # Converts the result to an Array.
      #
      # @return [Array] Array representation of the data
      def to_a
        case @data
        when Array then @data.dup
        when Hash then @data.to_a
        when nil then []
        else [@data]
        end
      end
      alias to_ary to_a

      # Converts the result to a Hash with full metadata.
      #
      # @return [Hash] Hash with :data, :tool_name, and :metadata keys
      def to_h = { data: @data, tool_name: @tool_name, metadata: @metadata }
      alias to_hash to_h

      # Returns a string representation (Markdown format).
      #
      # @return [String] Markdown-formatted string
      # @see #as_markdown
      def to_s = as_markdown
      alias to_str to_s

      # Returns the data for JSON serialization.
      #
      # @return [Object] The raw data suitable for JSON encoding
      def as_json(*) = @data

      # Returns a developer-friendly string representation.
      #
      # @return [String] Inspect string showing class, tool name, and data preview
      def inspect
        preview = case @data
                  when Array then "[#{@data.size} items]"
                  when Hash then "{#{@data.size} keys}"
                  when String then @data.length > 40 ? "\"#{@data[0..37]}...\"" : @data.inspect
                  else @data.inspect.then { |str| str.length > 40 ? "#{str[0..37]}..." : str }
                  end
        "#<#{self.class} tool=#{@tool_name} data=#{preview}>"
      end

      # @!endgroup

      # @!group Pattern Matching

      # Enables array-style pattern matching.
      #
      # @return [Array] Array representation for pattern matching
      # @example
      #   case result
      #   in [first, *rest] then process(first, rest)
      #   end
      def deconstruct = to_a

      # Enables hash-style pattern matching.
      #
      # @param keys [Array<Symbol>, nil] Keys to extract (nil for all)
      # @return [Hash] Hash with requested keys for pattern matching
      # @example
      #   case result
      #   in ToolResult[data: Array, error?: false]
      #     puts "Success with array data"
      #   end
      def deconstruct_keys(keys) = { data: @data, tool_name: @tool_name, metadata: @metadata, empty?: empty?, error?: error? }.then { |hash| keys ? hash.slice(*keys) : hash }

      # @!endgroup

      # @!group Comparison

      # Compares two ToolResults or a ToolResult with raw data.
      #
      # @param other [ToolResult, Object] The object to compare
      # @return [Boolean] True if data and tool_name match (for ToolResult) or data matches
      def ==(other) = other.is_a?(ToolResult) ? @data == other.data && @tool_name == other.tool_name : @data == other
      alias eql? ==

      # Returns a hash code for use in Hash keys.
      #
      # @return [Integer] Hash code based on data and tool_name
      def hash = [@data, @tool_name].hash

      # @!endgroup

      # @!group Composition

      # Concatenates two ToolResults into a new combined result.
      #
      # @param other [ToolResult] The result to append
      # @return [ToolResult] New result with combined data
      # @example
      #   combined = result1 + result2
      def +(other)
        self.class.new(to_a + other.to_a, tool_name: "#{@tool_name}+#{other.tool_name}", metadata: { combined_from: [@tool_name, other.tool_name] })
      end

      # @!endgroup

      # @!group Factory Methods

      # Creates an empty ToolResult.
      #
      # @param tool_name [String] Name of the tool
      # @return [ToolResult] Empty result with no data
      def self.empty(tool_name: "unknown") = new([], tool_name: tool_name)

      # Creates an error ToolResult.
      #
      # @param error [Exception, String] The error or error message
      # @param tool_name [String] Name of the tool that failed
      # @param metadata [Hash] Additional metadata
      # @return [ToolResult] Error result with :error and :success metadata
      # @example
      #   ToolResult.error("Connection timeout", tool_name: "api_fetch")
      #   ToolResult.error(StandardError.new("failed"), tool_name: "process")
      def self.error(error, tool_name: "unknown", metadata: {})
        message = error.is_a?(Exception) ? "#{error.class}: #{error.message}" : error.to_s
        new(nil, tool_name: tool_name, metadata: metadata.merge(error: message, success: false))
      end

      # @!endgroup

      private

      # Converts data to an enumerable form.
      #
      # @return [Array, Hash] Enumerable version of the data
      def enumerable_data
        case @data
        when Array, Hash then @data
        when nil then []
        else [@data]
        end
      end

      # Creates a new ToolResult from a transformation, preserving lineage.
      #
      # @param operation [Symbol] Name of the operation performed
      # @yield Block that computes the new data
      # @return [ToolResult] New result with transformed data
      def chain(operation) = self.class.new(yield, tool_name: @tool_name, metadata: { parent: @metadata[:created_at], op: operation })

      # Deep-freezes an object to ensure immutability.
      #
      # @param obj [Object] The object to freeze
      # @return [Object] The frozen object
      def deep_freeze(obj)
        case obj
        when Array then obj.map { |item| deep_freeze(item) }.freeze
        when Hash then obj.transform_values { |val| deep_freeze(val) }.freeze
        when String then obj.frozen? ? obj : obj.dup.freeze
        else begin
          obj.freeze
        rescue FrozenError, TypeError => e
          warn "[ToolResult#deep_freeze] cannot freeze #{obj.class}: #{e.message}" if $DEBUG
          obj
        end
        end
      end
    end
  end

  # Re-export ToolResult at the Smolagents level for backward compatibility.
  # @see Smolagents::Tools::ToolResult
  ToolResult = Tools::ToolResult
end
