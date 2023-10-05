# frozen_string_literal: true
require 'liquid'

class SectionTag < Liquid::Tag
  def initialize(tag_name, markup, options)
    super

    @name = markup.strip.remove("'").split(',')[0]
    unless @name =~ /(.+?)(\.[^.]*$|$)/
      "Illegal template name '#{@name}'"
    end

    @attributes = {}
    markup.scan(Liquid::TagAttributes) do |key, value|
      @attributes[key] = parse_expression(value)
    end
  end

  def render(context)
    new_context = context.environments.first

    if new_context.key?('section') and new_context['section']
      return "cannot render section inside other section "
    end
    if  new_context.key?('layout_data') and new_context['layout_data']
      new_context['section'] = new_context['layout_data'][@name]
    end
    full_path = Liquid::Template.file_system.root + "/sections/" + @name + ".liquid"
    unless File.exist?(full_path)
      return "No such '#{@name}' in section folder!"
    end
    # Remember here we are not passing extension
    content = File.read(full_path)

    new_context['params'] = {}
    @attributes.each do |key, value|
      new_context['params'][key] = context.evaluate(value)
    end


    content = Liquid::Template.parse(content).render(new_context).html_safe
    new_context.delete('section')
    content
  end

end
