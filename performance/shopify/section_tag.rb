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

    if new_context.key?('section')
      return "cannot render section inside other section " + new_context.inspect
    end
    new_context['section'] = context['layout_data'][@name]
    puts new_context['section']
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
