class Order < ApplicationRecord
  enum :status, { pending: 0, preparing: 1, ready: 2, delivered: 3, cancelled: 4 }

  belongs_to :user
  belongs_to :restaurant_table, optional: true
  has_many :order_items, dependent: :destroy
  has_many :menu_items, through: :order_items

  validates :status, presence: true
  validates :total_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
end

