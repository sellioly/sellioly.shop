class ShopController < ApplicationController
  protect_from_forgery except: :file_assets
  before_action :verify_ssl_hook, :initialize_shop, except: [:preview, :file_assets, :file_font_assets]

  def index

    puts "page Format: " + request.format.to_s + "/" + (request.format.html?).to_s

    render_page('index.json')
  end

  def file_assets
    @path = Rails.root.to_s + '/storage/' + params[:shop_id] + '/' + params[:template_id]
    unless File.directory?(@path)
      content_not_found
      return
    end

    @shop_id = params[:shop_id]
    @template_id = params[:template_id]

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

    @shop_id = params[:shop_id]
    @template_id = params[:template_id]

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

    @shop_id = params[:shop_id]
    @template_id = params[:template_id]

    Liquid::Template.file_system = Liquid::LocalFileSystem.new(@path, '%s.liquid')

    response = get_shop_id(params[:shop_id])
    unless response
      internal_server_error
      return
    end
    
    data = response
    @domain = data['app_domain']
    
    shop_name = data['shop_name']
    shop_description = data['shop_description']
    currency = data['currency']
    logo = (data['shop_logo_default'])

    @args = {}
    @args['shop_id'] = @shop_id
    @args['template_id'] = @template_id
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

    # read presets ---------------------------------
    file = File.read(@path + '/config/settings_data.json')
    settings_data = JSON.load file

    file = File.read(@path + '/config/settings_schema.json')
    settings_schema = JSON.load file

    presets = {}
    if settings_data['presets'][settings_data['current']]
      settings_data['presets'][settings_data['current']].keys.each do |section_id|
        section_data = settings_data['presets'][settings_data['current']][section_id]
        schema_data = settings_schema[section_id]
        presets[section_id] = section_data # to verify !
        
        if schema_data
          section_data['settings'].keys.each do |key|
            value = section_data['settings'][key]
            if schema_data['settings'][key]
              # read the default value
              if value.nil?
                value = schema_data['settings'][key]['default']
                section_data['settings'][key] = schema_data['settings'][key]['default']
              end

              case schema_data['settings'][key]['element']
              when 'menu'
                response = get_menu(value, @shop_id, @domain)
                if response
                  presets[section_id]['settings'][key] = response
                end
              when 'product-picker'
                response = get_product(value, @shop_id, @domain)
                if response
                  presets[section_id]['settings'][key] = response
                end
              when 'products-picker'
                presets[section_id]['settings'][key] = get_products(value, @shop_id, @domain)
              when 'collection-picker'
               response = get_collection(value, @shop_id, @domain)
                if response
                  presets[section_id]['settings'][key] = response
                end
              else
                next
              end
            else

            end
          end

        end
      end

      @args['presets'] = presets
    end

    render_page('index.json')
  end

  public def product
    response = get_product(params[:product], @shop_id, @domain)
    if response
      @args['product'] = response
    else
      page_not_found
      return
    end
    
    response = HTTP.post("https://api.sellioly.com/server/product/get-similar-by-handle", :form => { 'handle' => params[:product], 'user_id' => @shop_id, 'app_domain' => @domain })
    if response.status.success?
      @args['similar_products'] = response.parse
    end

    render_page('product.json')
    return
  end

  public def collection
    response = get_collection(params[:collection], @shop_id, @domain)
    @args['collection'] = nil
    if response
      @args['collection'] = response
      response = HTTP.post("https://api.sellioly.com/server/product/get-by-collection", :form => { 'handle' => params[:collection], 'user_id' => @shop_id, 'app_domain' => @domain })
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

  public def cart
    render_page('cart.json')
    nil
  end

  public def checkout
    render_page('checkout.json')
    nil
  end

  public def our_store
    render_page('our-store.json')
    nil
  end

  public def about_us
    render_page('about-us.json')
    nil
  end

  public def not_found
    puts "ShopController => not_found"
    render_page('404.json')
    nil
  end

  # other pages
  public def page
    puts "ShopController => page"
    puts "page Format: " + request.format.to_s + "/" + (request.format.html?).to_s

    unless request.format.html?
      content_not_found
      return
    end

    # Check if the page exists, if exists, render it using render_page method
    # else render 404 page
    if params[:path].present?
      path = params[:path]
      # Check if file exists
      if File.exist?(@path + '/templates/' + path + '.json')
        render_page(path + '.json')
        return
      end
    end
    
    # Render 404 page
    render_page('404.json')
  end
  
  public def productPreview
    @args['preview'] = true

    render_page('product.json')
    return
  end
  
  public def collectionPreview
    @args['preview'] = true

    render_page('collection.json')
    return
  end

  public def cartPreview
    @args['preview'] = true

    render_page('cart.json')
    return
  end

  public def checkoutPreview
    @args['preview'] = true

    render_page('checkout.json')
    return
  end

  private

  def render_snippet(section_id, current_url)
    # data = current_url.match(/^\/(product|collection|)?\/?(.*)$/)
    # layout = "theme"
    # template = "index"
    # if data
    #   if data[0] != ""
    #     template = data[0]
    #   end
    # end
    #
    #
    # file = File.read(@path + '/templates/' + template + ".json")
    # template_data = JSON.load file
    # if template_data['layout']
    #   layout = template_data['layout']
    # end
    #
    # layout_data = {}
    # if File.exist? @path + "/layout/#{layout}.json"
    #   layout_json = File.read(@path + "/layout/#{layout}.json")
    #   layout_data = JSON.load layout_json
    # end

    unless File.file? @path + '/snippets/' + section_id + '.liquid'
      return ''
    end

    Liquid::Template.file_system = Liquid::LocalFileSystem.new(@path, '%s.liquid')
    template = Liquid::Template.parse(File.read(@path + '/snippets/' + section_id + '.liquid'))
    template.render(@args)
  end

end
