require "zip"

class VerifyThemeJob < ApplicationJob
  queue_as :default

  def perform(url_theme)
    @response = Faraday.get(url_theme)

    @zip_buffer = @response.body
    zipfile = ::Zip::File.open_buffer(@zip_buffer)
    if zipfile
      @error = []
      settings_templates = zipfile.find_entry("config/settings_templates.json")


      settings_theme = zipfile.find_entry("config/settings_theme.json")
      unless settings_theme
        @error.push('config/settings_theme.json is missing!')
      end

      settings_data = zipfile.find_entry("config/settings_data.json")
      unless settings_data
        @error.push('config/settings_data.json is missing!')
      end

      settings_schema = zipfile.find_entry("config/settings_schema.json")
      unless settings_schema
        @error.push('config/settings_schema.json is missing!')
      end

      layout_theme = zipfile.find_entry("layout/theme.liquid")
      unless layout_theme
        @error.push('layout/theme.liquid is missing!')
      end

      json_theme = zipfile.find_entry("layout/theme.json")
      unless json_theme
        @error.push('layout/theme.json is missing!')
      end

      assets_folder = zipfile.find_entry("assets")
      unless assets_folder
        @error.push('assets folder is missing!')
      end

      locales_folder = zipfile.find_entry("locales")
      unless locales_folder
        @error.push('locales folder is missing!')
      end

      schemas_folder = zipfile.find_entry("schemas")
      unless schemas_folder
        @error.push('schemas folder is missing!')
      end

      section_folder = zipfile.find_entry("sections")
      unless section_folder
        @error.push('sections folder is missing!')
      end

      snippets_folder = zipfile.find_entry("snippets")
      unless snippets_folder
        @error.push('snippets folder is missing!')
      end

      templates_folder = zipfile.find_entry("templates")
      unless templates_folder
        @error.push('templates folder is missing!')
      end

      if @error.length <= 0

        file = File.read(@path + '/config/settings_theme.json')
        @data = JSON.load file
        @theme_name = @data['theme_name']
        @theme_version = @data['theme_version']
        @theme_author = @data['theme_author']
        @theme_support_url = @data['theme_support_url']

        @response = HTTP.post("https://api.sellioly.com/server/verify-theme",
                              :form => { 'status' => 'success', 'url_theme' => url_theme, 'data' => { 'theme_name' => @theme_name, 'theme_version' => @theme_version, 'theme_author' => @theme_author, 'theme_support_url' => @theme_support_url } })
      else
        @response = HTTP.post("https://api.sellioly.com/server/verify-theme",
                              :form => { 'status' => 'failed', 'url_theme' => url_theme, 'reason' => @error })
      end
    else
      @error = ['Cannot open your zip file!']
      @response = HTTP.post("https://api.sellioly.com/server/verify-theme",
                            :form => { 'status' => 'failed', 'url_theme' => url_theme, 'reason' => @error })
    end
  end
end
