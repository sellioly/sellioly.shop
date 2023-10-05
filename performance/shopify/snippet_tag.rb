# frozen_string_literal: true
require 'liquid'

class SnippetTag < Liquid::Tag
  def initialize(tag_name, markup, options)
    super

    begin
      @name = markup.strip.remove("'").split(',')[0]
      unless @name =~ /(.+?)(\.[^.]*$|$)/
        raise "Illegal template name '#{@name}'"
      end

      @attributes = {}
      markup.scan(Liquid::TagAttributes) do |key, value|
        @attributes[key] = parse_expression(value)
      end
    rescue => e
      puts e.message
    end
  end

  def render(context)
    begin
      new_context = context.environments.first

      full_path = Liquid::Template.file_system.root + "/snippets/" + @name + ".liquid"
      unless File.exist?(full_path)
        raise "No such '#{@name}' in section folder!"
      end
      # Remember here we are not passing extension
      content = File.read(full_path)
      new_context['params'] = @attributes


      new_context['params'] = {}
      @attributes.each do |key, value|
        new_context['params'][key] = context.evaluate(value)
      end

      Liquid::Template.parse(content).render(new_context).html_safe
    rescue => e
      puts e.message
    end
  end

end
