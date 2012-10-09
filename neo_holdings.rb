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

def create_graph
  neo = Neography::Rest.new
  letters = %w[a b c d e f g h i j k l m n o p q r s t u v w x y z]
  letters.each do |letter|
    puts "Creating Graph for letter #{letter} funds..."  
    funds = JSON.load(File.open("data/funds/#{letter}_funds.json", 'r').read)
    funds.each_pair do |symbol, name|
      commands = []
      commands << [:create_node, {:name => name, :symbol => symbol}]
      commands << [:add_node_to_index, "funds_index", "name", name, "{0}"]
      commands << [:add_node_to_index, "funds_index", "symbol", symbol, "{0}"]

      batch_results = neo.batch *commands
      fund_node_id = batch_results.first["body"]["self"].split('/').last
      
      holdings = JSON.load(File.open("data/holdings/#{symbol}_holdings.json", 'r').read)
      commands = []
      holdings.each do |holding|
        name = holding["company"] || ""
        symbol = holding["symbol"] || ""
        ytd_return = holding["return"] || ""
        commands << [:create_unique_node, "holdings", "name", name, {:name => name, :symbol => symbol, :ytd_return => ytd_return}]  
      end      
      batch_results = neo.batch *commands
      commands = []
            
      batch_results.each_with_index do |result, index|
        holding_node_id = result["body"]["self"].split('/').last
        percent = holdings[index]["percent"] || ""
        commands << [:create_relationship, "holds", fund_node_id, holding_node_id, {:percent => percent}] 
        #puts "Fund Node: #{fund_node_id} Holding Node: #{holding_node_id} Percent #{percent}"
      end      
      batch_results = neo.batch *commands
    end
  end
end