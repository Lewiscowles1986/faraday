module Faraday
  # Possibly going to extend this a bit.
  #
  # Faraday::Connection.new(:url => 'http://sushi.com') do |b|
  #   b.request  :yajl     # Faraday::Request::Yajl
  #   b.adapter  :logger   # Faraday::Adapter::Logger
  #   b.response :yajl     # Faraday::Response::Yajl
  # end
  class Builder
    attr_accessor :handlers

    def self.create_with_inner_app(&block)
      inner = lambda do |env| 
        if !env[:parallel_manager]
          env[:response].finish(env)
        else
          env[:response]
        end
      end
      Builder.new(&block).tap { |builder| builder.run(inner) }
    end

    def initialize(handlers = [])
      @handlers = handlers
      yield self if block_given?
    end

    def run(app)
      @handlers.unshift app
    end

    def to_app
      inner_app = @handlers.first
      @handlers[1..-1].inject(inner_app) { |app, middleware| middleware.call(app) }
    end

    def use(klass, *args, &block)
      @handlers.unshift(lambda { |app| klass.new(app, *args, &block) })
    end

    def request(key, *args, &block)
      use_symbol Faraday::Request, key, *args, &block
    end

    def response(key, *args, &block)
      use_symbol Faraday::Response, key, *args, &block
    end

    def adapter(key, *args, &block)
      use_symbol Faraday::Adapter, key, *args, &block
    end

    def use_symbol(mod, key, *args, &block)
      use mod.lookup_module(key), *args, &block
    end

    def ==(other)
      other.is_a?(self.class) && @handlers == other.handlers
    end

    def dup
      self.class.new @handlers.dup
    end
  end
end