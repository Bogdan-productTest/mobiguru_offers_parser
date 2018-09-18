require 'nokogiri'
require 'open-uri'
require 'csv'
require 'net/http'
require 'uri'
require 'time'
load 'database.rb'
load 'category.rb'

KEY = JSON.parse('config/config.json')['api-key']
categories_string = 'smartfony'

def getOffers(id)
    arr = Array.new
    [['Москва','2097','213'], ['Санкт-Петербург','2287','2'], ['Казань','1283','11119']].each do |city|
        params = [["id", id], ["city", city[0]], ["geoBaseId", city[1]], ["mobiGuruId", city[2]], ["tab", "3"], ["needFilter", "true"],  ["filters", "[]"]]
        uri = URI('https://product-test.ru/product/getnadavioffers')
        uri.query = URI.encode_www_form(params)
        req = Net::HTTP::Post.new(uri)
        req.content_type = "application/x-www-form-urlencoded; charset=UTF-8"
        req['User-Agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/68.0.3440.106 Safari/537.36'
        res = Net::HTTP.start(uri.hostname, uri.port,:use_ssl => true) do |http|
            doc = Nokogiri::HTML(http.request(req).body)
            arr << doc.xpath('//div[@class="buy__item"]').size
        end
    end
    arr
end

def getOffersFromMobiguruId(id)
    arr = Hash.new
        [['Moscow','213'], ['Piter','2'], ['Kazan','11119']].each do |city|
        res = Net::HTTP.get_response(URI("http://api.mobiguru.ru/v1/model/#{id}/offers.json?auth=#{KEY}&geo_id=#{city[1]}"))
        result = JSON.parse(res.body)
        arr[city[0]] = result['models']['total']
    end
    arr
end

def getOffersFromMobiguru(id)
    res = Net::HTTP.get_response(URI("http://api.mobiguru.ru/v1/model/#{id}/offers/stat.json?auth=#{KEY}"))
    puts "http://api.mobiguru.ru/v1/model/#{id}/offers/stat.json?auth=#{KEY}"
    result = JSON.parse(res.body)
    arr = Hash.new
    result['regions'].each do |region|
        case region['id']
        when 213
            arr['Moscow'] = region['offersCount']
        when 2
            arr['Piter'] = region['offersCount']
        when 11119
            arr['Kazan'] = region['offersCount']
        end
    end
    arr
end

def parsingCategoriesForTesting(id, name)
    filename = "test/#{name}_test.csv"
    puts "Парсинг категории #{name}"
    instance_variable_set("@#{name.gsub(/-/, '_')}", Category.new(id, name))
    category_class = instance_variable_get("@#{name.gsub(/-/, '_')}")
    products_parent = category_class.getParentProducts
    puts "Родительских товаров в категории: #{products_parent.count}"

    count_parent = 0
    CSV.open(filename, 'wb') do |csv|
        products_parent.each.with_index do |product, i|
            begin
                offers = getOffersFromMobiguruId(product[1])
            rescue Errno::ETIMEDOUT, Errno::ENETDOWN, Net::OpenTimeout => e
                puts e
                retry
            end
            csv << ['Id', 'Name', 'Url', 'Moscow', 'Piter', 'Kazan'] if count_parent == 0
            csv << [product[0], product[2], product[3], offers['Moscow'], offers['Piter'], offers['Kazan']]
            count_parent += 1
            puts "#{i+1}/#{products_parent.count}" if (i+1)%100==0
        end
    end

    products_child = category_class.getChildProducts
    puts "Дочерних товаров в категории: #{products_child.count}"
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
    end
end

categories = Mssql.new.getCategoriesFromUrl(categories_string)

puts "Всего категорий #{categories.count}"
categories.each do |category|
    parsingCategoriesForTesting(category[0], category[1])

    t = Time.now
    puts "Проверка категории: #{category[1]}"
    index = 0

    CSV.foreach("test/#{category[1]}_test.csv") do |row|
        if index == 0 then
            index += 1
            next
        end
        offers = getOffers(row[0])
        puts "Для товара #{row[2]}, #{row[0]} кол-во оферов для Москвы в файле: #{row[3]}, на сайте: #{offers[0]}" if !(row[3].to_i == offers[0].to_i)
        puts "Для товара #{row[2]}, #{row[0]} кол-во оферов для Питера в файле: #{row[4]}, на сайте: #{offers[1]}" if !(row[4].to_i == offers[1].to_i)
        puts "Для товара #{row[2]}, #{row[0]} кол-во оферов для Казани в файле: #{row[5]}, на сайте: #{offers[2]}" if !(row[5].to_i == offers[2].to_i)
        index += 1
    end
    puts "Завершено за #{(Time.now - t)/60} минут"
end

