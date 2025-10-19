class ApplicationController < ActionController::Base
  rescue_from StandardError, with: :log_and_render_error
  protect_from_forgery with: :null_session
  include ShopHelper

  def content_not_found
    render file: "#{Rails.root}/public/404.html", layout: true, status: :not_found
    # render  json: {domain: "not found! #{@domain}  #{@cname.inspect}"}
    true
  end

  def internal_server_error
    render file: "#{Rails.root}/public/500.html", layout: true, status: :not_found
    true
  end

  def verify_ssl_hook
    @domain = request.host
    cert = LetsEncrypt::Certificate.find_by(domain: @domain)
    # alias  `verify && issue`
    if cert
      if cert.expired?
        if cert.renew
          LetsEncrypt::RenewCertificatesJob.perform_later
        end
      end
    end
  end

  def check_store
    @domain = request.host
    @cname = Resolv::DNS.new.getresource(@domain, Resolv::DNS::Resource::IN::CNAME) rescue nil
    if @cname
      @cname = @cname.name.to_s
      @response = HTTP.post("https://api.sellioly.com/ruby/domain/verify", :form => { 'domain' => @domain, 'app_domain' => @cname })
      unless @response.status.success?
        puts "Verify domain failed! #{@domain} #{@cname}"
        content_not_found
        return false
      end
      @domain = @cname
    elsif not (@domain =~ /^[A-Za-z0-9.-]+\.sellioly\.com$/)
      puts "Domain format error! #{@domain}"
      content_not_found
      return false
    end

    @store = Store.where(app_domain: @domain).first
    if @store
      @shop_id = @store.shop_id
      @template_id = @store.template_id
    end

    true
  end

  def initialize_shop
    puts '--------------------- initialize_shop --------------------'
    puts "initialize_shop Format: " + request.format.to_s + "/" + (request.format.html?).to_s

    # remove html format check because we need initialize_shop for cart_controller

    # unless request.format.html?
    #   content_not_found
    #   return
    # end

    unless check_store
      return
    end

    unless @store
      puts "Store not found! #{@domain}"
      content_not_found
      return
    end

    @path = Rails.root.to_s + @store.template_path.to_s
    Liquid::Template.file_system = Liquid::LocalFileSystem.new(@path, '%s.liquid')

    response = get_shop_id(@shop_id)
    unless response
      internal_server_error
      return
    end

    data = response
    shop_name = data['shop_name']
    shop_description = data['shop_description']
    currency = data['currency']
    logo = (data['shop_logo_default'])

    @args = {}
    @args['shop_id'] = @shop_id
    @args['template_id'] = @template_id
    @args['page_title'] = "HOME - #{shop_name}"
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
          # get the section settings
          presets[section_id]['settings'] = get_section_settings(schema_data['settings'], section_data['settings'])
        end
      end

      @args['presets'] = presets
    end

    puts '--------------------- initialize_shop end --------------------'
  end

  def render_page(filename)
    puts(request.host + " - " + Liquid::Template.file_system.inspect)
    file = File.read(@path + '/templates/' + filename)
    data = JSON.load file
    layout = 'theme'
    if data['layout']
      layout = data['layout']
    end

    @content_for_layout = ''
    layout_data = {}
    if File.exist? @path + "/layout/#{layout}.json"
      layout_json = File.read(@path + "/layout/#{layout}.json")
      layout_data = JSON.load layout_json
    end

    if data["order"].kind_of?(Array)
      data["order"].each { |section_id|
        @args['section'] = {}
        section_data = data["sections"][section_id]
        section_schema = nil
        puts(request.host + " - " + Liquid::Template.file_system.inspect)
        if File.file? @path + '/schemas/' + section_data['type'] + '.json'
          file = File.read @path + '/schemas/' + section_data['type'] + '.json'
          section_schema = JSON.load file
        end

        section_settings = {}
        if section_schema     
          # get the section settings    
          section_settings = get_section_settings(section_schema['settings'], section_data['settings'])
        end

        section_blocks = []
        if section_data['block_order'].kind_of?(Array)
          section_data['block_order'].each { |block_id|
            block_data = section_data['blocks'][block_id]
            if section_schema and block_data
              if section_schema['blocks'] && section_schema['blocks'][block_data['type']]
                block_schema = section_schema['blocks'][block_data['type']]

                # get the block settings
                block_data['settings'] = get_section_settings(block_schema['settings'], block_data['settings'])
              end
            end

            section_blocks.push(block_data)
          }
        end
        @args['section']['settings'] = section_settings
        @args['section']['blocks'] = section_blocks

        puts(request.host + " - " + Liquid::Template.file_system.inspect)
        unless File.file? @path + '/sections/' + section_data['type'] + '.liquid'
          render plain: 'could not found sections/' + section_data['type'] + '.liquid file missing!', status: 400
          return
        end

        Liquid::Template.file_system = Liquid::LocalFileSystem.new(@path, '%s.liquid')
        template = Liquid::Template.parse(File.read(@path + '/sections/' + section_data['type'] + '.liquid'))
        @content_for_layout += template.render(@args)
      }
    end

    @args.delete('section')

    if layout_data['sections']
      layout_data['sections'].keys.each do |section_id|
        section_data = layout_data['sections'][section_id]
        schema_data = nil
        puts(request.host + " - " + Liquid::Template.file_system.inspect)
        if File.file? @path + '/schemas/' + section_data['type'] + '.json'
          file = File.read(@path + '/schemas/' + section_data['type'] + '.json')
          schema_data = JSON.load file
        end
        
        if schema_data
          # get the section settings
          layout_data['sections'][section_id]['settings'] = get_section_settings(schema_data['settings'], section_data['settings'])
        end
      end

      @args['layout_data'] = layout_data['sections']
    end

    Liquid::Template.file_system = Liquid::LocalFileSystem.new(@path, '%s.liquid')
    template = Liquid::Template.parse(File.read(@path + "/layout/#{layout}.liquid")) # Parses and compiles the template
    origin = request.base_url

    response = get_metadata(@shop_id, @domain)
    @args['content_for_header'] = ""
    if response
      metadata = response
      @args['metadata'] = metadata

      if metadata.has_key? "pixels"
        metadata['pixels'].keys.each do |pixel_type|
          metadata['pixels'][pixel_type].each do |pixel|
            if pixel.has_key? "pixel_code"
              @args['content_for_header'] = @args['content_for_header'] + pixel['pixel_code'] + "\n\n"
            end
          end
        end
      end
    end

    @args['content_for_layout'] = @content_for_layout
    @args['request'] = { 'origin' => origin }
    temp = template.render(@args)
    render html: temp.html_safe
    nil
  end

  def get_section_settings(schema_settings, data_settings)
    if not schema_settings or not data_settings
      return {}
    end

    # ensure data_settings is a Hash or empty Hash
    data_settings = {} unless data_settings.is_a?(Hash)
    schema_settings = {} unless schema_settings.is_a?(Hash)

    data_settings.keys.each do |key|
      value = data_settings[key]
      if schema_settings[key]
        # read the default value
        if value.nil?
          value = schema_settings[key]['default']
          data_settings[key] = schema_settings[key]['default']
        end

        case schema_settings[key]['element']
        when 'menu'
          response = get_menu(value, @shop_id, @domain)
          if response
            data_settings[key] = response
          end
        when 'product-picker'
          response = get_product(value, @shop_id, @domain)
          if response
            data_settings[key] = response
          end
        when 'products-picker'
          response = get_products(value, @shop_id, @domain)
          if response
            data_settings[key] = response
          end
        when 'collection-picker'
          response = get_collection(value, @shop_id, @domain)
          if response
            data_settings[key] = response
          end
        else
          next
        end
      end
    end

    data_settings
  end

  private

  def log_and_render_error(exception)
    # Log the error with full context
    Rails.logger.error({
      error: exception.message,
      backtrace: exception.backtrace.take(10), # limit lines for brevity
      path: request.fullpath,
      method: request.method,
      params: request.filtered_parameters, # filters sensitive keys
    }.to_json)

    # Return JSON error response (customize as needed)
    render json: { error: 'Internal server error' }, status: :internal_server_error
  end

end
