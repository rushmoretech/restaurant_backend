class CreateRestaurantTables < ActiveRecord::Migration[8.1]
  def change
    create_table :restaurant_tables do |t|
      t.integer :table_number, null: false
      t.integer :seats, default: 2, null: false
      t.integer :status, default: 0, null: false

      t.timestamps
    end
    add_index :restaurant_tables, :table_number, unique: true
  end
end
