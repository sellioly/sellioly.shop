# frozen_string_literal: true
require 'liquid'

class RenderTag < Liquid::Tag
  def initialize(tag_name, markup, options)
    super

    @name = markup.strip.remove("'").split(',')[0]
    unless @name =~ /(.+?)(\.[^.]*$|$)/
      raise "Illegal template name '#{@name}'"
    end

    @attributes = {}
    markup.scan(Liquid::TagAttributes) do |key, value|
      @attributes[key] = parse_expression(value)
      @attributes["#{key}_test"] = value
    end

    puts(@attributes)

  end

  def render(context)
    new_context = context.environments.first
    full_path = Liquid::Template.file_system.root + "/sections/" + @name + ".liquid"
    unless File.exist?(full_path)
      raise "No such '#{@name}' in section folder!"
    end
    # Remember here we are not passing extension
    content = File.read(full_path)

    new_context['params'] = @attributes
    Liquid::Template.parse(content).render(new_context).html_safe
  end

end
