require "sequel"
require "honeycomb-beeline"

Honeycomb.configure do |config|
  config.write_key = "write_key"
  config.dataset = "dataset"
  config.service_name = "service_name"
  config.client = Libhoney::LogClient.new
end

# connect to an in-memory database
DB = Sequel.sqlite

# create an items table
DB.create_table :items do
  primary_key :id
  String :name, unique: true, null: false
  Float :price, null: false
end

# create a dataset from the items table
items = DB[:items]

# populate the table
items.insert(name: 'abc', price: rand * 100)
items.insert(name: 'def', price: rand * 100)
items.insert(name: 'ghi', price: rand * 100)

# print out the number of records
puts "Item count: #{items.count}"

# print out the average price
puts "The average price is: #{items.avg(:price)}"
