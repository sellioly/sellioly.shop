# frozen_string_literal: true

module MoneyFilter
  # Example:
  #   {{ 1299 | money_cents: 'USD', 'after' }} → "12.99 USD"
  #
  # Params:
  #   cents: integer in cents
  #   currency: optional, defaults to Shop currency
  #   position: optional ("before" or "after"), defaults to "before"
  #
  def money_cents(cents, currency = nil, position = 'after')
    return '' if cents.nil?

    amount = cents.to_f / 100.0
    currency ||= shop_currency
    format_currency(amount, currency, position)
  end

  # Keep your older filters consistent
  def money_with_currency(money, currency = nil, position = 'after')
    return '' if money.nil?

    amount = money.to_f / 100.0
    currency ||= shop_currency
    format_currency(amount, currency, position)
  end

  def money(money)
    return '' if money.nil?
    format("$ %.2f", money / 100.0)
  end

  private

  def shop_currency
    ShopDrop.new.currency rescue 'USD'
  end

  def format_currency(amount, currency, position = 'before')
    formatted_amount = '%.2f' % amount
    if position.to_s == 'after'
      "#{formatted_amount} #{currency}"
    else
      "#{currency} #{formatted_amount}"
    end
  end
end
