# frozen_string_literal: true

module Theme
  # Renders templates with a per-request file system, guarding the global
  # Liquid::Template.file_system by setting and restoring around the render
  # call under a mutex. This is a pragmatic compromise given Liquid's API.
  class LiquidRenderer
    def initialize
      @mutex = self.class.render_mutex
    end

    # Render a compiled template with assigns, using the given theme's file system.
    def render(compiled_template, assigns:, theme_store:)
      return "" unless compiled_template
      fs = theme_store.file_system

      @mutex.synchronize do
        previous = Liquid::Template.file_system
        begin
          Liquid::Template.file_system = fs
          compiled_template.render(assigns)
        ensure
          Liquid::Template.file_system = previous
        end
      end
    end

    def self.render_mutex
      @render_mutex ||= Mutex.new
    end
  end
end
