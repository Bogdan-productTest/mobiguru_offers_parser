require 'tiny_tds'
require 'json'

class Mssql

	@@config = JSON.parse(File.read 'config/config.json')

	def execute (query)
		self.connection if (@con.nil? || !@con.active?)
		@con.execute(query)
	end

	def getAllCategories
		self.connection if (@con.nil? || !@con.active?)
		res = @con.execute('SELECT c.Id, c.Url FROM Categories as c INNER JOIN Products as p ON c.Id=p.CategoryId WHERE p.MailId IS NOT NULL GROUP BY c.Id, c.Url')
		arr = Array.new
		res.each do |row|
			arr << [row['Id'],row['Url']]
		end
		arr
	end

	def getCategoriesFromUrl(data)
		categories = data.each_line(' ').to_a
		string = String.new
		categories.each.with_index do |category, i|
			category.chomp!
			string += "'#{category}'" if i == 0
			string += ",'#{category}'" if i != 0
		end

		self.connection if (@con.nil? || !@con.active?)
		res = @con.execute("SELECT c.Id, c.Url FROM Categories as c INNER JOIN Products as p ON c.Id=p.CategoryId WHERE p.MailId IS NOT NULL AND c.Url IN (#{string}) GROUP BY c.Id, c.Url")
		arr = Array.new
		res.each do |row|
			arr << [row['Id'],row['Url']]
		end
		arr
	end

	protected

	def connection
		@con = TinyTds::Client.new username: @@config['username'], password: @@config['password'], host: @@config['host'], port: @@config['port'], database: @@config['database']
	end

	def active?
		@con.active?
	end

end

