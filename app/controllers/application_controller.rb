# app/controllers/application_controller.rb (method body replacement)
def initialize_shop
  ctx, failure = Shops::ShopContext.new.resolve!(host: request.host, cookies: cookies)
  if failure
    case failure.type
    when :not_found then content_not_found
    else internal_server_error
    end
    return
  end

  @domain       = ctx.domain
  @shop_id      = ctx.shop_id
  @template_id  = ctx.template_id
  @path         = ctx.theme_path
  @args         = ctx.base_args
end
