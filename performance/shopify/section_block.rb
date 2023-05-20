# frozen_string_literal: true

class SectionBlock < Liquid::Block
  def initialize(tag_name, markup, options)
    super

    @name = markup.strip.remove("'")
  end

  def render(context)
    new_context = context.environments.first

    # Remember here we are not passing extension
    asset = Template.partial.find_by(filename: 'sections/' + @name + ".liquid")

    Liquid::Template.parse(asset.content).render(new_context).html_safe
  end

end
