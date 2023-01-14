class StoreController < ApplicationController
  public

  def create
    # code here
    @store = Store.new({})
    @store.app_domain = params[:app_domain]

    @subpath = "/storage/" + @store.app_domain + "/default"
    @path = Rails.root.to_s + @subpath
    @store.template_path = @subpath
    @store.save

    UploadLocalTemplateJob.perform_later @path, @store.app_domain

    # upload local file template

    render json: { msg: 'Template in progress', id: @store.id, template_path: @subpath, theme_name: 'OutFill', theme_version: '1.0.0', theme_author: 'Sellioly', theme_support_url: '' }
  end
end
