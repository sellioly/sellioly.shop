# frozen_string_literal: true
require 'liquid'

module TFilter
  def t(key)
    puts key
    path = Liquid::Template.file_system.root + "/locales/en.default.json"

    puts path

    translation = TranslationUtil.translate(key)
    puts translation

    return translation
  end
end
