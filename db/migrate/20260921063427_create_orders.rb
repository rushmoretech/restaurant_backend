class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.references :user, null: false, foreign_key: true
      t.references :restaurant_table, null: true, foreign_key: true
      t.decimal :total_price, precision: 10, scale: 2, default: 0.0, null: false
      t.integer :status, default: 0, null: false

      t.timestamps
    end
  end
end
