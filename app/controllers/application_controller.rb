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

    render_page('404.json')
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
      content_not_found
      return
    end

    @path = Rails.root.to_s + @store.template_path.to_s
    Liquid::Template.file_system = Liquid::LocalFileSystem.new(@path, '%s.liquid')

    response = HTTP.post("https://api.sellioly.com/server/store/infos", :form => { 'app_domain' => @domain })
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

    # read presets ---------------------------------
    file = File.read(@path + '/config/settings_data.json')
    settings_data = JSON.load file

    file = File.read(@path + '/config/settings_schema.json')
    settings_schema = JSON.load file

    presets = {
    }
    if settings_data['presets'][settings_data['current']]
      settings_data['presets'][settings_data['current']].keys.each do |section_id|
        section_data = settings_data['presets'][settings_data['current']][section_id]
        schema_data = settings_schema[section_id]
        if schema_data
          section_data['settings'].keys.each do |key|
            value = section_data['settings'][key]
            if schema_data['settings'][key]
              presets[section_id] = { settings: {} }
              case schema_data['settings'][key]['element']
              when 'menu'
                response = HTTP.post("https://api.sellioly.com/server/menu/get-by-handle", :form => { 'handle' => value, 'user_id' => $shop_id, 'app_domain' => @domain })
                if response.status.success?
                  presets[section_id]['settings'][key] = response.parse
                end
              when 'product-picker'
                response = HTTP.post("https://api.sellioly.com/server/product/get-by-handle", :form => { 'handle' => value, 'user_id' => $shop_id, 'app_domain' => @domain })
                if response.status.success?
                  presets[section_id]['settings'][key] = response.parse
                end
              when 'products-picker'
                response = HTTP.post("https://api.sellioly.com/server/product/get-by-handles", :form => { 'handles[]' => value, 'user_id' => $shop_id, 'app_domain' => @domain })
                if response.status.success?
                  presets[section_id]['settings'][key] = response.parse
                end
              when 'collection-picker'
                response = HTTP.post("https://api.sellioly.com/server/collection/get-by-handle", :form => { 'handle' => value, 'user_id' => $shop_id, 'app_domain' => @domain })
                if response.status.success?
                  presets[section_id]['settings'][key] = response.parse
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

  end

  def render_page(filename)
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
        if File.file? @path + '/schemas/' + section_data['type'] + '.json'
          file = File.read @path + '/schemas/' + section_data['type'] + '.json'
          section_schema = JSON.load file
        end

        if section_schema
          section_data['settings'].each do |_data|
            key = _data[0]
            value = _data[1]
            if section_schema['settings'][key]
              case section_schema['settings'][key]['element']
              when 'menu'
                response = HTTP.post("https://api.sellioly.com/server/menu/get-by-handle", :form => { 'handle' => value, 'user_id' => $shop_id, 'app_domain' => @domain })
                if response.status.success?
                  section_data['settings'][key] = response.parse
                end
              when 'product-picker'
                response = HTTP.post("https://api.sellioly.com/server/product/get-by-handle", :form => { 'handle' => value, 'user_id' => $shop_id, 'app_domain' => @domain })
                if response.status.success?
                  section_data['settings'][key] = response.parse
                end
              when 'products-picker'
                response = HTTP.post("https://api.sellioly.com/server/product/get-by-handles", :form => { 'handles[]' => value, 'user_id' => $shop_id, 'app_domain' => @domain })
                if response.status.success?
                  section_data['settings'][key] = response.parse
                end
              when 'collection-picker'
                response = HTTP.post("https://api.sellioly.com/server/collection/get-by-handle", :form => { 'handle' => value, 'user_id' => $shop_id, 'app_domain' => @domain })
                if response.status.success?
                  section_data['settings'][key] = response.parse
                end
              else
                next
              end
            else

            end
          end

        end

        section_settings = section_data['settings']

        section_blocks = []
        if section_data['block_order'].kind_of?(Array)
          section_data['block_order'].each { |block_id|
            block_data = section_data['blocks'][block_id]
            if section_schema and block_data
              if section_schema['blocks'] && section_schema['blocks'][block_data['type']]
                block_schema = section_schema['blocks'][block_data['type']]
                block_data['settings'].each do |_data|
                  key = _data[0]
                  value = _data[1]
                  if block_schema['settings'][key]
                    case block_schema['settings'][key]['element']
                    when 'menu'
                      response = HTTP.post("https://api.sellioly.com/server/menu/get-by-handle", :form => { 'handle' => value, 'user_id' => $shop_id, 'app_domain' => @domain })
                      if response.status.success?
                        block_data['settings'][key] = response.parse
                      end
                    when 'product-picker'
                      response = HTTP.post("https://api.sellioly.com/server/product/get-by-handle", :form => { 'handle' => value, 'user_id' => $shop_id, 'app_domain' => @domain })
                      if response.status.success?
                        block_data['settings'][key] = response.parse
                      end
                    when 'products-picker'
                      response = HTTP.post("https://api.sellioly.com/server/product/get-by-handles", :form => { 'handles[]' => value, 'user_id' => $shop_id, 'app_domain' => @domain })
                      if response.status.success?
                        section_data['settings'][key] = response.parse
                      end
                    when 'collection-picker'
                      response = HTTP.post("https://api.sellioly.com/server/collection/get-by-handle", :form => { 'handle' => value, 'user_id' => $shop_id, 'app_domain' => @domain })
                      if response.status.success?
                        block_data['settings'][key] = response.parse
                      end
                    else
                      next
                    end
                  else

                  end
                end
              end
            end

            section_blocks.push(block_data)
          }
        end
        @args['section']['settings'] = section_settings
        @args['section']['blocks'] = section_blocks

        unless File.file? @path + '/sections/' + section_data['type'] + '.liquid'
          render plain: 'could not found sections/' + section_data['type'] + '.liquid file missing!', status: 400
          return
        end
        template = Liquid::Template.parse(File.read(@path + '/sections/' + section_data['type'] + '.liquid'))
        @content_for_layout += template.render(@args)
      }
    end

    @args.delete('section')

    if layout_data['sections']
      layout_data['sections'].keys.each do |section_id|
        section_data = layout_data['sections'][section_id]
        schema_data = nil
        if File.file? @path + '/schemas/' + section_data['type'] + '.json'
          file = File.read(@path + '/schemas/' + section_data['type'] + '.json')
          schema_data = JSON.load file
        end
        if schema_data
          section_data['settings'].keys.each do |key|
            value = section_data['settings'][key]
            if schema_data['settings'][key]
              case schema_data['settings'][key]['element']
              when 'menu'
                response = HTTP.post("https://api.sellioly.com/server/menu/get-by-handle", :form => { 'handle' => value, 'user_id' => $shop_id, 'app_domain' => @domain })
                if response.status.success?
                  layout_data['sections'][section_id]['settings'][key] = response.parse
                end
              when 'product-picker'
                response = HTTP.post("https://api.sellioly.com/server/product/get-by-handle", :form => { 'handle' => value, 'user_id' => $shop_id, 'app_domain' => @domain })
                if response.status.success?
                  layout_data['sections'][section_id]['settings'][key] = response.parse
                end
              when 'products-picker'
                response = HTTP.post("https://api.sellioly.com/server/product/get-by-handles", :form => { 'handles[]' => value, 'user_id' => $shop_id, 'app_domain' => @domain })
                if response.status.success?
                  section_data['settings'][key] = response.parse
                end
              when 'collection-picker'
                response = HTTP.post("https://api.sellioly.com/server/collection/get-by-handle", :form => { 'handle' => value, 'user_id' => $shop_id, 'app_domain' => @domain })
                if response.status.success?
                  layout_data['sections'][section_id]['settings'][key] = response.parse
                end
              else
                next
              end
            else

            end
          end

        end
      end

      @args['layout_data'] = layout_data['sections']
    end

    template = Liquid::Template.parse(File.read(@path + "/layout/#{layout}.liquid")) # Parses and compiles the template
    origin = request.base_url
    @args['content_for_layout'] = @content_for_layout
    @args['request'] = { 'origin' => origin }
    temp = template.render(@args)
    render html: temp.html_safe
    nil
  end

end
