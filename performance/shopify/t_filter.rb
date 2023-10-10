# frozen_string_literal: true
require 'liquid'

module TFilter
  def t(key)
    begin
      locale = 'en'


      return locale
    rescue => e
      puts e.message
    end
  end

  private

end
