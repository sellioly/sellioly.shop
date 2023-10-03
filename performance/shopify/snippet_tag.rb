# frozen_string_literal: true
require 'liquid'

class SnippetTag < Liquid::Tag
  def initialize(tag_name, markup, options)
    super
    puts markup
    @name = markup.strip.remove("'")
    puts @name
    unless @name =~ /(.+?)(\.[^.]*$|$)/
      raise "Illegal template name '#{@name}'"
    end

    @attributes = {}
    markup.scan(Liquid::TagAttributes) do |key, value|
      @attributes[key] = parse_expression(value)
    end
    puts @attributes

  end

  def render(context)
    begin

      puts @name
      new_context = context.environments.first
      puts new_context
      full_path = Liquid::Template.file_system.root + "/snippets/" + @name + ".liquid"
      unless File.exist?(full_path)
        raise "No such '#{@name}' in section folder!"
      end
      # Remember here we are not passing extension
      content = File.read(full_path)

      puts @attributes


      new_context['params'] = @attributes
      Liquid::Template.parse(content).render(new_context).html_safe

    rescue => e
      puts e.message
    end
  end

end
