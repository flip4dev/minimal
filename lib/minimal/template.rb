class Minimal::Template
  autoload :FormBuilderProxy, 'minimal/template/form_builder_proxy'
  autoload :Handler,          'minimal/template/handler'

  AUTO_BUFFER = %r(render|tag|error_message_|select|debug|_to|_for)

  TAG_NAMES = %w(a body div em fieldset h1 h2 h3 h4 head html img input label li
    ol option p pre script select span strong table thead tbody tfoot td th tr ul
    title)

  EMPTY_TAG_NAMES = %w(link meta hr)

  module Base
    attr_accessor :view, :locals

    def initialize(view = nil)
      @view, @locals, @_buffer = view, {}, {}
    end

    def _render(locals = nil)
      @locals = locals || {}
      content
      view.output_buffer
    end

    TAG_NAMES.each do |name|
      module_eval(<<-"END")
        def #{name}(*args, &block)
          content_tag(:#{name}, *args, &block)
        end
      END

      module_eval(<<-"END")
        def #{name}_for(*args, &block)
          content_tag_for(:#{name}, *args, &block)
        end
      END

      # does not work in jruby 1.4.0 -> throws syntax error
      # define_method(name) { |*args, &block| content_tag(name, *args, &block) }
      # define_method("#{name}_for") { |*args, &block| content_tag_for(name, *args, &block) }
    end

    EMPTY_TAG_NAMES.each do |name|
      module_eval(<<-"END")
        def #{name}(*args)
          tag(:#{name}, *args)
        end
      END
    end

    if Rails.env.development?
      def <<(output)
        view.output_buffer << output.to_s << "\n"
      end
    else
      def <<(output)
        view.output_buffer << output.to_s
      end
    end

    def respond_to?(method)
      view.respond_to?(method) || locals.key?(method) || view.instance_variable_defined?("@#{method}")
    end

    def raw_text(output = nil, &block)
      view.output_buffer << (block_given? ? capture(&block) : output).to_s.html_safe
    end

    protected

      def method_missing(method, *args, &block)
        locals.key?(method) ? locals[method] :
          view.instance_variable_defined?("@#{method}") ? view.instance_variable_get("@#{method}") :
          view.respond_to?(method) ? call_view(method, *args, &block) : super
      end

      def call_view(method, *args, &block)
        view.send(method, *args, &block).tap { |result| self << result if auto_buffer?(method) }
      end

      def auto_buffer?(method)
        @_buffer.key?(method) ? @_buffer[method] : @_buffer[method] = AUTO_BUFFER =~ method.to_s
      end
  end
  include Base
end