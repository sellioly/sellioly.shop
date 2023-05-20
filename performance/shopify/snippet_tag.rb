# frozen_string_literal: true
require 'liquid'

class SnippetTag < Liquid::Tag
  def initialize(tag_name, markup, options)
    super

    @name = markup.strip.remove("'")
  end

  def render(context)
    new_context = context.environments.first
    full_path = Liquid::Template.file_system.root + "/snippets/" + @name + ".liquid"
    # Remember here we are not passing extension
    content = File.read(full_path)

    Liquid::Template.parse(content).render(new_context).html_safe
  end

end
