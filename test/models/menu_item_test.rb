require "test_helper"

class MenuItemTest < ActiveSupport::TestCase
  def build_item(**attrs)
    MenuItem.new({ category: categories(:mains), name: "Pasta", price: 22.0 }.merge(attrs))
  end

  test "fixtures are valid" do
    MenuItem.find_each { |item| assert item.valid?, item.errors.full_messages.to_sentence }
  end

  test "valid with required attributes" do
    assert build_item.valid?
  end

  test "requires a name" do
    item = build_item(name: nil)
    assert_not item.valid?
    assert_includes item.errors[:name], "can't be blank"
  end

  test "requires a price" do
    item = build_item(price: nil)
    assert_not item.valid?
    assert_includes item.errors[:price], "can't be blank"
  end

  test "price cannot be negative" do
    item = build_item(price: -0.01)
    assert_not item.valid?
    assert_includes item.errors[:price], "must be greater than or equal to 0"
  end

  test "price may be zero" do
    assert build_item(price: 0).valid?
  end

  test "price must be numeric" do
    assert_not build_item(price: "abc").valid?
  end

  test "requires a category" do
    item = build_item(category: nil)
    assert_not item.valid?
    assert_includes item.errors[:category], "must exist"
  end

  test "is available by default" do
    assert build_item.is_available
  end

  test "is_available cannot be nil" do
    item = build_item(is_available: nil)
    assert_not item.valid?
    assert_includes item.errors[:is_available], "is not included in the list"
  end

  test "can be marked unavailable" do
    assert_not build_item(is_available: false).is_available
    assert_not menu_items(:sold_out).is_available
  end

  test "price keeps two decimal places" do
    item = build_item(price: 12.345)
    item.save!
    assert_equal BigDecimal("12.35"), item.reload.price
  end

  test "belongs to its category" do
    assert_equal categories(:starters), menu_items(:soup).category
  end

  test "cannot be destroyed while it has order items" do
    item = menu_items(:soup)
    assert_no_difference "MenuItem.count" do
      assert_not item.destroy
    end
    assert_not_empty item.errors
  end

  test "can be destroyed when it has no order items" do
    assert_difference "MenuItem.count", -1 do
      menu_items(:sold_out).destroy
    end
  end
end
