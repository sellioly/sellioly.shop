require "zip"

class TemplateController < ApplicationController
  include ErrorHandling
  include RequestLogging
  include InputValidation

  # Allowed file extensions for template files
  ALLOWED_EXTENSIONS = %w[.liquid .json .css .js .png .jpg .jpeg .gif .svg .webp .woff .woff2 .ttf .eot .ico .avif].freeze

  # before_action :verify_ssl_hook
  skip_before_action :verify_authenticity_token
  before_action :find_shop_theme, only: [
    :request_template_page,
    :request_assets_template,
    :request_asset_content,
    :update_asset_content,
    :create_asset_file,
    :delete_asset_file,
    :create_asset_directory,
    :move_asset_file,
    :upload_asset_file,
    :request_template
  ]

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
    @shop_id = params[:shop_id]
    @template_id = params[:template_id]
    @domain = params[:app_domain].to_s

    shop = Shop.find_by(app_domain: @domain)
    raise ActiveRecord::RecordNotFound, "Shop not found" unless shop

    shop_theme = shop.shop_themes.find_by(external_template_id: @template_id)
    raise ActiveRecord::RecordNotFound, "Theme not found" unless shop_theme

    # Update shop to use this theme
    unless shop.update(
      template_path: shop_theme.root_path,
      active_shop_theme_id: shop_theme.id,
      active_external_template_id: shop_theme.external_template_id
    )
      raise ActiveRecord::RecordInvalid, shop
    end

    render json: {
      msg: 'template has been published',
      id: shop.id,
      template_path: shop_theme.root_path
    }
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
    @request_page = params[:page].to_s
    base_path = resolve_template_path

    page_file = File.join(base_path, 'templates', "#{@request_page}.json")
    layout_file = File.join(base_path, 'layout', 'theme.json')

    begin
      page_data = JSON.parse(File.read(page_file))
      layout_data = JSON.parse(File.read(layout_file))

      # Determine layout name
      layout = page_data['layout'] || 'theme'
      if layout != 'theme'
        layout_file = File.join(base_path, 'layout', "#{layout}.json")
        layout_data = JSON.parse(File.read(layout_file)) if File.exist?(layout_file)
      end

      # Load schemas for sections
      layout_forms = build_section_forms(layout_data['sections'] || {}, base_path)
      forms = build_section_forms(
        page_data['sections'] || {},
        base_path,
        page_data['order'] || []
      )

      render json: {
        page: {
          order: page_data['order'],
          sections: forms
        },
        layout: {
          sections: layout_forms
        },
        original: {
          page: page_data,
          layout: layout_data
        }
      }
    rescue Errno::ENOENT => e
      raise Template::TemplateFileService::FileNotFoundError, "Template file not found: #{e.message}"
    rescue JSON::ParserError => e
      raise Template::TemplateFileService::InvalidFileTypeError, "Invalid JSON: #{e.message}"
    end
  end

  def request_assets_template
    base_path = resolve_template_path
    entries = []

    Dir.glob("#{base_path}/**/*") do |file_path|
      next if File.directory?(file_path)

      file_name = file_path.sub("#{base_path}/", "")
      created_at = File.ctime(file_path).strftime("%Y-%m-%d %H:%M:%S")
      updated_at = File.mtime(file_path).strftime("%Y-%m-%d %H:%M:%S")
      ext_type = File.extname(file_path)
      content_type = ext_type == '.liquid' ? 'application/x-liquid' : Rack::Mime.mime_type(ext_type)

      entries.push({
        key: file_name,
        created_at: created_at,
        updated_at: updated_at,
        extension: ext_type,
        content_type: content_type,
        size: File.size(file_path)
      })
    end

    render json: entries.sort_by { |e| e[:key] }
  end

  def request_asset_content
    key = params[:key].to_s
    base_path = resolve_template_path
    file_path = sanitize_file_path(base_path, key)

    raise Template::TemplateFileService::FileNotFoundError, "File not found: #{key}" unless File.exist?(file_path)
    raise Template::TemplateFileService::SecurityError, "Path outside template directory" unless file_path.start_with?(base_path)

    ext_type = File.extname(file_path)
    mime_type = ext_type == '.liquid' ? 'application/x-liquid' : Rack::Mime.mime_type(ext_type)
    content = File.read(file_path)
    render body: content, content_type: mime_type
  end

  def update_asset_content
    key = params[:key].to_s
    content = params[:content].to_s
    base_path = resolve_template_path
    file_path = sanitize_file_path(base_path, key)

    raise Template::TemplateFileService::FileNotFoundError, "File not found: #{key}" unless File.exist?(file_path)
    raise Template::TemplateFileService::SecurityError, "Path outside template directory" unless file_path.start_with?(base_path)
    raise Template::TemplateFileService::FileTooLargeError, "File too large" if content.bytesize > 10 * 1024 * 1024
    validate_file_extension(key)

    # Validate JSON syntax for .json files
    validate_json_content(content, key) if key.end_with?('.json')

    File.write(file_path, content)

    ext_type = File.extname(file_path)
    mime_type = ext_type == '.liquid' ? 'application/x-liquid' : Rack::Mime.mime_type(ext_type)
    render body: content, content_type: mime_type
  end

  def request_template
    base_path = resolve_template_path

    raise Template::TemplateFileService::FileNotFoundError, "Template not found" unless Dir.exist?(base_path)

    bundle_filename = Rails.root.join('tmp', "#{@shop_theme.id}-#{Time.now.to_i}.zip").to_s
    FileUtils.mkdir_p(File.dirname(bundle_filename))
    FileUtils.rm(bundle_filename, force: true)

    Zip::File.open(bundle_filename, Zip::File::CREATE) do |zipfile|
      Dir.chdir(base_path)
      Dir.glob("**/*").each do |file|
        next if File.directory?(file)
        zipfile.add(file.sub("#{base_path}/", ''), file)
      end
    end

    send_file bundle_filename, type: "application/zip", disposition: "attachment"
  ensure
    FileUtils.rm(bundle_filename, force: true) rescue nil if bundle_filename
  end

  # NEW: Create file
  def create_asset_file
    key = params[:key].to_s
    content = params[:content].to_s
    base_path = resolve_template_path
    file_path = sanitize_file_path(base_path, key)

    raise Template::TemplateFileService::SecurityError, "Path outside template directory" unless file_path.start_with?(base_path)
    raise Template::TemplateFileService::FileTooLargeError, "File too large" if content.bytesize > 10 * 1024 * 1024
    validate_file_extension(key)

    # Validate JSON syntax for .json files
    validate_json_content(content, key) if key.end_with?('.json')

    # Create directory if needed
    FileUtils.mkdir_p(File.dirname(file_path))
    File.write(file_path, content)

    render json: {
      success: true,
      file: build_file_entry(key, file_path)
    }, status: :created
  end

  # NEW: Delete file
  def delete_asset_file
    key = params[:key].to_s
    base_path = resolve_template_path
    file_path = sanitize_file_path(base_path, key)

    raise Template::TemplateFileService::FileNotFoundError, "File not found: #{key}" unless File.exist?(file_path)
    raise Template::TemplateFileService::SecurityError, "Path outside template directory" unless file_path.start_with?(base_path)

    File.delete(file_path)
    render json: { success: true, deleted: key }
  end

  # NEW: Create directory
  def create_asset_directory
    key = params[:key].to_s
    base_path = resolve_template_path
    dir_path = sanitize_file_path(base_path, key)

    raise Template::TemplateFileService::SecurityError, "Path outside template directory" unless dir_path.start_with?(base_path)

    FileUtils.mkdir_p(dir_path)
    render json: { success: true, path: key }, status: :created
  end

  # NEW: Move/rename file
  def move_asset_file
    old_key = params[:old_key].to_s
    new_key = params[:new_key].to_s
    base_path = resolve_template_path
    old_path = sanitize_file_path(base_path, old_key)
    new_path = sanitize_file_path(base_path, new_key)

    raise Template::TemplateFileService::FileNotFoundError, "File not found: #{old_key}" unless File.exist?(old_path)
    raise Template::TemplateFileService::SecurityError, "Path outside template directory" unless old_path.start_with?(base_path) && new_path.start_with?(base_path)

    FileUtils.mkdir_p(File.dirname(new_path))
    FileUtils.mv(old_path, new_path)

    render json: {
      success: true,
      file: build_file_entry(new_key, new_path)
    }
  end

  # NEW: Upload binary file
  def upload_asset_file
    raise ActionController::ParameterMissing, "file parameter is required" unless params[:file].present?

    file = params[:file]
    filename = params[:filename] || file.original_filename
    key = params[:key] # Optional: specify custom path

    base_path = resolve_template_path

    # Determine upload path
    if key.present?
      upload_path = sanitize_file_path(base_path, key)
    else
      # Default to assets folder
      if image_file?(filename)
        upload_path = File.join(base_path, "assets", filename)
      elsif font_file?(filename)
        upload_path = File.join(base_path, "assets", "fonts", filename)
      else
        upload_path = File.join(base_path, "assets", filename)
      end
      upload_path = sanitize_file_path(base_path, upload_path.sub("#{base_path}/", ""))
    end

    raise Template::TemplateFileService::SecurityError, "Path outside template directory" unless upload_path.start_with?(base_path)
    raise Template::TemplateFileService::FileTooLargeError, "File too large" if file.size > 10 * 1024 * 1024
    validate_file_extension(filename)

    FileUtils.mkdir_p(File.dirname(upload_path))
    File.binwrite(upload_path, file.read)

    relative_key = upload_path.sub("#{base_path}/", "")
    render json: {
      success: true,
      file: build_file_entry(relative_key, upload_path)
    }, status: :created
  end

  private

  def find_shop_theme
    # Get store_id from X-Store-ID header (preferred) or fallback to params
    store_id = request.headers['X-Store-ID'] || request.headers['X-Store-Id'] || params[:shop_id]
    template_id = params[:template_id]

    shop = Shop.find_by(external_store_id: store_id)
    raise ActiveRecord::RecordNotFound, "Shop not found" unless shop

    @shop_theme = shop.shop_themes.find_by(external_template_id: template_id)
    raise ActiveRecord::RecordNotFound, "Theme not found" unless @shop_theme
  end

  def resolve_template_path
    if @shop_theme&.root_path.present?
      root_path = @shop_theme.root_path.sub(%r{\A/}, "")
      Rails.root.join(root_path).to_s
    else
      # Legacy fallback (should be removed after migration)
      shop_id = @shop_theme&.shop&.id || params[:shop_id]
      template_id = @shop_theme&.external_template_id || params[:template_id]
      Rails.root.join("storage", shop_id.to_s, template_id.to_s).to_s
    end
  end

  def sanitize_file_path(base_path, key)
    # Remove leading slashes and prevent directory traversal
    safe_key = key.to_s
      .gsub(%r{\.\./}, '')           # Remove ../
      .gsub(%r{^/}, '')              # Remove leading /
      .gsub(%r{//+}, '/')             # Normalize multiple slashes

    full_path = File.join(base_path, safe_key)

    # Ensure path is within base_path (prevent directory traversal)
    begin
      real_base = File.realpath(base_path)
      
      # If file exists, use realpath; otherwise check the directory
      if File.exist?(full_path)
        real_path = File.realpath(full_path)
      else
        # For new files, check that the directory path is within base
        dir_path = File.dirname(full_path)
        if File.exist?(dir_path)
          real_dir = File.realpath(dir_path)
          unless real_dir.start_with?(real_base)
            raise Template::TemplateFileService::SecurityError, "Path traversal detected"
          end
        end
        # For new files, normalize the path
        real_path = File.expand_path(full_path)
      end

      # Final check: ensure resolved path is within base
      unless real_path.start_with?(real_base)
        raise Template::TemplateFileService::SecurityError, "Path traversal detected"
      end

      real_path
    rescue Errno::ENOENT
      # If base doesn't exist, validate the path structure manually
      expanded_base = File.expand_path(base_path)
      expanded_path = File.expand_path(full_path)
      
      unless expanded_path.start_with?(expanded_base)
        raise Template::TemplateFileService::SecurityError, "Path traversal detected"
      end
      
      full_path
    end
  end

  def build_section_forms(sections, base_path, order = nil)
    forms = {}
    sections_to_process = order ? sections.select { |k, _| order.include?(k) } : sections

    sections_to_process.each do |section_id, section_data|
      forms[section_id] = { schema: nil, data: section_data }

      schema_path = File.join(base_path, 'schemas', "#{section_data['type']}.json")
      if File.exist?(schema_path)
        begin
          forms[section_id]['schema'] = JSON.parse(File.read(schema_path))
        rescue JSON::ParserError
          # Schema parse error, keep as nil
        end
      end
    end

    forms
  end

  def build_file_entry(key, full_path)
    {
      key: key,
      created_at: File.ctime(full_path).strftime("%Y-%m-%d %H:%M:%S"),
      updated_at: File.mtime(full_path).strftime("%Y-%m-%d %H:%M:%S"),
      extension: File.extname(full_path),
      content_type: mime_type_for(full_path),
      size: File.size(full_path)
    }
  end

  def mime_type_for(path)
    ext = File.extname(path).downcase
    case ext
    when '.liquid'
      'application/x-liquid'
    when '.json'
      'application/json'
    else
      Rack::Mime.mime_type(ext) || 'application/octet-stream'
    end
  end

  def image_file?(filename)
    %w[.png .jpg .jpeg .gif .webp .svg .ico .avif].include?(File.extname(filename).downcase)
  end

  def font_file?(filename)
    %w[.woff .woff2 .eot .ttf].include?(File.extname(filename).downcase)
  end

  def validate_file_extension(filename)
    ext = File.extname(filename).downcase
    unless ALLOWED_EXTENSIONS.include?(ext)
      raise Template::TemplateFileService::InvalidFileTypeError, "File type not allowed: #{ext}. Allowed types: #{ALLOWED_EXTENSIONS.join(', ')}"
    end
  end

  def validate_json_content(content, filename)
    return unless filename.end_with?('.json')

    begin
      JSON.parse(content)
    rescue JSON::ParserError => e
      raise Template::TemplateFileService::InvalidFileTypeError, "Invalid JSON syntax in #{filename}: #{e.message}"
    end
  end
end
