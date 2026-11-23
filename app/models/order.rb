class Order < ApplicationRecord
  enum :status, { pending: 0, preparing: 1, ready: 2, delivered: 3, cancelled: 4 }, validate: true

  # Statuses an order can move to from each status. delivered and cancelled are final.
  STATUS_FLOW = {
    "pending" => %w[preparing cancelled],
    "preparing" => %w[ready],
    "ready" => %w[delivered],
    "delivered" => [],
    "cancelled" => []
  }.freeze

  # Transitions each role may perform. Admins may perform any transition in STATUS_FLOW.
  ROLE_TRANSITIONS = {
    "customer" => { "pending" => %w[cancelled] },
    "waiter" => { "pending" => %w[cancelled], "ready" => %w[delivered] },
    "chef" => { "pending" => %w[preparing], "preparing" => %w[ready] }
  }.freeze

  belongs_to :user
  belongs_to :restaurant_table, optional: true
  has_many :order_items, dependent: :destroy
  has_many :menu_items, through: :order_items

  validates :status, presence: true
  validates :total_price, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Customers only see their own orders; staff see all of them.
  scope :visible_to, ->(user) { user.customer? ? where(user: user) : all }

  def can_transition_to?(new_status)
    STATUS_FLOW.fetch(status).include?(new_status.to_s)
  end

  def transition_permitted_for?(user, new_status)
    return false unless can_transition_to?(new_status)
    return true if user.admin?

    ROLE_TRANSITIONS.fetch(user.role, {}).fetch(status, []).include?(new_status.to_s)
  end
end
