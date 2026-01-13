module Smolagents
  module Types
    Goal.define_method(:method_missing) do |name, *args, &block|
      return super(name) unless name.to_s.start_with?("expect_")

      key = name.to_s.delete_prefix("expect_").to_sym
      val = args.first || block
      expect(key => val)
    end

    Goal.define_method(:respond_to_missing?) do |name, include_private = false|
      name.to_s.start_with?("expect_") || super(name, include_private)
    end
  end
end
