class ShopController < ApplicationController
  def index
    @domain = request.host
    @store = Store.where(app_domain: @domain).first
    unless @store
      content_not_found
      return
    end

    @path = Rails.root.to_s + @store.template_path
    Liquid::Template.file_system = Liquid::LocalFileSystem.new(@path, '%s.liquid')
    @template = Liquid::Template.parse(File.read(@path + '/layout/theme.liquid')) # Parses and compiles the template
    @test = @template.render('page_title' => @domain)
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
end
