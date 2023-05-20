# frozen_string_literal: true
require 'liquid'

class SectionBlock < Liquid::Tag
  def initialize(tag_name, markup, options)
    super

    @name = markup.strip.remove("'")
  end

  def full_path(template_path)
    raise FileSystemError, "Illegal template name '#{template_path}'" unless %r{\A[^./][a-zA-Z0-9-_/]+\z}.match?(template_path)

    full_path = if template_path.include?('/')
                  File.join(Liquid::Template.file_system.root, File.dirname(template_path), Liquid::Template.file_system.pattern % File.basename(template_path))
                else
                  File.join(Liquid::Template.file_system.root, Liquid::Template.file_system.pattern % template_path)
                end

    raise FileSystemError, "Illegal template path '#{File.expand_path(full_path)}'" unless File.expand_path(full_path).start_with?(File.expand_path(root))

    full_path
  end

  def render(context)
    new_context = context.environments.first

    # Remember here we are not passing extension
    content = File.read(full_path('sections/' + @name + ".liquid"))

    Liquid::Template.parse(content).render(new_context).html_safe
  end

end
