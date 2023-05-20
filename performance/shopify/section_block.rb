# frozen_string_literal: true
require 'liquid'

class SectionBlock < Liquid::Tag
  def initialize(tag_name, markup, options)
    super

    @name = markup.strip.remove("'")
  end

  def full_path(template_path)

    if template_path.include?('/')
                  File.join(Liquid::Template.file_system.root, File.dirname(template_path), Liquid::Template.file_system.pattern % File.basename(template_path))
                else
                  File.join(Liquid::Template.file_system.root, Liquid::Template.file_system.pattern % template_path)
                end
  end

  def render(context)
    new_context = context.environments.first
    full_path = full_path('sections/' + @name + ".liquid")
    return full_path
    # Remember here we are not passing extension
    content = File.read(full_path)

    Liquid::Template.parse(content).render(new_context).html_safe
  end

end
