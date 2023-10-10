# frozen_string_literal: true
require 'liquid'

module TFilter
  def t(key)
    locale = 'en'
    translation_data = load_translation_data(locale)
    value = key.split('.').reduce(translation_data) do |data, subkey|
      data.is_a?(Hash) ? data[subkey] : nil
    end

    puts value

    return value
  end

  private

  def self.load_translation_data(locale)
    translation_file_path = Liquid::Template.file_system.root.join('locales', "#{locale}.default.json")
    puts translation_file_path
    JSON.parse(File.read(translation_file_path))[locale.to_s]
  rescue StandardError
    {}
  end

end
