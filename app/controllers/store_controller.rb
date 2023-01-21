class StoreController < ApplicationController
  public

  def create
    # code here
    @store = Store.new({})
    @store.app_domain = params[:app_domain]
    @store.template_id = params[:template_id]
    @store.shop_id = params[:user_id]

    @subpath = "/storage/" + @store.shop_id + "/" + @store.template_id
    @path = Rails.root.to_s + @subpath
    @store.template_path = @subpath
    @store.save

    UploadLocalTemplateJob.perform_later @path, @store.app_domain, @subpath

    # upload local file template

    file = File.read(@path + '/config/settings_schema.json')
    data = JSON.load file

    render json: { msg: 'Template in progress', id: @store.id, template_path: @subpath, theme_name: data['theme_name'], theme_version: data['theme_version'], theme_author: data['theme_author'], theme_support_url: data['theme_support_url'] }
  end

  def preview
    @width = params[:w]
    @height = params[:h]
    @resize_width = params[:rw]
    @resize_height = params[:rh]
    @response = HTTP.get("https://node-api.sellioly.com/take-screenshot?url=https://preview.sellioly.com/" + params[:shop_id].to_s + "/" + params[:template_id].to_s + '&w=' + @width + '&h=' + @height + '&rw=' + @resize_width + '&rh=' + @resize_height)
    render status: 200, text:  @response.body
  end
end
