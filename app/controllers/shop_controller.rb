class ShopController < ApplicationController
  public

  def index
    @domain = request.host
    @store = Store.where(app_domain: @domain).first()
    unless @store
      render json: { msg: 'Store not found', domain:  @domain, store: @store }
      return
    end

    @path = Rails.root.to_s + @store.template_path
    Liquid::Template.file_system = Liquid::LocalFileSystem.new(@path, '%s.liquid')
    @template = Liquid::Template.parse(File.read(@path + '/layout/theme.liquid')) # Parses and compiles the template
    @test = @template.render()
    render :text =>  @test
  end
end
