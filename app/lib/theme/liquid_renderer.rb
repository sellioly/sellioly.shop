# frozen_string_literal: true

module Theme
  # Renders templates with a per-request file system, guarding the global
  # Liquid::Template.file_system by setting and restoring around the render
  # call under a mutex. This is a pragmatic compromise given Liquid's API.
  class LiquidRenderer
    def initialize
      @mutex = Monitor.new
    end

    # Render a compiled template with assigns, using the given theme's file system.
    def render(compiled_template, assigns:, theme_store: nil, registers: {})
      return "" unless compiled_template
      
      fs = theme_store&.file_system || Liquid::Template.file_system

      @mutex.synchronize do
        previous = Liquid::Template.file_system
        begin
          Liquid::Template.file_system = fs

          compiled_template.render(assigns, registers: registers)
        ensure
          Liquid::Template.file_system = previous
        end
      end
    end

    def safe_render(compiled_template, assigns:, theme_store: nil, registers: {})
      render(compiled_template, assigns: assigns, theme_store: theme_store, registers: registers)
    rescue Liquid::InternalError => e
      cause = e.cause || e
      Rails.logger.error({
        at:   "liquid_render",
        err:  cause.class.name,
        msg:  cause.message,
        bt:   Array(cause.backtrace).take(10)
      }.to_json)
      raise
    rescue => e
      Rails.logger.error({ at: "liquid_render", err: e.class.name, msg: e.message, bt: Array(e.backtrace).take(10) }.to_json)
      raise
    end

    def self.render_mutex
      @render_mutex ||= Mutex.new
    end
  end
end
