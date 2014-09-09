require "scraperwiki"
require "date"
require "rubygems"
require "pp"
require "bundler/setup"
require "capybara"
require "capybara/dsl"
require "capybara-webkit"

$base_url = "https://apply.hobartcity.com.au"
Capybara.run_server = false
Capybara.current_driver = :webkit
Capybara.app_host = $base_url

class Spider
  include Capybara::DSL

  def initialize
    @base_url = "https://apply.hobartcity.com.au"
    @full_url = "#{@base_url}/Pages/XC.Track/SearchApplication.aspx?d=thismonth&k=LodgementDate&t=PLN"
    @main_xpath = '//div[@id="searchresult"]//div[@class="result"]'
    @next_page_xpath = '//div[@class="pagination"]//a[@class="next"]'
  end

  def scrape_page address_data, urls_data
    page_info = {}
    for i in 0 ... address_data.size do
      address_data_item = address_data[i]
      urls_item = urls_data[i]

      page_info["council_reference"] = urls_item[urls_item.index("=") + 1 ... -1]
      page_info["info_url"] = @base_url + urls_item[5..-1]
      page_info["date_received"] = Date.today.to_s
      page_info["date_scraped"] = Date.today.to_s
      page_info["address"] = address_data_item
      page_info["description"] = "description"
      page_info["on_notice_to"] = Date.today.to_s
      page_info["comment_url"] = @base_url + urls_item[5..-1]
    end

    page_info
  end

  def get_data
    address_data = all(:xpath, @main_xpath + '//a[@style="text-decoration:none; color:gray;"]/span[@style="font-size:larger; font-weight:bold;"]').map(&:text)
    urls_data = all(:xpath, @main_xpath + '//a[@style="text-decoration:none; color:gray;"]').map { |x| x[:href] }
    
    [address_data, urls_data]
  end

  def get_results
    visit(@full_url)
    
    address_data, urls_data = get_data
    data1 = [scrape_page(address_data, urls_data)]

    next_page = all(:xpath, @next_page_xpath)[0] 
    data2 = []
    while next_page
      next_page.click
      address_data, urls_data = get_data
      data2 << scrape_page(address_data, urls_data)
      next_page = all(:xpath, @next_page_xpath)[0] 
    end

    data1 + data2
  end
end

spider = Spider.new
results = spider.get_results
# p results

results.each do |record|
  if ScraperWiki.select("* from data where `council_reference`='#{record['council_reference']}'").empty? 
   ScraperWiki.save_sqlite(['council_reference'], record)
  else
  puts "Skipping already saved record " + record['council_reference']
  end
end