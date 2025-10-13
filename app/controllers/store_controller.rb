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

  public

  def process_event
    event = params[:event]
    operation = params[:operation]
    handle_param = params[:handle]
    app_domain = params[:app_domain]
    shop_id = params[:shop_id].to_s
    event_id = event == 'metadata' ? 'meta_id' : 'shop_id'

    # Check for valid operations
    unless %w[update insert delete].include?(operation)
      render json: { error: "Invalid operation: #{operation}" }, status: :unprocessable_entity
      return
    end

    # Check for valid events
    unless %w[product menu collection metadata shop].include?(event)
      render json: { error: "Invalid event: #{event}" }, status: :unprocessable_entity
      return
    end

    if operation == 'delete'
      # Handle deletion for all types
      redis_del(app_domain, event == 'shop' ? -1 : shop_id, "#{event}:#{handle_param}")
      message = event == 'shop' ? "Deleting #{event} with domain #{app_domain}" : "Deleting #{event} with handle #{handle_param}"
      render json: { message: message }
      return
    end

    # Set handle and endpoint based on event
    handle, endpoint = case event
                       when 'product', 'menu', 'collection'
                         [handle_param, "#{event}/get-by-handle"]
                       when 'metadata'
                         [nil, "metadata/store/list"]
                       when 'shop'
                         [nil, "store/infos"]
                       else
                         [nil, nil]
                       end

    # Make an HTTP request to the appropriate endpoint
    response = HTTP.post("https://api.sellioly.com/ruby/#{endpoint}", form: { 'handle' => handle, event_id => shop_id, 'app_domain' => app_domain })
    if response.status.success?
      response_string = response.body.to_s
      if event === "shop"
        redis_set(-1, shop_id, "shop", response_string)
      else
        redis_set(app_domain,  shop_id, "#{event}:#{handle_param}", response_string)
      end
      message = "Synchronized #{event} with #{handle ? 'handle' : 'domain'} #{handle || app_domain}"
      render json: { message: message }
    else
      render json: { error: "unsuccessful api #{endpoint}" }, status: :unprocessable_entity
    end
  end

end
