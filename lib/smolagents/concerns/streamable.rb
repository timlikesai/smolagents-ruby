module Smolagents
  module Concerns
    module Streamable
      def stream(&) = Enumerator.new(&).lazy

      def stream_fiber(&) = Fiber.new(&)

      def safe_stream(on_error: :skip)
        Enumerator.new do |yielder|
          catch(:stop_stream) do
            yield(yielder)
          rescue StandardError => e
            case on_error
            when :skip then nil
            when :stop then throw(:stop_stream)
            when Proc then on_error.call(e)
            else raise
            end
          end
        end.lazy
      end

      def merge_streams(*streams)
        Enumerator.new { |yielder| streams.flat_map(&:to_a).each { |item| yielder << item } }.lazy
      end

      def transform_stream(stream, &) = stream.lazy.map(&)
      def filter_stream(stream, &) = stream.lazy.select(&)
      def take_until(stream) = stream.lazy.take_while { |item| !yield(item) }
      def batch_stream(stream, size:) = stream.lazy.each_slice(size)
      def collect_stream(stream) = stream.to_a
      def tap_stream(stream, &) = stream.lazy.tap(&)
    end
  end
end
