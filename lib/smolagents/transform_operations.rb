module Smolagents
  module TransformOperations
    OPERATIONS = {
      "select" => ->(data, op) { data.select { |i| matches?(i, op) } },
      "reject" => ->(data, op) { data.reject { |i| matches?(i, op) } },
      "sort_by" => ->(data, op) { data.sort_by { |i| fetch_key(i, op) } },
      "take" => ->(data, op) { data.take(op[:count] || op["count"] || 10) },
      "drop" => ->(data, op) { data.drop(op[:count] || op["count"] || 0) },
      "uniq" => ->(data, op) { op[:key] || op["key"] ? data.uniq { |i| fetch_key(i, op) } : data.uniq },
      "pluck" => ->(data, op) { data.map { |i| fetch_key(i, op) } }
    }.freeze

    COMPARISON_OPS = { "=" => :==, "==" => :==, "!=" => :!=, ">" => :>, "<" => :<, ">=" => :>=, "<=" => :<= }.freeze

    class << self
      def apply(data, operations)
        operations.reduce(data) do |result, op|
          type = op[:type] || op["type"]
          handler = OPERATIONS[type]
          handler ? handler.call(result, op) : result
        end
      end

      def matches?(item, operation)
        cond = operation[:condition] || operation["condition"]
        return true unless cond

        field = cond[:field] || cond["field"]
        compare_op = cond[:op] || cond["op"] || "="
        value = cond.key?(:value) ? cond[:value] : cond["value"]
        item_val = item.is_a?(Hash) ? (item[field] || item[field.to_s] || item[field.to_sym]) : item
        (method = COMPARISON_OPS[compare_op]) ? item_val.send(method, value) : true
      end

      def fetch_key(item, operation)
        key = operation[:key] || operation["key"]
        item[key] || item[key.to_sym]
      end
    end
  end
end
