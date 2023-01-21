class ApplicationController < ActionController::Base
  protect_from_forgery with: :null_session
  def content_not_found
    render file: "#{Rails.root}/public/404.html", layout: true, status: :not_found
  end

  def internal_server_error
    render file: "#{Rails.root}/public/500.html", layout: true, status: :not_found
  end

  def check_store
    @domain = request.host
    @store = Store.where(app_domain: @domain).first
    unless @store
      content_not_found
      return
    end
    $shop_id = @store.shop_id
    $template_id = @store.template_id
  end
end
