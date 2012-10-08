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
    File.open("data/funds/#{letter}_funds.json", 'w') {|f| f.write(Hash[*symbols.zip(names).flatten].to_json) }
  end  
end

def scrape_holdings
  a = Mechanize.new
  letters = %w[a b c d e f g h i j k l m n o p q r s t u v w x y z]
  letters.each do |letter|
    puts "Getting holdings for letter #{letter} funds..."  
    funds = JSON.load(File.open("data/funds/#{letter}_funds.json", 'r').read)
    funds.each_pair do |symbol, name|
      puts "Getting holdings for #{name}..."  
      holdings = []
      begin
        a.get("http://finance.yahoo.com/q/hl?s=#{symbol}+Holdings") do |page|
          records = page.parser.xpath("//table[@class='yfnc_tableout1'][1]//td[@class='yfnc_tabledata1']").collect{|n| n.text.strip}
          records.each_slice(4) do |slice|
            holdings << {:company => slice[0], :symbol => slice[1], :percent => slice[2], :return => slice[3]}
          end
          File.open("data/holdings/#{symbol}_holdings.json", 'w') {|f| f.write(holdings.to_json) }
        end
      rescue
        puts "Problem scraping holdings for #{name}."
      end
    end
  end
end
