require "zip"

class StoreController < ApplicationController

  include StoreHelper

  public def generate_ssl
    cert = LetsEncrypt::Certificate.create(domain: params[:app_domain])
    # alias  `verify && issue`
    if cert.get
      LetsEncrypt::RenewCertificatesJob.perform_later
      render :json => { :msg => 'OK' }
    else
      render :json => { :msg => 'NOT OK' }, status: 400
    end
  end

  public def renew_ssl
    cert = LetsEncrypt::Certificate.find_by(domain: params[:app_domain])
    # alias  `verify && issue`
    if cert
      if cert.renew
        LetsEncrypt::RenewCertificatesJob.perform_later
        render :json => { :msg => 'OK' }
      else
        render :json => { :msg => 'NOT OK' }, status: 400
      end
    else
      generate_ssl
    end
  end

  public def verify_ssl
    cert = LetsEncrypt::Certificate.find_by(domain: params[:app_domain])
    # alias  `verify && issue`
    if cert&.verify
      render :json => { :msg => 'OK' }, status: 200
    else
      render :json => { :msg => 'NOT OK' }, status: 400
    end
  end
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
    cert = LetsEncrypt::Certificate.create(domain: params[:app_domain]) rescue nil
    cert.get if cert

    LetsEncrypt::RenewCertificatesJob.perform_later
    UploadLocalTemplateJob.perform_later @path, @store.app_domain, @subpath

    # upload local file template  /app/storage/63/28/config/settings_schema.json

    render json: { msg: 'Template in progress', id: @store.id, template_path: @subpath }
  end

  public def import_template
    # data
    @shop_id = params[:shop_id].to_i
    @template_id = params[:template_id].to_i
    @url_theme = params[:url_theme].to_s

    # traitement
    GetTemplateFromAwsJob.perform_later @shop_id, @template_id, @url_theme

    # result
    render json: { msg: 'Wait for checking template' }
  end

  public def publish_template
    # data
    @shop_id = params[:shop_id].to_i
    @template_id = params[:template_id].to_i
    @domain = params[:app_domain].to_s

    # traitement
    @store = Store.where(app_domain: @domain).first
    @store.template_id = params[:template_id].to_i
    @store.shop_id = params[:shop_id].to_i
    @sub_path = "/storage/" + @store.shop_id.to_s + "/" + @store.template_id.to_s
    @store.template_path = @sub_path
    @store.save

    # result
    render json: { msg: 'template has been published', id: @store.id, template_path: @sub_path }
  end

  public def verify_theme
    # data
    @url_theme = params[:url_theme].to_s

    # traitement
    VerifyThemeJob.perform_later @url_theme

    # result
    render json: { msg: 'Wait for checking the theme' }
  end

  public

  def request_template_page
    # code here
    @shop_id = params[:shop_id].to_s
    @template_id = params[:template_id].to_s
    @request_page = params[:page].to_s
    @sub_path = "/storage/" + @shop_id + "/" + @template_id
    @path = Rails.root.to_s + @sub_path

    file = File.read(@path + '/templates/' + @request_page + '.json')
    data = JSON.load file

    layout = 'theme'
    if data['layout']
      layout = data['layout']
    end

    layout_json = File.read(@path + "/layout/#{layout}.json")
    layout_data = JSON.load layout_json
    # items = template.root.nodelist
    # items = items.select { |node| (node.is_a?(Liquid::Variable) && node.name.is_a?(Liquid::VariableLookup) && node.name.name == "content_for_layout") || node.is_a?(SectionTag) }
    #              .map { |var| var.as_json }
    #
    layout_forms = {}
    after_content_for_layout = false
    layout_data['sections'].each do |section|
      section_data = section[1]
      if File.file? @path + '/schemas/' + section_data['type'] + '.json'
        file = File.read(@path + '/schemas/' + section_data['type'] + '.json')
        schema_data = JSON.load file
        layout_forms[section[0]] = { schema: schema_data, data: section_data }
      end
    end

    forms = {}
    data["order"].each { |section_id|
      section_data = data["sections"][section_id]
      forms[section_id] = { schema: nil, data: section_data }
      if File.file? @path + '/schemas/' + section_data['type'] + '.json'
        file = File.read(@path + '/schemas/' + section_data['type'] + '.json')
        schema_data = JSON.load file
        forms[section_id]['schema'] = schema_data
      end
    }
    page_data = {}
    page_data['order'] = data['order']
    page_data['sections'] = forms

    render json: { page: page_data, layout: { sections: layout_forms }, original: { page: data, layout: layout_data } }
  end

  def request_assets_template
    # code here
    @shop_id = params[:shop_id].to_s
    @template_id = params[:template_id].to_s
    @sub_path = "/storage/" + @shop_id + "/" + @template_id
    @path = Rails.root.to_s + @sub_path

    entries = []

    Dir.glob("#{@path}/**/*") do |file_path|
      next if File.directory?(file_path)

      file_name = file_path.sub("#{@path}/", "")
      created_at = File.ctime(file_path).strftime("%Y-%m-%d %H:%M:%S")
      updated_at = File.mtime(file_path).strftime("%Y-%m-%d %H:%M:%S")
      ext_type = File.extname(file_path)
      if ext_type == '.liquid'
        content_type = 'application/x-liquid'
      else
        content_type = Rack::Mime.mime_type(ext_type)
      end

      entries.push({
                     key: file_name,
                     created_at: created_at,
                     updated_at: updated_at,
                     extension: ext_type,
                     content_type: content_type
                   })
    end

    render json: entries
  end

  def request_asset_content
    # code here
    @shop_id = params[:shop_id].to_s
    @template_id = params[:template_id].to_s
    @key = params[:key].to_s
    @sub_path = "/storage/" + @shop_id + "/" + @template_id
    @path = Rails.root.to_s + @sub_path + "/" + @key

    ext_type = File.extname(@path)
    if ext_type == '.liquid'
      mime_type = 'application/x-liquid'
    else
      mime_type = Rack::Mime.mime_type(ext_type)
    end
    content = File.read(@path)
    render body: content, mime_type: mime_type
  end

  def update_asset_content
    # code here
    @shop_id = params[:shop_id].to_s
    @template_id = params[:template_id].to_s
    @key = params[:key].to_s
    @content = params[:content].to_s
    @sub_path = "/storage/" + @shop_id + "/" + @template_id
    @path = Rails.root.to_s + @sub_path + "/" + @key

    File.open(@path, "w") do |file|
      file.write(@content)
    end

    ext_type = File.extname(@path)
    if ext_type == '.liquid'
      mime_type = 'application/x-liquid'
    else
      mime_type = Rack::Mime.mime_type(ext_type)
    end
    content = File.read(@path)
    render body: content, mime_type: mime_type
  end

  def request_template
    # code here
    @shop_id = params[:shop_id].to_s
    @template_id = params[:template_id].to_s
    @sub_path = "/storage/" + @shop_id + "/" + @template_id
    @path = Rails.root.to_s + @sub_path

    unless Dir.exist? @path
      return :json => { msg: "template not found" }, status: 400
    end

    bundle_filename = Rails.root.to_s + "/storage/" + @shop_id + "/" + @template_id + ".zip"
    FileUtils.rm bundle_filename, :force => true
    Zip::File.open(bundle_filename, Zip::File::CREATE) do |zipfile|
      Dir.chdir @path
      Dir.glob("**/*").each do |file|
        zipfile.add(file.sub(@path + '/', ''), file)
      end
    end
    send_file bundle_filename, :type => "application/zip", :x_sendfile => true
  end

  # This method processes events based on their type and operation
  def process_event
    # Extract parameters from the request
    event = params[:event]
    operation = params[:operation]
    id = params[:id]
    app_domain = params[:app_domain]
    shop_id = params[:shop_id].to_s
    event_id = 'user_id'

    case event
    when 'product'
      case operation
      when 'update', 'insert'
        # Handle product update/insert
        handle = id
        endpoint = "product/get-by-handle"
      when 'delete'
        # Handle product deletion
        redis_del(app_domain, shop_id, "#{event}:#{id}")
        render json: { message: "Deleting #{event} with id #{id}" }
        return
      else
        render json: { error: "Invalid operation: #{operation}" }, status: :unprocessable_entity
        return
      end
    when 'menu'
      case operation
      when 'update', 'insert'
        # Handle menu update/insert
        handle = id
        endpoint = "menu/get-by-handle"
      when 'delete'
        # Handle menu deletion
        redis_del(app_domain, shop_id, "#{event}:#{id}")
        render json: { message: "Deleting #{event} with id #{id}" }
        return
      else
        render json: { error: "Invalid operation: #{operation}" }, status: :unprocessable_entity
        return
      end
    when 'collection'
      case operation
      when 'update', 'insert'
        # Handle collection update/insert
        handle = id
        endpoint = "collection/get-by-handle"
      when 'delete'
        # Handle collection deletion
        redis_del(app_domain, shop_id, "#{event}:#{id}")
        render json: { message: "Deleting #{event} with id #{id}" }
        return
      else
        render json: { error: "Invalid operation: #{operation}" }, status: :unprocessable_entity
        return
      end
    when 'metadata'

      event_id = 'meta_id'

      case operation
      when 'update', 'insert'
        # Handle metadata update/insert
        handle = nil
        endpoint = "metadata/store/list"
      when 'delete'
        # Handle metadata deletion
        redis_del(app_domain, shop_id, "#{event}")
        render json: { message: "Deleting #{event} with shop id #{shop_id}" }
        return
      else
        render json: { error: "Invalid operation: #{operation}" }, status: :unprocessable_entity
        return
      end

    when 'shop'
      case operation
      when 'update', 'insert'
        # Handle shop update/insert
        handle = nil
        endpoint = "store/infos"
      when 'delete'
        # Handle shop deletion
        redis_del(app_domain, -1, "#{event}")
        render json: { message: "Deleting #{event} with domain #{app_domain}" }
        return
      else
        render json: { error: "Invalid operation: #{operation}" }, status: :unprocessable_entity
        return
      end
    else
      render json: { error: "Invalid event: #{event}" }, status: :unprocessable_entity
      return
    end

    # Make an HTTP request to the appropriate endpoint
    response = HTTP.post("https://api.sellioly.com/server/#{endpoint}", :form => { 'handle' => handle, event_id => shop_id, 'app_domain' => app_domain })
    if response.status.success?
      response_string = response.body.to_s
      if handle
        redis_set(app_domain, shop_id, "#{event}:#{id}", response_string)
      else
        redis_set(app_domain, -1, "#{event}", response_string)
      end

      render json: { message: "Synchronized #{event} with #{handle ? 'id' : 'domain'} #{handle || app_domain}" }
    else
      render json: { error: "unsuccessful api #{endpoint}" }, status: :unprocessable_entity
    end
  end

end
