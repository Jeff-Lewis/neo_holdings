require 'rubygems'
require 'neography'
require 'sinatra'
require 'uri'
require 'mechanize'
  
def scrape_symbols
  a = Mechanize.new
  letters = %w[a b c d e f g h i j k l m n o p q r s t u v w x y z]
  letters.each do |letter|
    puts "Getting letter #{letter} funds..."
    symbols = []
    names = []
    a.get("http://www.investorguide.com/funds/mutual-fund-list-#{letter}.html") do |page|
      page.parser.xpath("//div[@class='column fund-list-ticker']").each{|n| symbols << n.text.strip }
      page.parser.xpath("//div[@class='column fund-list-links']").each{|n| names << n.text.strip }
    end
    File.open("data/#{letter}_funds.json", 'w') {|f| f.write(Hash[*symbols.zip(names).flatten].to_json) }
  end  
end
