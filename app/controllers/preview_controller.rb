class PreviewController < ApplicationController

  public def index
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
    @domain = @data['app_domain']
    @shop_name = @data['shop_name']
    @currency = @data['currency']
    @shop_description = @data['shop_description']
    @logo = (@data['shop_logo_default'])
    args = {}

    @response = HTTP.post("https://api.sellioly.com/server/menu/get-by-handle", :form => { 'handle' => 'main-menu', 'app_domain' => @domain })
    args['menu'] = nil
    if @response.status.success?
      args['menu'] = @response.parse
    end

    args['logo'] = @logo
    args['shop_name'] = @shop_name
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
  end

end