class Category < ApplicationRecord
  # Must be declared before the has_many so it runs before the dependent
  # destroy of the menu items.
  before_destroy :ensure_no_ordered_menu_items, prepend: true

  has_many :menu_items, dependent: :destroy

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  private

  # Menu items that appear in past orders must stay in the order history, so a
  # category containing any of them cannot be deleted.
  def ensure_no_ordered_menu_items
    return unless menu_items.joins(:order_items).exists?

    errors.add(:base, "Cannot delete a category that has menu items used in orders")
    throw :abort
  end
end
