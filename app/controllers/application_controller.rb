class ApplicationController < ActionController::Base
  protect_from_forgery with: :null_session

  def content_not_found
    render file: "#{Rails.root}/public/404.html", layout: true, status: :not_found
    # render  json: {domain: "not found! #{@domain}  #{@cname.inspect}"}
  end

  def internal_server_error
    render file: "#{Rails.root}/public/500.html", layout: true, status: :not_found
  end

  def check_store
    @domain = request.host
    @cname = Resolv::DNS.new.getresource(@domain, Resolv::DNS::Resource::IN::CNAME) rescue nil
    if @cname
      @cname = @cname.name.to_s
    end

    @response = HTTP.post("https://api.sellioly.com/server/domain/verify", :form => { 'domain' => @domain, 'app_domain' => @cname })
    unless @response.status.success?
      content_not_found
      return
    end

    if @cname
      @domain = @cname.name.to_s
    end

    @store = Store.where(app_domain: @domain).first
    if @store
      $shop_id = @store.shop_id
      $template_id = @store.template_id
    end
  end
end
