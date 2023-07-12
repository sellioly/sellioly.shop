class HomeController < ApplicationController
  def index
    @path = Rails.root.to_s + ("/storage/template")
    Liquid::Template.file_system = Liquid::LocalFileSystem.new(@path, '%s.liquid')
    @template = Liquid::Template.parse(File.read(@path + '/test.liquid')) # Parses and compiles the template
    # @items = @template.root.nodelist
    @test = @template.render('product' => { 'collection' => { 'name' => 'Computer' } }) # => "hi tobi"
  end
end
