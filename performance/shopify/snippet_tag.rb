# frozen_string_literal: true
require 'liquid'

class SnippetTag < Liquid::Tag
  def initialize(tag_name, markup, options)
    super

    @name = markup.strip.remove("'")
    unless @name =~ /(.+?)(\.[^.]*$|$)/
      raise "Illegal template name '#{@name}'"
    end
  end

  def render(context)
    new_context = context.environments.first
    full_path = @liquid_instance.file_system.root + "/snippets/" + @name + ".liquid"
    unless File.exist?(full_path)
      raise "No such '#{@name}' in section folder!"
    end
    # Remember here we are not passing extension
    content = File.read(full_path)

    @liquid_instance.parse(content).render(new_context).html_safe
  end

end
