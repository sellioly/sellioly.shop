# frozen_string_literal: true
require 'liquid'
class SectionBlock < Liquid::Tag
  def initialize(tag_name, markup, options)
    super

    @name = markup.strip.remove("'")
  end

  def render(context)
    new_context = context.environments.first

    # Remember here we are not passing extension
    content = Liquid::Template.file_system.read_template_file('sections/' + @name + ".liquid")

    Liquid::Template.parse(content).render(new_context).html_safe
  end

end
