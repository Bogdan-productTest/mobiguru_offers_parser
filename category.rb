load 'database.rb'

class Category
	attr_reader :id, :name

	def initialize (id, name)
		@id = id
		@name = name
	end

	def getParentProducts
		client = Mssql.new
		query = "SELECT p.Id, p.MailId, p.CompanyName + ' ' + p.Name as Name, 'https://product-test.ru/' + c.Url + '/' + p.Url + '/kupit' as Url FROM Products as p INNER JOIN Categories as c ON p.CategoryId=c.id WHERE CategoryId=#{@id} AND Mailid IS NOT NULL"
		result = client.execute(query)
		arr = Array.new
		result.each do |row|
			arr << [row['Id'], row['MailId'], row['Name'], row['Url']]
		end
		arr
	end

	def getChildProducts
		client = Mssql.new
		query = "SELECT p.Id, p.ParentId, p.CompanyName + ' ' + p.Name as Name, 'https://product-test.ru/' + c.Url + '/' + p.Url + '/kupit' as Url FROM Products as p INNER JOIN Categories as c ON p.CategoryId=c.id WHERE p.CategoryId=#{@id} AND p.ParentId IS NOT NULL AND p.MailId IS NULL"
		result = client.execute(query)
		arr = Array.new
		result.each do |row|
			arr << [row['Id'], row['ParentId'], row['Name'], row['Url']]
		end
		arr
	end
end
