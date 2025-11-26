# app/controllers/assets_controller.rb
# frozen_string_literal: true

class AssetsController < ActionController::Base
  # We don’t need initialize_shop here. Assets are static by path.

  # Allow cross-origin GETs for static files (JS/CSS/fonts/images)
  skip_forgery_protection only: :show  # <-- this removes the 422

  before_action :set_asset_cors_headers

  # GET /files/1/:shop_id/:template_id/assets/*filepath
  def show
    shop_id     = params[:shop_id].to_s
    template_id = params[:template_id].to_s
    
    filepath = params[:filepath].to_s
    if params[:format].present? && !filepath.end_with?(".#{params[:format]}")
      filepath = "#{filepath}.#{params[:format]}"
    end

    # shop_id in URL is external_store_id (ULID from Laravel), not Ruby Shop.id
    shop = Shop.find_by(external_store_id: shop_id)
    return head :not_found unless shop&.active_shop_theme&.root_path.present?

    # 1) resolve theme root from the active shop theme (ProvisionShopTemplateJob sets root_path on ShopTheme)
    theme_root = resolve_theme_root(shop, template_id)
    return head :not_found unless theme_root
    assets_root = theme_root.join("assets")
    return head :not_found unless File.directory?(assets_root)

    # 2) sanitize and resolve path (no traversal)
    safe_rel = sanitize_relative_path(filepath)
    return head :not_found if safe_rel.nil?

    absolute = assets_root.join(safe_rel)

    # Ensure final path is inside theme_root/assets
    return head :not_found unless inside_dir?(absolute, assets_root)
    return head :not_found unless File.file?(absolute)

    # 3) content type
    content_type = mime_for(absolute)

    # 4) caching
    stat          = File.stat(absolute)
    last_modified = stat.mtime.utc
    etag          = %W[a#{stat.size} m#{last_modified.to_i}].join("-")

    if stale?(etag: etag, last_modified: last_modified, public: true)
      # 5) long cache for fingerprinted URLs; otherwise reasonable default
      expires_in 24.hours, public: true
      headers["Content-Type"] = content_type

      # Optional: Offload to web server if available
      if ENV["USE_X_SENDFILE"] == "1"
        headers["X-Sendfile"] = absolute.to_s
        head :ok
      elsif ENV["USE_X_ACCEL"] == "1"
        # Example for NGINX: map /protected to your storage directory
        internal_path = absolute.to_s.sub(Rails.root.join("storage").to_s, "/protected")
        headers["X-Accel-Redirect"] = internal_path
        headers["Content-Type"] = content_type
        head :ok
      else
        send_file absolute, disposition: "inline", type: content_type
      end
    end
  end

  private

  # Allow only safe relative paths
  def sanitize_relative_path(p)
    return nil if p.blank?
    # reject absolute or traversal
    return nil if p.start_with?("/", "\\") || p.include?("..")
    # normalize slashes, strip any leading separators
    p.gsub("\\", "/").sub(%r{\A/+}, "")
  end

  def inside_dir?(path, dir)
    path = Pathname.new(path).expand_path
    dir  = Pathname.new(dir).expand_path
    path.to_s.start_with?(dir.to_s + File::SEPARATOR) || path.to_s == dir.to_s
  end

  def mime_for(path)
    ext = File.extname(path.to_s).downcase
    case ext
    when ".css"  then "text/css"
    when ".js"   then "application/javascript"
    when ".svg"  then "image/svg+xml"
    when ".jpg", ".jpeg" then "image/jpeg"
    when ".png"  then "image/png"
    when ".gif"  then "image/gif"
    when ".webp" then "image/webp"
    when ".avif" then "image/avif"

    # .map files
    when ".map"  then "application/json"

    # fonts
    when ".woff" then "font/woff"
    when ".woff2" then "font/woff2"
    when ".ttf"  then "font/ttf"
    when ".otf"  then "font/otf"
    when ".eot"  then "application/vnd.ms-fontobject"
    # fall back
    else Rack::Mime.mime_type(ext, "application/octet-stream")
    end
  end

  def set_asset_cors_headers
    # Allow embedding of JS/CSS/fonts from any origin (adjust if you want to restrict)
    headers["Access-Control-Allow-Origin"] = "*"
    headers["Vary"] = "Origin"
    # If you need credentials/cookies for assets (usually not), set ACA-Credentials too.
  end

  def resolve_theme_root(shop, template_id)
    # Get root_path from active_shop_theme (source of truth set by ProvisionShopTemplateJob)
    shop_theme = shop.active_shop_theme
    return nil unless shop_theme

    rel_path = shop_theme.root_path.to_s.sub(%r{\A/}, "")
    return nil if rel_path.blank?

    root = Rails.root.join(rel_path)
    return nil unless File.directory?(root)

    # Optional safety: ensure template_id (external_template_id ULID) matches when provided
    if template_id.present?
      # template_id is external_template_id (ULID), compare with shop_theme.external_template_id
      return nil unless shop_theme.external_template_id == template_id
    end

    root
  end
end
