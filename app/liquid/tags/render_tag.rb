# frozen_string_literal: true
require 'liquid'
require_relative '../support/sellioly_liquid_tag_support'

# Best-practice: render looks in snippets/ by default.
class RenderTag < Liquid::Tag
  include SelliolyLiquidTagSupport

  def initialize(tag_name, markup, options)
    super
    @name = extract_name(markup)
    @attributes = parse_attributes(markup)
  end

  def render(context)
    env = env_from(context)
    new_ctx = context.environments.first.dup
    new_ctx['params'] = build_params(context, @attributes)

    rel = File.join('snippets', "#{@name}.liquid")

    guard_include_depth!(context, env)
    begin
      render_liquid_file(context, rel, assigns_extra: new_ctx)
    ensure
      unguard_include_depth(context, env)
    end
  end
end
