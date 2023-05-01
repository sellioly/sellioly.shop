class ApplicationController < ActionController::Base
  protect_from_forgery with: :null_session

  def content_not_found
    render file: "#{Rails.root}/public/404.html", layout: true, status: :not_found
    # render  json: {domain: "not found! #{@domain}  #{@cname.inspect}"}
    true
  end

  def internal_server_error
    render file: "#{Rails.root}/public/500.html", layout: true, status: :not_found
    true
  end

  def check_store
    @domain = request.host
    @cname = Resolv::DNS.new.getresource(@domain, Resolv::DNS::Resource::IN::CNAME) rescue nil
    if @cname
      @cname = @cname.name.to_s
      @response = HTTP.post("https://api.sellioly.com/server/domain/verify", :form => { 'domain' => @domain, 'app_domain' => @cname })
      unless @response.status.success?
        content_not_found
        return false
      end
      @domain = @cname
    elsif not (@domain =~ /^[A-za-z0-9-.]+.sellioly.com$/)
      content_not_found
      return false
    end

    @store = Store.where(app_domain: @domain).first
    if @store
      $shop_id = @store.shop_id
      $template_id = @store.template_id
    end

    true
  end
  
  def page_not_found
    @path = Rails.root.to_s + @store.template_path.to_s
    Liquid::Template.file_system = Liquid::LocalFileSystem.new(@path, '%s.liquid')

    @response = HTTP.post("https://api.sellioly.com/server/store/infos", :form => { 'app_domain' => @domain })
    unless (@response.status.success?)
      internal_server_error
      return
    end

    @data = @response.parse
    @shop_name = @data['shop_name']
    @currency = @data['currency']
    @shop_description = @data['shop_description']
    @logo = (@data['shop_logo_default'])
    args = {}
    args['logo'] = @logo
    args['shop_name'] = @shop_name
    args['currency'] = @currency
    args['page_title'] = "HOME - #{@shop_name}"
    args['shop_description'] = @shop_description

    @response = HTTP.post("https://api.sellioly.com/server/menu/get-by-handle", :form => { 'handle' => 'main-menu', 'user_id' => $shop_id, 'app_domain' => @domain })
    args['menu'] = nil
    if @response.status.success?
      args['menu'] = @response.parse
    end

    @not_found_page = Liquid::Template.parse(File.read(@path + '/sections/notfound.liquid'))
    @content_for_layout = @not_found_page.render(args)


    @template = Liquid::Template.parse(File.read(@path + '/layout/theme.liquid')) # Parses and compiles the template
    @origin = request.base_url
    args['content_for_layout'] = @content_for_layout
    args['request'] = { 'origin' => @origin }
    @test = @template.render(args)
    render html: @test.html_safe
    return
  end

end
