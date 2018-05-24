ActiveRecord::Schema.define do
  create_table :animals do |t|
    t.string :name
    t.string :species, null: :false
    t.datetime :created_at
    t.datetime :updated_at
  end
end
