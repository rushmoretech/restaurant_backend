# Builds and saves an order from a list of requested menu items.
#
# The server is the source of truth for money: every line's unit_price is
# copied from the menu and total_price is computed here, never taken from the
# client.
#
#   result = PlaceOrder.call(user: user, restaurant_table_id: 3,
#                            items: [{ menu_item_id: 1, quantity: 2 }])
#   result.success? # => true
#   result.order    # => the saved Order, or the unsaved one when it failed
#   result.errors   # => array of messages
class PlaceOrder
  Result = Struct.new(:order, :errors) do
    def success?
      errors.empty?
    end
  end

  def self.call(...)
    new(...).call
  end

  def initialize(user:, restaurant_table_id: nil, items: [])
    @user = user
    @restaurant_table_id = restaurant_table_id.presence
    @items = Array(items)
  end

  def call
    order = Order.new(user: @user)

    errors = []
    errors << "Restaurant table must exist" unless assign_table(order)
    errors << "Items can't be blank" if @items.empty?
    errors.concat(build_items(order))
    order.total_price = order.order_items.sum { |item| item.unit_price * item.quantity.to_i }
    errors.concat(order.errors.full_messages) unless order.valid?

    return Result.new(order, errors) if errors.any?

    order.save!
    Result.new(order, [])
  end

  private

  # The table is optional, but when an id is given it has to exist. (belongs_to
  # optional: true does not check this, so an unknown id would otherwise reach
  # the database and fail on the foreign key.)
  def assign_table(order)
    return true if @restaurant_table_id.nil?

    order.restaurant_table = RestaurantTable.find_by(id: @restaurant_table_id)
    order.restaurant_table.present?
  end

  def build_items(order)
    menu_items = MenuItem.where(id: @items.filter_map { |item| item[:menu_item_id] }).index_by(&:id)

    @items.filter_map do |item|
      menu_item = menu_items[item[:menu_item_id].to_i]

      if menu_item.nil?
        "Menu item #{item[:menu_item_id].inspect} does not exist"
      elsif !menu_item.is_available
        "#{menu_item.name} is not available"
      else
        order.order_items.build(
          menu_item: menu_item,
          quantity: item.fetch(:quantity, 1),
          unit_price: menu_item.price,
          special_requests: item[:special_requests]
        )
        nil
      end
    end
  end
end
