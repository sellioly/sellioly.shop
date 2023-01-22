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

    render json: { msg: 'Template in progress', id: @store.id, template_path: @subpath}
  end

  public def preview
    @width = params[:w].to_s
    @height = params[:h].to_s
    @resize_width = params[:rw].to_s
    @resize_height = params[:rh].to_s
    # @response = HTTP.get("https://node-api.sellioly.com/api/screenshot/take-screenshot?url=https://preview.sellioly.com/preview/" + params[:shop_id].to_s + "/" + params[:template_id].to_s + '&w=' + @width + '&h=' + @height + '&rw=' + @resize_width + '&rh=' + @resize_height)
    #
    # headers['Access-Control-Allow-Origin'] = '*'
    # headers['Access-Control-Allow-Methods'] = 'GET, OPTIONS'
    # headers['Access-Control-Request-Method'] = '*'
    # headers['Access-Control-Allow-Headers'] = 'Origin, X-Requested-With, Content-Type, Accept, Authorization'
    @path = Rails.root.to_s + '/storage/screenshot.jpeg'

    File.open(@path, 'rb') do |f|
      send_data f.read, :type => "image/jpeg", :disposition => "inline", status: 200
    end
  end
end
