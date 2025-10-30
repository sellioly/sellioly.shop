# app/jobs/get_template_from_aws_job.rb
# frozen_string_literal: true

require "zip"
require "faraday"
require "json"
require "openssl"

class GetTemplateFromAwsJob < ApplicationJob
  queue_as :default

  # ---- Config ----
  CALLBACK_SUCCESS = ENV.fetch("TEMPLATE_CALLBACK_SUCCESS", "https://api.sellioly.com/ruby/template-uploaded/success")
  CALLBACK_FAILED  = ENV.fetch("TEMPLATE_CALLBACK_FAILED",  "https://api.sellioly.com/ruby/template-uploaded/failed")
  CALLBACK_SECRET  = ENV.fetch("SELLIOLY_SHARED_SECRET",    nil) # optional HMAC signing
  STORAGE_ROOT     = ENV.fetch("THEME_STORAGE_ROOT",         Rails.root.join("storage").to_s)

  HTTP_OPEN_TIMEOUT = 10
  HTTP_TIMEOUT      = 30

  # Required files inside the zip
  REQUIRED_FILES = %w[
    config/settings_theme.json
    config/settings_data.json
    config/settings_schema.json
    layout/theme.liquid
    layout/theme.json
  ].freeze

  # What to extract (globs)
  EXTRACT_GLOBS = [
    "assets/*.css",
    "assets/*.js",
    "assets/fonts/*.{eot,ttf,woff,woff2}",
    "assets/**/*.{png,jpg,jpeg,webp,svg,gif,ico,avif}",
    "config/*.json",
    "layout/*.liquid",
    "layout/*.json",
    "locales/*.json",
    "schemas/*.json",
    "sections/*.liquid",
    "snippets/*.liquid",
    "components/*.liquid",
    "templates/*.json"
  ].freeze

  def perform(shop_id, template_id, url_theme)
    Rails.logger.info("[ThemeImport] start shop_id=#{shop_id} template_id=#{template_id} url=#{url_theme}")

    base_dir = File.join(STORAGE_ROOT, shop_id.to_s, template_id.to_s)
    FileUtils.mkdir_p(base_dir)

    zip_bytes = download_zip(url_theme)
    errors, settings = validate_and_extract(zip_bytes, base_dir)

    if errors.empty?
      payload = success_payload(shop_id, template_id, base_dir, settings)
      post_callback(CALLBACK_SUCCESS, payload)
      Rails.logger.info("[ThemeImport] success shop_id=#{shop_id} template_id=#{template_id} saved_to=#{base_dir} files=#{Dir.glob(File.join(base_dir, '**', '*')).count}")
    else
      post_callback(CALLBACK_FAILED, failed_payload(shop_id, template_id, errors))
      Rails.logger.warn("[ThemeImport] failed shop_id=#{shop_id} template_id=#{template_id} errors=#{errors.join(' | ')}")
    end
  rescue => e
    # Best-effort failure callback; avoid infinite retries spam by not re-raising.
    Rails.logger.error("[ThemeImport] exception #{e.class}: #{e.message}\n#{e.backtrace&.first(15)&.join("\n")}")
    post_callback(CALLBACK_FAILED, failed_payload(shop_id, template_id, ["exception: #{e.message}"])) rescue nil
  end

  private

  # ---- Network ----

  def http_client_json
    Faraday.new do |f|
      f.request :json
      f.response :raise_error # raise on 4xx/5xx
      f.options.open_timeout = HTTP_OPEN_TIMEOUT
      f.options.timeout      = HTTP_TIMEOUT
      f.adapter Faraday.default_adapter
    end
  end

  def http_client_raw
    Faraday.new do |f|
      f.options.open_timeout = HTTP_OPEN_TIMEOUT
      f.options.timeout      = HTTP_TIMEOUT
      f.adapter Faraday.default_adapter
    end
  end

  def download_zip(url)
    resp = http_client_raw.get(url)
    unless resp.success? && resp.body && resp.body.bytesize.positive?
      raise "S3 download failed status=#{resp.status}"
    end
    resp.body
  end

  def post_callback(url, payload)
    headers = { "Accept" => "application/json", "Content-Type" => "application/json" }
    if CALLBACK_SECRET
      sig = OpenSSL::HMAC.hexdigest("SHA256", CALLBACK_SECRET, payload.to_json)
      headers["X-Sellioly-Signature"] = sig
    end
    res = http_client_json.post(url, payload, headers)
    Rails.logger.info("[ThemeImport] callback POST #{url} status=#{res.status}")
  end

  # ---- Zip handling ----

  def validate_and_extract(zip_bytes, base_dir)
    errors = []
    settings = {}

    Zip::File.open_buffer(zip_bytes) do |zip|
      # Validate required files
      REQUIRED_FILES.each do |req|
        errors << "#{req} is missing!" unless zip.find_entry(req)
      end

      # If critical files missing, skip extraction but still return errors
      return [errors, settings] unless errors.empty?

      # Extract everything we care about
      EXTRACT_GLOBS.each { |pattern| extract_glob(zip, pattern, base_dir) }

      # Load settings for callback metadata
      theme_json_path = File.join(base_dir, "config", "settings_theme.json")
      settings = JSON.parse(File.read(theme_json_path))
    end

    [errors, settings]
  end

  def extract_glob(zip, pattern, root)
    zip.glob(pattern).each do |entry|
      # Safety: avoid directory traversal
      next if entry.name.include?("..")

      target = File.join(root, entry.name)
      FileUtils.mkdir_p(File.dirname(target))

      # Overwrite duplicates
      entry.extract(target) { true }
    rescue Zip::Error => e
      Rails.logger.warn("[ThemeImport] zip extract warning for #{entry.name}: #{e.message}")
    end
  end

  # ---- Payloads ----

  def success_payload(shop_id, template_id, base_dir, settings)
    {
      shop_id:        shop_id,
      template_id:    template_id,
      template_path:  relative_template_path(base_dir),
      theme_name:     settings["theme_name"],
      theme_version:  settings["theme_version"],
      theme_author:   settings["theme_author"],
      theme_support_url: settings["theme_support_url"]
    }
  end

  def failed_payload(shop_id, template_id, reasons)
    {
      shop_id:     shop_id,
      template_id: template_id,
      reason:      Array(reasons).map(&:to_s)
    }
  end

  def relative_template_path(abs_path)
    # Return a path like "/storage/<shop>/<template>" to match your Laravel expectation
    # If STORAGE_ROOT ends with "/storage", this will work as-is.
    if STORAGE_ROOT.end_with?("/storage")
      abs_path.sub(Rails.root.to_s, "")
    else
      # Fallback: compute relative from STORAGE_ROOT
      rel = abs_path.sub(STORAGE_ROOT, "")
      File.join("/storage", rel) # ensures leading "/storage"
    end
  end
end
