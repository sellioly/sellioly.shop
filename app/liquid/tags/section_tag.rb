# frozen_string_literal: true
require 'liquid'
require_relative '../support/sellioly_liquid_tag_support'

module Tags
  class SectionTag < Liquid::Tag
    include Support::SelliolyLiquidTagSupport

    def initialize(tag_name, markup, options)
      super
      @name = extract_name(markup)
      @attributes = parse_attributes(markup)
    end

    def render(context)
      env = env_from(context)
      new_ctx = context.environments.first.dup

      if new_ctx.key?('section') && new_ctx['section']
        return render_missing(env, "sections/#{@name}.liquid", message: 'Cannot render a section inside another section')
      end

      if (ld = new_ctx['layout_data']).is_a?(Hash)
        new_ctx['section'] = ld[@name]
      end

      new_ctx['params'] = build_params(context, @attributes)

      rel = File.join('sections', "#{@name}.liquid")

      guard_include_depth!(context, env)
      begin
        html = render_liquid_file(context, rel, assigns_extra: new_ctx)
      ensure
        new_ctx.delete('section')
        unguard_include_depth(context, env)
      end

      html
    end
  end
end
