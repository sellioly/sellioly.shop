# app/utils/translation_util.rb

module TranslationUtil
  def self.translate(key, locale = :en)
    translation_data = load_translation_data(locale)
    key.split('.').reduce(translation_data) do |data, subkey|
      data.is_a?(Hash) ? data[subkey] : nil
    end
  end

  private

  def self.load_translation_data(locale)
    translation_file_path = Rails.root.join('config', 'locales', "#{locale}.json")
    JSON.parse(File.read(translation_file_path))[locale.to_s]
  rescue StandardError
    {}
  end
end