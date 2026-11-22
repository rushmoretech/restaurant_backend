class RestaurantTable < ApplicationRecord
  enum :status, { available: 0, occupied: 1, reserved: 2 }

  has_many :orders, dependent: :nullify

  validates :table_number, presence: true,
                           uniqueness: true,
                           numericality: { only_integer: true, greater_than: 0 }
  validates :seats, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :status, presence: true
end

