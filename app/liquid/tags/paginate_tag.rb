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
# 1) Server-side: items يحتوي على Hash فيه data + meta
# 2) Client-side: items مصفوفة كاملة (نقسّم محلياً)
#
# التشخيص:
# - يسجّل أخطاء واضحة في اللوج
# - في وضع الـ preview (registers['preview'] == true) يضيف تعليقات HTML

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

        if coll_hash && coll_hash['meta'].is_a?(Hash)
          # ---- Server-side mode ----
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
            'previous_url' => (page > 1 ? build_url_with_params(base_url, assigns, @param, page - 1) : nil),
            'page'          => build_url_with_params(base_url, assigns, @param, '{{ page }}'),
          }

          render_with_paginate(context, paginate_hash)
        else
          # ---- Client-side mode ----
          items     = Array(collection)
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
            'previous_url' => (page > 1 ? build_url_with_params(base_url, assigns, @param, page - 1) : nil),
            'page'          => build_url_with_params(base_url, assigns, @param, '{{ page }}'),
          }

          render_with_paginate(context, paginate_hash)
        end

      rescue => e
        log_error(e, context, @items_expr)
        return preview_hint("PAGINATE_ERROR: #{e.class}: #{e.message}") if preview
        "" # في الإنتاج لا نفشل الصفحة
      end
    end

    private

    # نستدعي جسم البلوك بشكل صحيح (بدون super داخل دالة مساعدة)
    def render_with_paginate(context, paginate_hash)
      context.stack do
        context['paginate'] = paginate_hash
        # Liquid::BlockBody#render
        @body.render(context)
      end
    end

    # يحاول تحويل أي قيمة إلى Hash (لاستخدام data/meta)
    def to_hashish(obj)
      return obj if obj.is_a?(Hash)
      if obj.respond_to?(:to_liquid)
        val = obj.to_liquid
        return val if val.is_a?(Hash)
      end
      nil
    end

    # التقييم الصحيح لتعبير Liquid (حلّ مشكلة VariableLookup)
    def evaluate_items(context, expr)
      return [] unless expr
      context.evaluate(Liquid::Expression.parse(expr))
    rescue => e
      raise ArgumentError, "Failed to evaluate items expression: #{e.message}"
    end

    def current_base_url(assigns)
      return assigns['current_url'] if assigns['current_url'].is_a?(String) && !assigns['current_url'].empty?

      req = assigns['request']
      return nil unless req.is_a?(Hash)

      path  = (req['path'] || req['fullpath'] || '').to_s
      query = req['params'].is_a?(Hash) ? URI.encode_www_form(req['params'].to_a) : nil
      if path && !path.empty?
        query && !query.empty? ? "#{path}?#{query}" : path
      end
    end

    # يحافظ على جميع الباراميترات ويبدّل page فقط
    def build_url_with_params(base, assigns, page_param, new_value)
      if base && !base.empty?
        uri = URI.parse(base) rescue nil
        if uri
          q = URI.decode_www_form(String(uri.query)) rescue []
          # أضف باراميترات request الحالية إن لم تكن موجودة
          req_params = (assigns.dig('request', 'params') || {}).to_a
          req_params.each { |kv| q << kv unless q.any? { |e| e[0] == kv[0] } }
          # بدّل قيمة الـ page
          q.reject! { |k, _| k == page_param }
          q << [page_param, new_value]
          uri.query = URI.encode_www_form(q)
          return uri.to_s
        end
      end
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

    def preview_hint(msg)
      "<!-- #{msg} -->"
    end

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
