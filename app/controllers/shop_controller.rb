class ShopController < ApplicationController
  protect_from_forgery except: :file_assets

  def index
    @domain = request.host
    @store = Store.where(app_domain: @domain).first
    unless @store
      content_not_found
      return
    end

    @path = Rails.root.to_s + @store.template_path
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
    data["order"].each { |section_id|
      section_data = data["sections"][section_id]
      section_settings = section_data['settings']
      section_blocks = []
      section_data['block_order'].each { |block_id|
        section_blocks.push(section_data['blocks'][block_id])
      }
      args['section'] = { 'settings' => section_settings, 'blocks' => section_blocks }
      @template = Liquid::Template.parse(File.read(@path + '/sections/' + section_data['type'] + '.liquid'))
      @test = @template.render!(args)
      @content_for_layout += @test
    }
    args.delete('section')

    @template = Liquid::Template.parse(File.read(@path + '/layout/theme.liquid')) # Parses and compiles the template
    @origin = request.base_url
    args['content_for_layout'] = @content_for_layout
    args['request'] = { 'origin' => @origin }
    @test = @template.render!(args)
    render html: @test.html_safe
  end

  def file_assets()
    @domain = request.host
    @store = Store.where(app_domain: @domain).first
    unless @store
      content_not_found
      return
    end
    @path = Rails.root.to_s + @store.template_path
    unless File.exist?(@path + '/assets/' + params[:filename])
      not_found
    end
    render file: @path + '/assets/' + params[:filename]
  end

  def not_found
    content_not_found
  end
end
