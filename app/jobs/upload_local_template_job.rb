require "http"

class UploadLocalTemplateJob < ApplicationJob
  queue_as :default

  def perform(shop_path, app_domain, sub_path)
    # Do something later
    unless File.directory?(shop_path)
      FileUtils.mkdir_p(shop_path)
    end

    @path = Rails.root.to_s + ("/storage/template/default")
    FileUtils.copy_entry @path, shop_path

    file = File.read(shop_path + '/config/settings_schema.json')
    @data = JSON.load file
    @theme_name = @data['theme_name'].to_s
    @theme_version = @data['theme_version'].to_s
    @theme_author = @data['theme_author'].to_s
    @theme_support_url = @data['theme_support_url'].to_s


    @response = HTTP.post("https://api.sellioly.com/server/template-created", :form => { 'app_domain' => app_domain, 'template_path' => sub_path, 'theme_name' => @theme_name, 'theme_version' => @theme_version, 'theme_author' => @theme_author, 'theme_support_url' => @theme_support_url })
  end
end