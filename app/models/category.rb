class Category < ApplicationRecord
  has_many :menu_items, dependent: :destroy

  validates :name, presence: true, uniqueness: { case_sensitive: false }
end

