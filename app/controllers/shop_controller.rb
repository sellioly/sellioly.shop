class ShopController < ApplicationController
  protect_from_forgery except: :file_assets
  before_action :initialize_shop, except: [:preview, :file_assets, :file_font_assets, :page]

  def index
    render_page('index.json')
  end

  def file_assets
    @path = Rails.root.to_s + '/storage/' + params[:shop_id] + '/' + params[:template_id]
    unless File.directory?(@path)
      content_not_found
      return
    end

    $shop_id = params[:shop_id]
    $template_id = params[:template_id]

    unless File.exist?(@path + '/assets/' + params[:filename])
      content_not_found
      return
    end
    expires_in 24.hours, :public => true
    render file: @path + '/assets/' + params[:filename], status: 200
  end

  def file_font_assets
    @path = Rails.root.to_s + '/storage/' + params[:shop_id] + '/' + params[:template_id]
    unless File.directory?(@path)
      content_not_found
      return
    end

    $shop_id = params[:shop_id]
    $template_id = params[:template_id]

    unless File.exist?(@path + '/assets/fonts/' + params[:filename])
      content_not_found
      return
    end
    expires_in 24.hours, :public => true
    render file: @path + '/assets/fonts/' + params[:filename], status: 200
  end

  public def preview

    headers['Access-Control-Allow-Origin'] = '*'
    headers['Access-Control-Allow-Methods'] = 'GET, OPTIONS'
    headers['Access-Control-Request-Method'] = '*'
    headers['Access-Control-Allow-Headers'] = 'Origin, X-Requested-With, Content-Type, Accept, Authorization'

    @path = Rails.root.to_s + '/storage/' + params[:shop_id] + '/' + params[:template_id]
    unless File.directory?(@path)
      content_not_found
      return
    end

    $shop_id = params[:shop_id]
    $template_id = params[:template_id]

    Liquid::Template.file_system = Liquid::LocalFileSystem.new(@path, '%s.liquid')

    response = HTTP.post("https://api.sellioly.com/server/store/infos", :form => { 'user_id' => params[:shop_id] })
    unless response.status.success?
      internal_server_error
      return
    end

    data = response.parse
    shop_name = data['shop_name']
    shop_description = data['shop_description']
    currency = data['currency']
    logo = (data['shop_logo_default'])

    @args = {}
    @args['page_title'] = "HOME - #{shop_name}"
    @args['shop_name'] = shop_name
    @args['shop_description'] = shop_description
    @args['currency'] = currency
    @args['logo'] = logo

    # get cart -------------------------------------
    if cookies[:cart_id].present?
      puts '------------------------------------------------'
      puts '---------------- cart_id cookie ----------------'
      puts '------------------------------------------------'
      cart = Cart.find_by(cart_id: cookies[:cart_id])
      if cart
        @args['cart'] = cart.as_json
      else
        new_cart = Cart.new({})
        new_cart.cart_id = cookies[:cart_id]
        new_cart.items = []
        new_cart.subtotal = 0
        new_cart.save
        @args['cart'] = new_cart.as_json
      end
    end

    render_page('index.json')
  end

  public def page
    unless request.format.html?
      content_not_found
      return
    end


    unless check_store
      return
    end

    unless @store
      content_not_found
      return
    end

    page_not_found
  end

  public def product
    response = HTTP.post("https://api.sellioly.com/server/product/get-by-handle", :form => { 'handle' => params[:product], 'user_id' => $shop_id, 'app_domain' => @domain })
    if response.status.success?
      @args['product'] = response.parse
    else
      page_not_found
      return
    end

    render_page('product.json')
    return
  end

  public def collection
    response = HTTP.post("https://api.sellioly.com/server/collection/get-by-handle", :form => { 'handle' => params[:collection], 'user_id' => $shop_id, 'app_domain' => @domain })
    @args['collection'] = nil
    if response.status.success?
      @args['collection'] = response.parse
      response = HTTP.post("https://api.sellioly.com/server/product/get-by-collection", :form => { 'handle' => params[:collection], 'user_id' => $shop_id, 'app_domain' => @domain })
      @args['collection']['products'] = nil
      if response.status.success?
        @args['collection']['products'] = response.parse
      end
    else
      page_not_found
      return
    end

    render_page('collection.json')
    return
  end

  public def checkout
    render_page('checkout.json')
    nil
  end

  private


  def render_section(section_id)
    unless File.file? @path + '/sections/' + section_id + '.liquid'
      return ''
    end

    template = Liquid::Template.parse(File.read(@path + '/sections/' + section_id + '.liquid'))
    template.render(@args)
  end

end
