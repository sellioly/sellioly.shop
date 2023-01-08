class StoreController < ApplicationController
  public

  def create
    # code here

    @store = Store.new({})
    @store.app_domain = params[:app_domain]

    @subpath = "/storage/" + @store.app_domain + "/default"
    @path = Rails.root.to_s + @subpath

    @store.template_path = @subpath
    unless File.directory?(@path)
      FileUtils.mkdir_p(@path)
    end

    @store.save

    render json: { msg: 'Template in progress', id: @store.id }
  end
end
