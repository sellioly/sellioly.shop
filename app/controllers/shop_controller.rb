class ShopController < ApplicationController
  protect_from_forgery except: :file_assets

  def index
    check_store
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
    args['page_title'] = 'HOME - ' + @shop_name
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

  def file_assets()
    @path = Rails.root.to_s + '/storage/' + params[:shop_id] + '/' + params[:template_id]
    unless File.directory?(@path)
      content_not_found
      return
    end

    $shop_id = params[:shop_id]
    $template_id = params[:template_id]

    unless File.exist?(@path + '/assets/' + params[:filename])
      not_found
    end
    expires_in 24.hours, :public => true
    render file: @path + '/assets/' + params[:filename], status: 200
    return
  end

  def not_found
    content_not_found
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

    @response = HTTP.post("https://api.sellioly.com/server/store/infos", :form => { 'user_id' => params[:shop_id] })
    unless @response.status.success?
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
    args['page_title'] = 'HOME - ' + @shop_name
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
          render plain:  'could not found sections/' + section_data['type'] + '.liquid file missing!', status: 400
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

  public def page
    render text: 'other page'
    return
  end
  public def product
    # code here
  end

  public def collection
    # code here
  end
end
