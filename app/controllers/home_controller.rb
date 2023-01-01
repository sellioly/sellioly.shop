class HomeController < ApplicationController
  def index
    Liquid::Template.error_mode = :strict
    @path = Rails.root.to_s + ("/storage/template")
    Liquid::Template.file_system = Liquid::LocalFileSystem.new(@path, '%s.liquid')
    @template = Liquid::Template.parse("{{ 'section-main-product.css' | asset_url | stylesheet_tag }} {% render \"test\" %} hi {{ product.collection.name }}") # Parses and compiles the template
    # @items = @template.root.nodelist
    @test = @template.render('product' => { 'collection' => { 'name' => 'Computer' } }) # => "hi tobi"
  end
end
