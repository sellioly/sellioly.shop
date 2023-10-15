# frozen_string_literal: true
require 'json'
require 'liquid'

module TFilter
  def t(key)
    locale = 'en'

    file = File.read(Liquid::Template.file_system.root + '/config/settings_data.json')
    settings_data = JSON.load file

    if settings_data['presets'][settings_data['current']]['language']
      locale = settings_data['presets'][settings_data['current']]['language']['settings']['locale']
    end
    translation_data = load_translation_data(locale)
    value = key.split('.').reduce(translation_data) do |data, subkey|
      puts data
      puts subkey
      data.is_a?(Hash) ? data[subkey] : nil
    end

    puts value

    value
  rescue => e
    puts e.message
  end

  private

  def load_translation_data(locale)
    translation_file_path = Liquid::Template.file_system.root + "/locales/" + locale + ".json"
    file = File.read(translation_file_path)
    JSON.load file
  rescue => e
    puts e.message
  end
end
