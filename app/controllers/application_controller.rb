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


    render_page('404.json')
  end


  def render_page(filename)
    file = File.read(@path + '/templates/' + filename)
    data = JSON.load file
    layout = 'theme'
    if data['layout']
      layout = data['layout']
    end

    @content_for_layout = ''
    layout_json = File.read(@path + "/layout/#{layout}.json")
    layout_data = JSON.load layout_json

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
              case section_schema['settings'][key]['type']
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
            case schema_data['settings'][key]['type']
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

    template = Liquid::Template.parse(File.read(@path + "/layout/#{layout}.liquid")) # Parses and compiles the template
    origin = request.base_url
    @args['content_for_layout'] = @content_for_layout
    @args['request'] = { 'origin' => origin }
    temp = template.render(@args)
    render html: temp.html_safe
    nil
  end

end
