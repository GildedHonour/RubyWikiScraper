require "scraperwiki"
require "date"
require "rubygems"
require "bundler/setup"
require "capybara"
require "capybara/dsl"
require "capybara-webkit"

$base_url = "https://apply.hobartcity.com.au"
$full_url = "#{$base_url}/Pages/XC.Track/SearchApplication.aspx?d=thismonth&k=LodgementDate&t=PLN"
$main_xpath = '//div[@id="searchresult"]//div[@class="result"]'
$next_page_xpath = '//div[@class="pagination"]//a[@class="next"]'

Capybara.run_server = false
Capybara.current_driver = :webkit
Capybara.app_host = $base_url

class Spider
  include Capybara::DSL

  def scrape_page address_data, urls_data
    result = []
    for i in 0 ... address_data.size do
      address_data_item = address_data[i]
      urls_item = urls_data[i]

      page_info = {}
      page_info["council_reference"] = urls_item[urls_item.index("=") + 1..-1]
      page_info["info_url"] = $base_url + urls_item[5..-1]
      page_info["date_received"] = Date.today.to_s
      page_info["date_scraped"] = Date.today.to_s
      page_info["address"] = address_data_item
      page_info["description"] = "description"
      page_info["on_notice_to"] = Date.today.to_s
      page_info["comment_url"] = $base_url + urls_item[5..-1]

      result << page_info
    end

    result
  end

  def get_data
    address_data = all(:xpath, $main_xpath + '//a[@style="text-decoration:none; color:gray;"]/span[@style="font-size:larger; font-weight:bold;"]').map(&:text)
    urls_data = all(:xpath, $main_xpath + '//a[@style="text-decoration:none; color:gray;"]').map { |x| x[:href] }
    [address_data, urls_data]
  end

  def get_results
    visit($full_url)
    
    address_data, urls_data = get_data
    data1 = scrape_page(address_data, urls_data)

    next_page = all(:xpath, $next_page_xpath)[0] 
    data2_raw = []
    while next_page
      next_page.click
      address_data, urls_data = get_data
      data2_raw << scrape_page(address_data, urls_data)
      next_page = all(:xpath, $next_page_xpath)[0] 
    end

    data2 = data2_raw.flatten
    data1 + data2
  end
end

spider = Spider.new
results = spider.get_results
puts "There are #{results.size} records." 

if results.size > 0
  # save the first item to create a table if it doesn't exist
  # if a record with a given id already exists then it'll be updated, id will remain the same
  first_item = results[0]
  ScraperWiki.save_sqlite(["council_reference"], first_item)
  puts "Saved or updated record " + first_item["council_reference"]

  results[1..-1].each do |item|
    if ScraperWiki.select("* from swdata where `council_reference`='#{item['council_reference']}'").empty? 
      ScraperWiki.save_sqlite(["council_reference"], item)
      puts "Saved " + item["council_reference"]
    else
      puts "Skipping already saved record " + item["council_reference"]
    end
  end
else
  puts "There are no data to save"
end
