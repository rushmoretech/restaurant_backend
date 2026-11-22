require "test_helper"

class OrderItemTest < ActiveSupport::TestCase
  def build_item(**attrs)
    OrderItem.new({
      order: orders(:pending_order),
      menu_item: menu_items(:steak),
      quantity: 1,
      unit_price: 45
    }.merge(attrs))
  end

  test "fixtures are valid" do
    OrderItem.find_each { |item| assert item.valid?, item.errors.full_messages.to_sentence }
  end

  test "valid with required attributes" do
    assert build_item.valid?
  end

  test "requires an order" do
    item = build_item(order: nil)
    assert_not item.valid?
    assert_includes item.errors[:order], "must exist"
  end

  test "requires a menu item" do
    item = build_item(menu_item: nil)
    assert_not item.valid?
    assert_includes item.errors[:menu_item], "must exist"
  end

  test "quantity defaults to 1" do
    assert_equal 1, OrderItem.new.quantity
  end

  test "requires a quantity" do
    item = build_item(quantity: nil)
    assert_not item.valid?
    assert_includes item.errors[:quantity], "can't be blank"
  end

  test "quantity must be a positive integer" do
    [ 0, -1, 1.5 ].each do |value|
      assert_not build_item(quantity: value).valid?, "#{value} should be invalid"
    end
  end

  test "requires a unit_price" do
    item = build_item(unit_price: nil)
    assert_not item.valid?
    assert_includes item.errors[:unit_price], "can't be blank"
  end

  test "unit_price cannot be negative" do
    item = build_item(unit_price: -1)
    assert_not item.valid?
    assert_includes item.errors[:unit_price], "must be greater than or equal to 0"
  end

  test "unit_price may be zero" do
    assert build_item(unit_price: 0).valid?
  end

  test "special_requests is optional" do
    assert build_item(special_requests: nil).valid?
    assert_nil order_items(:steak_in_delivered).special_requests
  end

  test "unit_price is a snapshot and does not follow menu price changes" do
    item = order_items(:soup_in_pending)
    item.menu_item.update!(price: 99)
    assert_equal BigDecimal("12.50"), item.reload.unit_price
  end
end
