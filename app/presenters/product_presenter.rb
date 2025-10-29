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
#     "id","handle","title","vendor","description_html",
#     "options"  => [{ "id","name","values":[...] }, ...],
#     "variants" => [
#       {
#         "id","title","sku","available",
#         "price_cents","compare_at_cents",
#         "options"   => { "Color"=>"blue", ... },
#         "image"     => { "id","src","alt","width","height" } | nil,
#         "images"    => [ { ... }, ... ],
#         "image_id"  => "...", # kept for reference
#       }, ...
#     ],
#     "media"       => [ { "id","src","alt","width","height" }, ... ],
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
        "vendor"           => base["vendor"],
        "options"          => base["options"],
        "variants"         => variants,
        "media"            => base["media"],
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

    {
      "id"               => p["id"],
      "handle"           => p["handle"],
      "title"            => p["title"],
      "vendor"           => p["vendor"],
      "description_html" => p["body_html"].to_s,
      "options"          => normalize_options(p),
      # variants depend on media (for image composition)
      "variants"         => normalize_variants(p, media),
      "media"            => media
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
        "available"        => infer_available(v),
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
    images = Array(p["images"])
    # Ensure default_image is present in media if missing
    if p["default_image"].is_a?(Hash) && !images.any? { |img| img["id"].to_s == p["default_image"]["id"].to_s }
      images = [p["default_image"], *images]
    end

    images.map do |img|
      {
        "id"     => img["id"],
        "src"    => img["src"],
        "alt"    => p["title"].to_s,
        "width"  => img["width"],
        "height" => img["height"]
      }
    end
  end

  # Laravel variant options come in v["option"]["option1".."option3"]
  # e.g. { "option1"=>{"name"=>"color","value"=>"black"}, "option2"=>nil, ... }
  def extract_variant_options(v)
    result = {}
    opt    = v["option"] || {}
    %w[option1 option2 option3].each do |slot|
      item = opt[slot]
      next unless item.is_a?(Hash)
      name  = normalize_option_name(item["name"])
      value = item["value"].to_s
      result[name] = value
    end
    result
  end

  def normalize_option_name(name)
    s = name.to_s.strip
    s.empty? ? s : s[0].upcase + s[1..]
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
    if val.is_a?(Integer)
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
