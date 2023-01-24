class StoreController < ApplicationController
  public def create
    # code here
    @store = Store.new({})
    @store.app_domain = params[:app_domain]
    @store.template_id = params[:template_id].to_i
    @store.shop_id = params[:shop_id].to_i

    @subpath = "/storage/" + @store.shop_id.to_s + "/" + @store.template_id.to_s
    @path = Rails.root.to_s + @subpath
    @store.template_path = @subpath
    @store.save

    UploadLocalTemplateJob.perform_later @path, @store.app_domain, @subpath

    # upload local file template  /app/storage/63/28/config/settings_schema.json

    render json: { msg: 'Template in progress', id: @store.id, template_path: @subpath }
  end

  public def import_template
    #data
    @shop_id = params[:shop_id].to_i
    @template_id = params[:template_id].to_i
    @url_theme = params[:url_theme].to_s

    #traitement
    GetTemplateFromAwsJob.perform_later @shop_id, @template_id, @url_theme

    #result
    render json: { msg: 'Wait for checking template'}
  end
  public def publish_template
    #data
    @shop_id = params[:shop_id].to_i
    @template_id = params[:template_id].to_i
    @domain = params[:app_domain].to_s

    #traitement
    @store = Store.where(app_domain: @domain).first
    @store.template_id = params[:template_id].to_i
    @store.shop_id = params[:shop_id].to_i
    @sub_path = "/storage/" + @store.shop_id.to_s + "/" + @store.template_id.to_s
    @store.template_path = @sub_path
    @store.save

    #result
    render json: { msg: 'template has been published', id: @store.id, template_path: @sub_path }
  end
end
