class UploadLocalTemplateJob < ApplicationJob
  queue_as :default

  def perform(shop_path, app_domain)
    # Do something later
    unless File.directory?(shop_path)
      FileUtils.mkdir_p(shop_path)
    end

    @path = Rails.root.to_s + ("/storage/template/default")
    FileUtils.copy_entry @path, shop_path

    response = HTTParty.post("https://api.sellioly.com/server/template-created",
                             :body => { :app_domain => app_domain, :template_path => shop_path }.to_json,
                             :headers => { 'Content-Type' => 'application/json' })
  end
end