# frozen_string_literal: true
require 'liquid'

class SectionTag < Liquid::Tag
  def initialize(tag_name, markup, options)
    super

    @name = markup.strip.remove("'")
    unless @name =~ /(.+?)(\.[^.]*$|$)/
      "Illegal template name '#{@name}'"
    end
  end

  def render(context)
    new_context = context.environments.first

    if context.key?('section')
      return "cannot render section inside other section "
    end
    new_context.stack do
      new_context['section'] = new_context['layout_data'][@name]
    end
    full_path = Liquid::Template.file_system.root + "/sections/" + @name + ".liquid"
    unless File.exist?(full_path)
      return "No such '#{@name}' in section folder!"
    end
    # Remember here we are not passing extension
    content = File.read(full_path)

    Liquid::Template.parse(content).render(new_context).html_safe
    new_context.delete('section')
  end

end
