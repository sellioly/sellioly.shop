# frozen_string_literal: true
require 'liquid'

class SectionTag < Liquid::Tag
  def initialize(tag_name, markup, options)
    super

    @name = markup.strip.remove("'")
    unless @name =~ /(.+?)(\.[^.]*$|$)/
      return "Illegal template name '#{@name}'"
    end
  end

  def render(context)
    new_context = context.environments.first
    return self.inspect
    full_path = Liquid::Template.file_system.root + "/sections/" + @name + ".liquid"
    unless File.exist?(full_path)
      return "No such '#{@name}' in section folder!"
    end
    # Remember here we are not passing extension
    content = File.read(full_path)

    Liquid::Template.parse(content).render(new_context).html_safe
  end

end
