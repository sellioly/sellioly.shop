# app/liquid/tags/paginate_tag.rb
# frozen_string_literal: true
require 'liquid'
require 'uri'

# الاستخدام:
# {% paginate items: collection, by: 24, param: 'page' %}
#   {% for p in paginate.items %} ... {% endfor %}
#   {% render 'pagination', paginate: paginate %}
# {% endpaginate %}
#
# يعمل تلقائياً بطريقتين:
# 1) Server-side: إذا كان items يحتوي على مفاتيح meta + data (قادمة من Laravel)
# 2) Client-side: إن كان items مصفوفة كاملة، يقسّم محليًا
#
# تشخيص الأخطاء:
# - في وضع preview (registers['preview'] == true) سيضيف تعليقات HTML تبدأ بـ <!-- PAGINATE_* -->
# - يسجل دائمًا أخطاء واضحة عبر Rails.logger مع سياق

module Tags
  class PaginateTag < Liquid::Block
    Syntax = /
      (?:\s*items:\s*(?<items>[^,]+))?
      (?:\s*,\s*by:\s*(?<by>\d+))?
      (?:\s*,\s*param:\s*(?<param>[^,]+))?
    /xo

    def initialize(tag_name, markup, options)
      super
      m = Syntax.match(markup.to_s)
      @items_expr = m && m[:items]
      @by         = (m && m[:by] ? m[:by].to_i : 24)
      @param      = (m && m[:param] ? m[:param].strip.delete("'\"") : 'page')
    end

    def render(context)
      preview = !!(context.registers && context.registers['preview'])
      assigns = context.environments.first || {}

      begin
        collection = evaluate_items(context, @items_expr)
        coll_hash  = to_hashish(collection)

        # ------- Server-side mode (data + meta) -------
        if coll_hash && coll_hash['meta'].is_a?(Hash)
          items = coll_hash['data'] || coll_hash['items'] || []
          meta  = coll_hash['meta']

          page      = safe_int(meta['current_page'], 1)
          page_size = safe_int(meta['per_page'],     @by)
          total     = safe_int(meta['total'],        items.is_a?(Array) ? items.length : 0)
          pages     = safe_int(meta['last_page'],    [(total.to_f / page_size).ceil, 1].max)

          base_url  = current_base_url(assigns)

          paginate_hash = {
            'items'        => Array(items),
            'current_page' => page,
            'page_size'    => page_size,
            'pages'        => pages,
            'total'        => total,
            'next_url'     => (page < pages ? build_url_with_params(base_url, assigns, @param, page + 1) : nil),
            'previous_url' => (page > 1 ? build_url_with_params(base_url, assigns, @param, page - 1) : nil)
          }

          inject_and_render_block(context, paginate_hash)
        else
          # ------- Client-side mode (local slice) -------
          items = Array(collection)
          page      = current_page_from(assigns, @param)
          page_size = [@by, 1].max
          total     = items.length
          pages     = [(total.to_f / page_size).ceil, 1].max
          page      = [[page, 1].max, pages].min
          offset    = (page - 1) * page_size
          slice     = items.slice(offset, page_size) || []

          base_url  = current_base_url(assigns)

          paginate_hash = {
            'items'        => slice,
            'current_page' => page,
            'page_size'    => page_size,
            'pages'        => pages,
            'total'        => total,
            'next_url'     => (page < pages ? build_url_with_params(base_url, assigns, @param, page + 1) : nil),
            'previous_url' => (page > 1 ? build_url_with_params(base_url, assigns, @param, page - 1) : nil)
          }

          inject_and_render_block(context, paginate_hash)
        end

      rescue => e
        # سجل الخطأ بتفاصيل واضحة
        log_error(e, context, @items_expr)

        # وفي وضع المعاينة أعط إشارة في HTML
        return preview_hint("PAGINATE_ERROR: #{e.class}: #{e.message}") if preview

        "" # في الإنتاج، لا نُسقط الصفحة
      end
    end

    private

    # يحاول تحويل أي قيمة إلى شكل Hash لاستخدام مفاتيح data/meta
    def to_hashish(obj)
      return obj if obj.is_a?(Hash)
      if obj.respond_to?(:to_liquid)
        val = obj.to_liquid
        return val if val.is_a?(Hash)
      end
      nil
    end

    def evaluate_items(context, expr)
      return [] unless expr
      context.evaluate(Liquid::Expression.parse(expr))
    rescue => e
      raise ArgumentError, "Failed to evaluate items expression: #{e.message}"
    end

    def inject_and_render_block(context, paginate_hash)
      context.stack do
        context['paginate'] = paginate_hash
        super
      end
    end

    # يبني base_url من assigns['current_url'] أو من request path + query
    def current_base_url(assigns)
      return assigns['current_url'] if assigns['current_url'].is_a?(String) && !assigns['current_url'].empty?

      req = assigns['request']
      return nil unless req.is_a?(Hash)

      path  = (req['path'] || req['fullpath'] || '').to_s
      query = req['params'].is_a?(Hash) ? URI.encode_www_form(req['params'].to_a) : nil
      if path && !path.empty?
        if query && !query.empty?
          "#{path}?#{query}"
        else
          path
        end
      end
    end

    # يحافظ على جميع باراميترات الاستعلام ويغيّر page فقط
    def build_url_with_params(base, assigns, page_param, new_value)
      # إذا كان لدينا base صالح، عدّل الـ query داخله
      if base && !base.empty?
        uri = URI.parse(base) rescue nil
        if uri
          q = URI.decode_www_form(String(uri.query)) rescue []
          # اجمع باراميترات request الحالية أيضاً
          req_params = (assigns.dig('request', 'params') || {}).to_a
          req_params.each { |kv| q << kv unless q.any? { |e| e[0] == kv[0] } }

          # أزل الـ page القديم ثم أضف الجديد
          q.reject! { |k, _| k == page_param }
          q << [page_param, new_value]
          uri.query = URI.encode_www_form(q)
          return uri.to_s
        end
      end

      # fallback بسيط
      "?#{page_param}=#{new_value}"
    end

    def current_page_from(assigns, param)
      req = assigns['request']
      return 1 unless req.is_a?(Hash) && req['params'].is_a?(Hash)
      p = req['params'][param] || req['params'][param.to_s]
      (p.to_i <= 0) ? 1 : p.to_i
    end

    def safe_int(val, fallback)
      i = val.to_i
      i > 0 ? i : fallback
    end

    # تعليق HTML يظهر فقط في الـ preview
    def preview_hint(msg)
      "<!-- #{msg} -->"
    end

    # تسجيل خطأ مفيد مع سياق
    def log_error(e, context, items_expr)
      assigns = context.environments.first || {}
      where = {
        at:     "paginate_tag",
        error:  e.class.name,
        msg:    e.message,
        items:  items_expr.to_s,
        req:    (assigns['request'] rescue nil),
      }
      Rails.logger.error(where.to_json)
    rescue
      # لا شيء
    end
  end
end
