class StoreController < ApplicationController

  include StoreHelper
  # before_action :verify_ssl_hook

  public def create
    # code here
    @store = Store.new({})
    @store.app_domain = params[:app_domain]
    @store.template_id = params[:template_id].to_i
    @store.shop_id = params[:shop_id].to_i

    @subpath = "/storage/" + @store.shop_id.to_s + "/" + @store.template_id.to_s
    @path = Rails.root.to_s + @subpath
    @store.template_path = @subpath
    @store.save

    cert = LetsEncrypt::Certificate.find_by(domain: params[:app_domain])
    unless cert
      cert = LetsEncrypt::Certificate.create(domain: params[:app_domain]) rescue nil
      cert.get if cert

      LetsEncrypt::RenewCertificatesJob.perform_later
    end

    UploadLocalTemplateJob.perform_later @path, @store.app_domain, @subpath

    endpoint = "collection/get-by-handle"
    response = HTTP.post("https://api.sellioly.com/ruby/#{endpoint}", :form => { 'handle' => 'all', 'user_id' => @store.shop_id, 'app_domain' => @store.app_domain })
    if response.status.success?
      response_string = response.body.to_s
      redis_set(@store.app_domain, @store.shop_id, "collection:all", response_string)

      # return response.parse
    end

    # upload local file template  /app/storage/63/28/config/settings_schema.json

    render json: { msg: 'Template in progress', id: @store.id, template_path: @subpath }
  end

end
