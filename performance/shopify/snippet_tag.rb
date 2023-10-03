# frozen_string_literal: true
require 'liquid'

class SnippetTag < Liquid::Tag
  def initialize(tag_name, markup, options)
    super

    @name = markup.strip.remove("'")
    unless @name =~ /(.+?)(\.[^.]*$|$)/
      raise "Illegal template name '#{@name}'"
    end

    @attrs = {}
    markup.scan(Liquid::TagAttributes) do |key, value|
      @attrs[key] = parse_expression(value)
    end
    puts @attrs

  end

  def render(context)
    new_context = context.environments.first
    full_path = Liquid::Template.file_system.root + "/snippets/" + @name + ".liquid"
    unless File.exist?(full_path)
      raise "No such '#{@name}' in section folder!"
    end
    # Remember here we are not passing extension
    content = File.read(full_path)

    puts @attrs

    new_context['params'] = @attrs
    Liquid::Template.parse(content).render(new_context).html_safe
  end

end
