require "zip"

class GetTemplateFromAwsJob < ApplicationJob
  queue_as :default

  def perform(shop_id, template_id, url_theme)
    @response = Faraday.get(url_theme)

    @zip_buffer = @response.body
    zipfile = ::Zip::File.open_buffer(@zip_buffer)
    if zipfile
      @error = []
      settings_templates = zipfile.find_entry("config/settings_templates.json")

      # settings_assets = zipfile.find_entry("config/settings_assets.json")
      # unless settings_assets
      #   @error.push('config/settings_assets.json is missing!')
      # end\


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
        @sub_path = "/storage/#{shop_id}/#{template_id}"
        @path = Rails.root.to_s + @sub_path

        unless File.directory?(@path)
          FileUtils.mkdir_p(@path)
        end

        unless File.directory?(@path + '/assets')
          FileUtils.mkdir_p(@path + '/assets')

          zipfile.glob('assets/*.css').each do
          |entry|
            entry.extract(@path + '/' + entry.name)
          end

          zipfile.glob('assets/*.js').each do
          |entry|
            entry.extract(@path + '/' + entry.name)
          end
        end

        unless File.directory?(@path + '/assets/fonts')
          FileUtils.mkdir_p(@path + '/assets/fonts')
          extentions = %w[eot ttf woff woff2]

          extentions.each do |ext|
            zipfile.glob('assets/fonts/*.' + ext).each do
            |entry|
              entry.extract(@path + '/' + entry.name)
            end
          end
        end

        unless File.directory?(@path + '/config')
          FileUtils.mkdir_p(@path + '/config')
          zipfile.glob('config/*.json').each do
          |entry|
            next unless %w[config/settings_templates.json config/settings_theme.json config/settings_data.json config/settings_schema.json].include? entry.name
            entry.extract(@path + '/' + entry.name)
          end
        end

        unless File.directory?(@path + '/layout')
          FileUtils.mkdir_p(@path + '/layout')
          zipfile.glob('layout/*.liquid').each do
          |entry|
            entry.extract(@path + '/' + entry.name)
          end
        end

        unless File.directory?(@path + '/layout')
          zipfile.glob('layout/*.json').each do
          |entry|
            entry.extract(@path + '/' + entry.name)
          end
        end

        unless File.directory?(@path + '/locales')
          FileUtils.mkdir_p(@path + '/locales')
          zipfile.glob('locales/*.json').each do
          |entry|
            entry.extract(@path + '/' + entry.name)
          end
        end

        unless File.directory?(@path + '/schemas')
          FileUtils.mkdir_p(@path + '/schemas')
          zipfile.glob('schemas/*.json').each do
          |entry|
            entry.extract(@path + '/' + entry.name)
          end
        end

        unless File.directory?(@path + '/sections')
          FileUtils.mkdir_p(@path + '/sections')
          zipfile.glob('sections/*.liquid').each do
          |entry|
            entry.extract(@path + '/' + entry.name)
          end
        end

        unless File.directory?(@path + '/snippets')
          FileUtils.mkdir_p(@path + '/snippets')
          zipfile.glob('snippets/*.liquid').each do
          |entry|
            entry.extract(@path + '/' + entry.name)
          end
        end

        unless File.directory?(@path + '/templates')
          FileUtils.mkdir_p(@path + '/templates')
          zipfile.glob('templates/*.json').each do
          |entry|
            entry.extract(@path + '/' + entry.name)
          end
        end

        file = File.read(@path + '/config/settings_theme.json')
        @data = JSON.load file
        @theme_name = @data['theme_name']
        @theme_version = @data['theme_version']
        @theme_author = @data['theme_author']
        @theme_support_url = @data['theme_support_url']

        @response = HTTP.post("https://api.sellioly.com/server/template-uploaded/success",
                              :form => { 'user_id' => shop_id, 'template_id' => template_id, 'template_path' => @sub_path, 'theme_name' => @theme_name, 'theme_version' => @theme_version, 'theme_author' => @theme_author, 'theme_support_url' => @theme_support_url })
      else
        @response = HTTP.post("https://api.sellioly.com/server/template-uploaded/failed",
                              :form => { 'user_id' => shop_id, 'template_id' => template_id, 'reason' => @error })
      end
    else
      @error = ['Cannot open your zip file!']
      @response = HTTP.post("https://api.sellioly.com/server/template-uploaded/failed",
                            :form => { 'user_id' => shop_id, 'template_id' => template_id, 'reason' => @error })
    end
  end
end
