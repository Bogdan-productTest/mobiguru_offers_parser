require 'csv'
require 'net/http'
require 'uri'
require 'logger'
require 'time'
load 'database.rb'
load 'category.rb'

KEY = JSON.parse(File.read 'config/config.json')['api-key']
categories_string = ARGV[0]
LOGGER = Logger.new("log/parser.log")

def getOffersFromMobiguruId(id)
    arr = Hash.new
        [['Moscow','213'], ['Piter','2'], ['Kazan','11119']].each do |city|
            LOGGER.info "Parsing http://api.mobiguru.ru/v1/model/#{id}/offers.json?auth=#{KEY}&geo_id=#{city[1]}"
            res = Net::HTTP.get_response(URI("http://api.mobiguru.ru/v1/model/#{id}/offers.json?auth=#{KEY}&geo_id=#{city[1]}"))
            result = JSON.parse(res.body)
            arr[city[0]] = result['models']['total']
        end
    arr
end

def parsingCategoriesToCSV(id, name)
    filename = "csv/#{name}.csv"
    puts "Парсинг категории #{name}"
    LOGGER.info "Parsing category #{name}"
    instance_variable_set("@#{name.gsub(/-/, '_')}", Category.new(id, name))
    category_class = instance_variable_get("@#{name.gsub(/-/, '_')}")
    products_parent = category_class.getParentProducts
    puts "Родительских товаров в категории: #{products_parent.count}"
    t = Time.now

    count_parent = 0
    CSV.open(filename, 'wb') do |csv|
        products_parent.each.with_index do |product, i|
            LOGGER.info "Id is #{product[0]}"
            csv << ['Id', 'Name', 'Url', 'Moscow', 'Piter', 'Kazan'] if count_parent == 0
            begin
                offers = getOffersFromMobiguruId(product[1])
            rescue Errno::ETIMEDOUT, Errno::ENETDOWN, Net::OpenTimeout => e
                LOGGER.error e
                puts e
                retry
            end 
            csv << [product[0], product[2], product[3], offers['Moscow'], offers['Piter'], offers['Kazan']]
            count_parent += 1
            puts "#{i+1}/#{products_parent.count}" if (i+1)%100==0
        end
        File.delete(filename) if count_parent == 0
    end

    products_child = category_class.getChildProducts
    if products_child.count > 0 && File.exist?(filename) then
        count_child = 0
        products_child.each.with_index do |product, i|
            index = 0
            CSV.foreach(filename) do |row|
                break if index == (count_parent + 1)
                if row[0].to_i == product[1].to_i then
                    CSV.open(filename, 'a') {|csv| csv << [product[0], product[2], product[3], row[3], row[4], row[5]]} 
                    count_child += 1
                end
                index +=1
            end
        end
        puts "Дочерних товаров в категории: #{count_child}"
    end
    puts "Категория завершена за #{(Time.now - t)/60} минут"
end

categories = String.new
if categories_string.nil? then
    categories = Mssql.new.getAllCategories
else
    categories = Mssql.new.getCategoriesFromUrl(categories_string)
end

puts "Всего категорий #{categories.count}"
categories.each do |category|
    parsingCategoriesToCSV(category[0], category[1])
end
