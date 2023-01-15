class ShopController < ApplicationController
  protect_from_forgery except: :file_assets

  def index
    @domain = request.host
    @store = Store.where(app_domain: @domain).first
    unless @store
      content_not_found
      return
    end

    @response = HTTP.post("https://api.sellioly.com/server/store/infos", :form => { 'app_domain' => @domain })
    unless (@response.status.success?)
      internal_server_error
      return
    end

    @data  = @response.body.parse

    @path = Rails.root.to_s + @store.template_path
    Liquid::Template.file_system = Liquid::LocalFileSystem.new(@path, '%s.liquid')
    @content_for_layout = ''
    @template = Liquid::Template.parse(File.read(@path + '/sections/slideshow.liquid'))
    @test = @template.render
    @content_for_layout += @test
    @template = Liquid::Template.parse(File.read(@path + '/layout/theme.liquid')) # Parses and compiles the template
    @origin = request.base_url
    @test = @template.render('content_for_layout' => @content_for_layout, 'request' => { 'origin' => @origin }, 'page_title' => @data['shop_name'])
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
    render file: @path + '/assets/' + params[:filename] + '.' + params[:format]
  end

  def not_found
    content_not_found
  end
end
