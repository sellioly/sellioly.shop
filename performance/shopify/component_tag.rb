# frozen_string_literal: true
require 'liquid'

class ComponentTag < Liquid::Tag
  def initialize(tag_name, markup, options)
    super

    @name = markup.strip.remove("'")
    unless @name =~ /(.+?)(\.[^.]*$|$)/
      raise "Illegal template name '#{@name}'"
    end

    @attributes = {}
    markup.scan(TagAttributes) do |key, value|
      @attributes[key] = parse_expression(value)
    end

  end

  def render(context)
    new_context = @attributes
    full_path = Liquid::Template.file_system.root + "/components/" + @name + ".liquid"
    unless File.exist?(full_path)
      raise "No such '#{@name}' in components folder!"
    end
    # Remember here we are not passing extension
    content = File.read(full_path)

    Liquid::Template.parse(content).render(new_context).html_safe
  end

end
