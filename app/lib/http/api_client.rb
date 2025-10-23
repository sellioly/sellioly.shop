# frozen_string_literal: true

# Single boundary for all calls to api.sellioly.com
# - Per-request timeouts and SSL verification (does NOT rely on global HTTP.default_options)
# - Small, typed result object with status + parsed JSON
# - Mirrors your current endpoints and form params
module Http
  class ApiClient
    Result = Struct.new(:ok?, :status, :json, :error, keyword_init: true)

    DEFAULT_OPEN_TIMEOUT = (ENV["HTTP_OPEN_TIMEOUT"] || 2).to_f # seconds
    DEFAULT_READ_TIMEOUT = (ENV["HTTP_READ_TIMEOUT"] || 3).to_f # seconds
    DEFAULT_RETRIES      = (ENV["HTTP_RETRIES"] || 1).to_i

    def initialize(base_url: ENV.fetch("API_BASE_URL", "https://api.sellioly.com"))
      @base_url = base_url.chomp("/")
    end

    # ---- Public API wrappers -------------------------------------------------
    def product_by_handle(handle:, shop_id:, domain:)
      post_json("/ruby/product/get-by-handle", handle: handle, shop_id: shop_id, app_domain: domain)
    end

    def collection_by_handle(handle:, shop_id:, domain:)
      post_json("/ruby/collection/get-by-handle", handle: handle, shop_id: shop_id, app_domain: domain)
    end

    def menu_by_handle(handle:, shop_id:, domain:)
      post_json("/ruby/menu/get-by-handle", handle: handle, shop_id: shop_id, app_domain: domain)
    end

    def shop_info(shop_id:)
      post_json("/ruby/store/infos", shop_id: shop_id)
    end

    def metadata(shop_id:, domain:)
      post_json("/ruby/metadata/store/list", shop_id: shop_id, app_domain: domain)
    end

    def similar_products_by_handle(handle:, shop_id:, domain:)
      post_json("/ruby/product/get-similar-by-handle", handle: handle, user_id: shop_id, app_domain: domain)
    end

    def verify_domain(domain:, app_domain:)
      post_json("/ruby/domain/verify", domain: domain, app_domain: app_domain)
    end

    # ---- Internals -----------------------------------------------------------
    private

    def post_json(path, **form)
      tries = 0
      begin
        response = http.post(url_for(path), form: form)
        if response.status.success?
          return Result.new(ok?: true, status: response.status.to_i, json: safe_parse(response))
        end
        Result.new(ok?: false, status: response.status.to_i, error: response.body.to_s)
      rescue StandardError => e
        tries += 1
        retry if tries <= DEFAULT_RETRIES
        Result.new(ok?: false, status: 599, error: e.message)
      end
    end

    def http
      @http ||= HTTP.use(:auto_inflate)
                   .timeout(connect: DEFAULT_OPEN_TIMEOUT, read: DEFAULT_READ_TIMEOUT)
                   .headers("User-Agent" => "Sellioly-RubyShop/1 ApiClient")
                   .persistent(@base_url)
    end

    def url_for(path)
      path.start_with?("/") ? (@base_url + path) : ("#{@base_url}/#{path}")
    end

    def safe_parse(response)
      response.parse
    rescue StandardError
      JSON.parse(response.body.to_s) rescue { "raw" => response.body.to_s }
    end
  end
end
