class ShopController < ApplicationController
  protect_from_forgery except: :file_assets
  before_action :initialize_shop

  def index
    unless check_store
      return
    end

    unless @store
      content_not_found
      return
    end

    @path = Rails.root.to_s + @store.template_path.to_s
    Liquid::Template.file_system = Liquid::LocalFileSystem.new(@path, '%s.liquid')

    @response = HTTP.post("https://api.sellioly.com/server/store/infos", :form => { 'app_domain' => @domain })
    unless (@response.status.success?)
      internal_server_error
      return
    end
    @content_for_layout = ''

    file = File.read(@path + '/templates/index.json')
    data = JSON.load file

    @data = @response.parse
    @shop_name = @data['shop_name']
    @currency = @data['currency']
    @shop_description = @data['shop_description']
    @logo = (@data['shop_logo_default'])
    args = {}
    args['logo'] = @logo
    args['shop_name'] = @shop_name

    @response = HTTP.post("https://api.sellioly.com/server/menu/get-by-handle", :form => { 'handle' => 'main-menu', 'user_id' => $shop_id, 'app_domain' => @domain })
    args['menu'] = nil
    if @response.status.success?
      args['menu'] = @response.parse
    end
    args['currency'] = @currency
    args['page_title'] = "HOME - #{@shop_name}"
    args['shop_description'] = @shop_description
    if data["order"].kind_of?(Array)
      data["order"].each { |section_id|
        section_data = data["sections"][section_id]
        section_settings = section_data['settings']
        section_blocks = []
        if section_data['block_order'].kind_of?(Array)
          section_data['block_order'].each { |block_id|
            section_blocks.push(section_data['blocks'][block_id])
          }
        end
        args['section'] = { 'settings' => section_settings, 'blocks' => section_blocks }
        unless File.file? @path + '/sections/' + section_data['type'] + '.liquid'
          render plain: 'could not found sections/' + section_data['type'] + '.liquid file missing!', status: 400
          return
        end
        @template = Liquid::Template.parse(File.read(@path + '/sections/' + section_data['type'] + '.liquid'))
        @test = @template.render(args)
        @content_for_layout += @test
      }
    end
    args.delete('section')

    @template = Liquid::Template.parse(File.read(@path + '/layout/theme.liquid')) # Parses and compiles the template
    @origin = request.base_url
    args['content_for_layout'] = @content_for_layout
    args['request'] = { 'origin' => @origin }
    @test = @template.render(args)
    render html: @test.html_safe
    return
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

  public def page

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
    unless check_store
      return
    end

    unless @store
      content_not_found
      return
    end

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

    @response = HTTP.post("https://api.sellioly.com/server/collection/get-by-handle", :form => { 'handle' => params[:collection], 'user_id' => $shop_id, 'app_domain' => @domain })
    args['collection'] = nil
    if @response.status.success?
      args['collection'] = @response.parse
      @response = HTTP.post("https://api.sellioly.com/server/product/get-by-collection", :form => { 'handle' => params[:collection], 'user_id' => $shop_id, 'app_domain' => @domain })
      args['collection']['products'] = nil
      if @response.status.success?
        args['collection']['products'] = @response.parse
      end
    else
      page_not_found
      return
    end

    @content_for_layout = ''

    file = File.read(@path + '/templates/collection.json')
    data = JSON.load file
    if data["order"].kind_of?(Array)
      data["order"].each { |section_id|
        section_data = data["sections"][section_id]
        section_settings = section_data['settings']
        section_blocks = []
        if section_data['block_order'].kind_of?(Array)
          section_data['block_order'].each { |block_id|
            section_blocks.push(section_data['blocks'][block_id])
          }
        end
        args['section'] = { 'settings' => section_settings, 'blocks' => section_blocks }
        unless File.file? @path + '/sections/' + section_data['type'] + '.liquid'
          render plain: 'could not found sections/' + section_data['type'] + '.liquid file missing!', status: 400
          return
        end
        @template = Liquid::Template.parse(File.read(@path + '/sections/' + section_data['type'] + '.liquid'))
        @test = @template.render(args)
        @content_for_layout += @test
      }
    end
    args.delete('section')

    @template = Liquid::Template.parse(File.read(@path + '/layout/theme.liquid')) # Parses and compiles the template
    @origin = request.base_url
    args['content_for_layout'] = @content_for_layout
    args['request'] = { 'origin' => @origin }
    @test = @template.render(args)
    render html: @test.html_safe
    return
  end

  public def checkout
    render_page('checkout.json')
    return
  end

  private

  def initialize_shop
    puts '--------------------- initialize_shop --------------------'

    unless check_store
      return
    end

    unless @store
      content_not_found
      return
    end

    @path = Rails.root.to_s + @store.template_path.to_s
    Liquid::Template.file_system = Liquid::LocalFileSystem.new(@path, '%s.liquid')

    response = HTTP.post("https://api.sellioly.com/server/store/infos", :form => { 'app_domain' => @domain })
    unless (response.status.success?)
      internal_server_error
      return
    end
    @content_for_layout = ''

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

    response = HTTP.post("https://api.sellioly.com/server/menu/get-by-handle", :form => { 'handle' => 'main-menu', 'user_id' => $shop_id, 'app_domain' => @domain })
    @args['menu'] = nil
    if response.status.success?
      @args['menu'] = response.parse
    end

    # get cart -------------------------------------
    if cookies[:cart_id].present?
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
  end

  def render_page(filename)
    file = File.read(@path + '/templates/' + filename)
    data = JSON.load file

    if data["order"].kind_of?(Array)
      data["order"].each { |section_id|
        section_data = data["sections"][section_id]
        section_settings = section_data['settings']
        section_blocks = []
        if section_data['block_order'].kind_of?(Array)
          section_data['block_order'].each { |block_id|
            section_blocks.push(section_data['blocks'][block_id])
          }
        end
        @args['section'] = { 'settings' => section_settings, 'blocks' => section_blocks }
        unless File.file? @path + '/sections/' + section_data['type'] + '.liquid'
          render plain: 'could not found sections/' + section_data['type'] + '.liquid file missing!', status: 400
          return
        end
        template = Liquid::Template.parse(File.read(@path + '/sections/' + section_data['type'] + '.liquid'))
        @content_for_layout += template.render(@args)
      }
    end
    @args.delete('section')

    template = Liquid::Template.parse(File.read(@path + '/layout/theme.liquid')) # Parses and compiles the template
    origin = request.base_url
    @args['content_for_layout'] = @content_for_layout
    @args['request'] = { 'origin' => origin }
    temp = template.render(@args)
    render html: temp.html_safe
    return
  end

  def render_section(section_id)
    unless File.file? @path + '/sections/' + section_id + '.liquid'
      return ''
    end
    
    template = Liquid::Template.parse(File.read(@path + '/sections/' + section_id + '.liquid'))
    return template.render(@args)
  end

end
