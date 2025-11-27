# frozen_string_literal: true

# Normalizes a raw Laravel product payload into a clean, theme-friendly shape.
# Key points:
# - All money in integer cents (avoid floats).
# - Each variant includes:
#     - image:   its main image (if any)
#     - images:  [main image, ...general images not tied to other variants]
# - Selected variant resolved via ?variant_id=<id> (fallback: first available, else first).
# - Builds simple indices for fast lookups on the front (by id and by options).
# - Leaves sanitization of HTML (if needed) to the view layer.
#
# Returned shape:
# {
#   "product" => {
#     "id","handle","title","description_html","status","published_at",
#     "options"  => [{ "id","name","values":[...] }, ...],
#     "variants" => [
#       {
#         "id","title","sku","barcode","position","available","inventory_quantity",
#         "price_cents","compare_at_cents",
#         "options"   => { "Color"=>"blue", ... },
#         "image"     => { "id","src","alt","width","height" } | nil,
#         "images"    => [ { ... }, ... ],
#         "image_id"  => "...", # kept for reference
#       }, ...
#     ],
#     "media"       => [ { "id","src","alt","width","height" }, ... ],
#     "collections" => [ { "id","handle","title" }, ... ],
#     "collection"  => { "id","handle","title" } | nil, # Primary/first collection
#     "seo"         => { "title","description","canonical_url","robots" } | nil,
#     "price_range" => { "min"=>..., "max"=>... } | nil,
#     "available"   => true/false,
#     "on_sale"     => true/false,
#     "currency"    => "MAD"
#   },
#   "selected_variant"  => { ...same shape as in variants... } | nil,
#   "variant_index"     => {
#     "by_id"     => { "<id>" => {variant}, ... },
#     "by_options"=> { "Color:Blue|Size:M" => "<variant_id>", ... }
#   },
#   "urls" => {
#     "canonical"   => "/products/<handle>",
#     "variant_url" => "/products/<handle>?variant_id={{ variant_id }}"
#   }
# }
#
class ProductPresenter
  # Public API
  def self.call(product:, params:, currency:)
    new(product, params, currency).present
  end

  def initialize(product, params, currency)
    @raw      = deep_stringify(product || {})
    @params   = params || {}
    @currency = currency.to_s
  end

  def present
    base = normalize_product(@raw)

    variants = base["variants"]
    selected = resolve_selected_variant(variants)

    by_id, by_opts = build_variant_indices(variants, base["options"])
    img_map        = build_variant_image_map(variants)
    price_range     = compute_price_range_cents(variants)

    available = selected ? selected["available"] : true
    on_sale   = selected && sale?(selected["price_cents"], selected["compare_at_cents"])

    {
      "product" => {
        "id"               => base["id"],
        "handle"           => base["handle"],
        "title"            => base["title"],
        "description_html" => base["description_html"],
        "status"           => base["status"],
        "published_at"     => base["published_at"],
        "options"          => base["options"],
        "variants"         => variants,
        "media"            => base["media"],
        "collections"      => base["collections"],
        "collection"       => base["collection"],
        "seo"              => base["seo"],
        "price_range"      => price_range,
        "available"        => !!available,
        "on_sale"          => !!on_sale,
        "currency"         => @currency
      },
      "selected_variant"  => selected,
      "variant_index"     => { "by_id" => by_id, "by_options" => by_opts },
      "variant_image_map" => img_map,
      "urls"              => {
        "canonical"   => "/products/#{base["handle"]}",
        # Note: a template string so Liquid/JS can safely inject a concrete id
        "variant_url" => "/products/#{base["handle"]}?variant_id={{ variant_id }}"
      }
    }
  end

  private

  # ---------- Normalization ----------

  def normalize_product(p)
    media = normalize_media(p)
    collections_data = normalize_collections(p)
    seo_data = normalize_seo(p)

    {
      "id"               => p["id"],
      "handle"           => p["handle"],
      "title"            => p["title"],
      "status"           => p["status"],
      "published_at"     => p["published_at"],
      "description_html" => (p["description"] || p["body_html"] || "").to_s, # Support both new and old field names
      "options"          => normalize_options(p),
      # variants depend on media (for image composition)
      "variants"         => normalize_variants(p, media),
      "media"            => media,
      "collections"      => collections_data["collections"],
      "collection"       => collections_data["collection"],
      "seo"              => seo_data
    }
  end

  def normalize_options(p)
    list = Array(p["options"])
    return [] if list.empty?

    list.map do |o|
      {
        "id"     => o["id"],
        "name"   => normalize_option_name(o["name"]),
        "values" => Array(o["values"]).map { |v| v.to_s }
      }
    end
  end

  def normalize_variants(p, all_media)
    raw_variants = Array(p["variants"])

    # Collect image ids used by variants
    used_image_ids = raw_variants.map { |v| v["image_id"].to_s }.reject(&:empty?).to_set
    # General images = media not tied to any variant id
    general_images = all_media.reject { |img| used_image_ids.include?(img["id"].to_s) }

    raw_variants.map do |v|
      opts      = extract_variant_options(v)
      main_img  = all_media.find { |img| img["id"].to_s == v["image_id"].to_s }
      images    = [main_img, *general_images].compact.uniq { |img| img["id"] }

      {
        "id"               => v["id"],
        "title"            => v["title"],
        "sku"              => v["sku"],
        "barcode"          => v["barcode"],
        "position"         => v["position"],
        "available"        => infer_available(v),
        "inventory_quantity" => v["inventory_quantity"],
        "price_cents"      => to_cents(v["price"]),
        "compare_at_cents" => to_cents(v["compare_at_price"]),
        "options"          => opts,                 # {"Color"=>"black", ...}
        "image_id"         => v["image_id"],
        "image"            => main_img,            # can be nil
        "images"           => images               # [main + general]
      }
    end
  end

  def normalize_media(p)
    # Use new "media" field, fallback to "images" for backward compatibility
    images = Array(p["media"] || p["images"])

    images.map do |img|
      {
        "id"     => img["id"],
        "src"    => img["url"] || img["src"], # Map url to src (media now has full URLs from Laravel)
        "alt"    => img["alt"] || p["title"].to_s, # Use alt from media object (from ProductMedia pivot)
        "width"  => img["width"],
        "height" => img["height"]
      }
    end
  end

  # New format: v["options"] = [{"name": "Color", "value": "Red"}, ...]
  # Old format (backward compat): v["option"]["option1".."option3"]
  def extract_variant_options(v)
    # New format: structured options array
    if v["options"].is_a?(Array)
      v["options"].each_with_object({}) do |opt, result|
        next unless opt.is_a?(Hash)
        name = normalize_option_name(opt["name"])
        value = opt["value"].to_s
        result[name] = value if name.present? && value.present?
      end
    # Old format: nested option object with option1/option2/option3
    else
      result = {}
      opt = v["option"] || {}
      %w[option1 option2 option3].each do |slot|
        item = opt[slot]
        next unless item.is_a?(Hash)
        name = normalize_option_name(item["name"])
        value = item["value"].to_s
        result[name] = value
      end
      result
    end
  end

  def normalize_option_name(name)
    s = name.to_s.strip
    s.empty? ? s : s[0].upcase + s[1..]
  end

  def normalize_collections(p)
    collections = Array(p["collections"] || [])
    {
      "collections" => collections.map do |c|
        {
          "id" => c["id"],
          "handle" => c["handle"],
          "title" => c["title"]
        }
      end,
      "collection" => collections.first # Primary/first collection for breadcrumb convenience
    }
  end

  def normalize_seo(p)
    seo = p["seo"]
    return nil unless seo.is_a?(Hash)

    {
      "title" => seo["title"],
      "description" => seo["description"],
      "canonical_url" => seo["canonical_url"],
      "robots" => seo["robots"]
    }
  end

  # ---------- Selection / Indices ----------

  def resolve_selected_variant(variants)
    return nil if variants.empty?

    # 1) ?variant_id=<id>
    if (vid = (@params[:variant_id] || @params["variant_id"]).to_s).present?
      found = variants.find { |v| v["id"].to_s == vid }
      return found if found
    end

    # 2) First available, else first
    variants.find { |v| v["available"] } || variants.first
  end

  def build_variant_indices(variants, product_options)
    by_id   = {}
    by_opts = {}

    option_names = Array(product_options).map { |o| o["name"] }

    variants.each do |v|
      by_id[v["id"].to_s] = v
      key = options_key(v["options"], option_names)
      by_opts[key] = v["id"].to_s unless key.empty?
    end

    [by_id, by_opts]
  end

  def build_variant_image_map(variants)
    map = {}
    variants.each do |v|
      img_id = v["image_id"]
      map[v["id"].to_s] = img_id if img_id
    end
    map
  end

  def options_key(options_hash, option_names)
    return "" unless options_hash.is_a?(Hash) && option_names.any?
    parts = option_names.map do |name|
      val = options_hash[name]
      val ? "#{name}:#{val}" : nil
    end.compact
    parts.join("|")
  end

  # ---------- Helpers ----------

  def to_cents(val)
    return nil if val.nil?
    # New format: {"amount": 2999, "currency": "USD", "formatted": "$29.99"}
    # Amount is already in minor units (cents)
    if val.is_a?(Hash) && val["amount"]
      val["amount"].to_i
    elsif val.is_a?(Integer)
      # Laravel prices look like numbers in currency units; convert to cents
      (val * 100)
    elsif val.is_a?(Float)
      (val * 100).round
    else
      s = val.to_s.strip
      return nil if s.empty?
      (BigDecimal(s) * 100).round
    end
  rescue ArgumentError
    nil
  end

  def infer_available(v)
    # New format has direct "available" boolean
    return v["available"] if v.key?("available")
    # Fallback for old format
    inv = v["inventory_quantity"] || v["inventory"]
    return inv.to_i > 0 if inv
    true
  end

  def sale?(price_cents, compare_cents)
    p = price_cents.to_i
    c = compare_cents.to_i
    c > p && p > 0
  end

  def compute_price_range_cents(variants)
    cents_list = variants.map { |v| v["price_cents"] }.compact
    return nil if cents_list.empty?
    { "min" => cents_list.min, "max" => cents_list.max }
  end

  def deep_stringify(obj)
    case obj
    when Hash  then obj.transform_keys(&:to_s).transform_values { |v| deep_stringify(v) }
    when Array then obj.map { |v| deep_stringify(v) }
    else            obj
    end
  end
end
