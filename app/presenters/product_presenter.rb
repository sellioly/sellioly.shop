# frozen_string_literal: true

class ProductPresenter
  # Public API
  # - product:  raw Laravel hash (كما هو في المثال)
  # - params:   request query params (لـ variant_id)
  # - currency: e.g. "MAD"
  #
  # Returns a normalized hash جاهز للـ Liquid:
  # {
  #   "product" => {...},
  #   "selected_variant" => {...},
  #   "variant_index" => { "by_id" => {...}, "by_options" => {...} },
  #   "variant_image_map" => {...},
  #   "urls" => { "canonical" => "...", "variant_url" => "...?variant_id={{ variant_id }}" }
  # }
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

    # خرائط مساعدة
    by_id, by_opts = build_variant_indices(variants, base["options"])
    img_map        = build_variant_image_map(variants)

    # مدى الأسعار
    price_range = compute_price_range_cents(variants)

    # أعلام مساعدة
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
        "variant_url" => "/products/#{base["handle"]}?variant_id={{ variant_id }}"
      }
    }
  end

  private

  # ---------- Normalization ----------

  def normalize_product(p)
    {
      "id"               => p["id"],
      "handle"           => p["handle"],
      "title"            => p["title"],
      "vendor"           => p["vendor"],
      "description_html" => p["body_html"].to_s, # نخلي التنقية (sanitize) لطبقة العرض إن لزم

      "options"  => normalize_options(p),
      "variants" => normalize_variants(p),
      "media"    => normalize_media(p)
    }
  end

  def normalize_options(p)
    # Laravel الآن يرسل options[] بالاسم "options"
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

  def normalize_variants(p)
    Array(p["variants"]).map do |v|
      opts = extract_variant_options(v)
      {
        "id"               => v["id"],
        "title"            => v["title"],
        "sku"              => v["sku"],
        "available"        => infer_available(v),
        "price_cents"      => to_cents(v["price"]),
        "compare_at_cents" => to_cents(v["compare_at_price"]),
        "options"          => opts,                 # {"Color"=>"black", ...}
        "image_id"         => v["image_id"]
      }
    end
  end

  def normalize_media(p)
    images = Array(p["images"])
    # تأكد أن default_image موجود ضمن القائمة (لو ناقص)
    if p["default_image"].is_a?(Hash) && !images.any? { |img| img["id"].to_s == p["default_image"]["id"].to_s }
      images = [p["default_image"], *images]
    end

    images.map do |img|
      {
        "id"          => img["id"],
        "src"         => img["src"],
        "alt"         => p["title"].to_s,
        "width"       => img["width"],
        "height"      => img["height"],
        "variant_ids" => [] # سنربط لاحقًا عبر build_variant_image_map
      }
    end
  end

  # يستخرج خيارات الفاريانت من هيكل Laravel الحالي:
  # v["option"]["option1"] => {"name"=>"color","value"=>"black"}
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
    # نثبت تنسيق الاسم (Capitalized أول حرف فقط)، مثلاً "color" => "Color"
    s = name.to_s.strip
    s.empty? ? s : s[0].upcase + s[1..]
  end

  # ---------- Selection / Indices ----------

  def resolve_selected_variant(variants)
    return nil if variants.empty?

    # 1) ?variant_id=<id>
    if (vid = (@params[:variant_id] || @params["variant_id"])).to_s.strip
      found = variants.find { |v| v["id"].to_s == vid.to_s }
      return found if found
    end

    # 2) أول متاح، وإلا الأول
    variants.find { |v| v["available"] } || variants.first
  end

  def build_variant_indices(variants, product_options)
    by_id   = {}
    by_opts = {}

    option_names = Array(product_options).map { |o| o["name"] }

    variants.each do |v|
      by_id[v["id"].to_s] = v

      # ابنِ مفتاح by_options وفق ترتيب أسماء خيارات المنتج
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
      # نفترض أنه مبلغ بالعملة (MAD) وليس بالسنت، فنضرب × 100
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
    # Laravel response لا يحتوي دايمًا على مخزون؛ كبداية اعتبره متاح إن ماكانش في معلومة ضد
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
    when Hash
      obj.transform_keys(&:to_s).transform_values { |v| deep_stringify(v) }
    when Array
      obj.map { |v| deep_stringify(v) }
    else
      obj
    end
  end
end
