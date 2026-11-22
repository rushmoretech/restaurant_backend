require "test_helper"

class RestaurantTableTest < ActiveSupport::TestCase
  def build_table(**attrs)
    RestaurantTable.new({ table_number: 10, seats: 4 }.merge(attrs))
  end

  test "fixtures are valid" do
    RestaurantTable.find_each { |table| assert table.valid?, table.errors.full_messages.to_sentence }
  end

  test "valid with required attributes" do
    assert build_table.valid?
  end

  test "requires a table_number" do
    table = build_table(table_number: nil)
    assert_not table.valid?
    assert_includes table.errors[:table_number], "can't be blank"
  end

  test "table_number must be unique" do
    table = build_table(table_number: restaurant_tables(:table_one).table_number)
    assert_not table.valid?
    assert_includes table.errors[:table_number], "has already been taken"
  end

  test "table_number must be a positive integer" do
    [ 0, -1, 1.5 ].each do |value|
      assert_not build_table(table_number: value).valid?, "#{value} should be invalid"
    end
  end

  test "requires seats" do
    table = build_table(seats: nil)
    assert_not table.valid?
    assert_includes table.errors[:seats], "can't be blank"
  end

  test "seats must be a positive integer" do
    [ 0, -2, 2.5 ].each do |value|
      assert_not build_table(seats: value).valid?, "#{value} should be invalid"
    end
  end

  test "seats defaults to 2" do
    assert_equal 2, RestaurantTable.new.seats
  end

  test "status defaults to available" do
    assert build_table.available?
  end

  test "defines the expected statuses" do
    assert_equal %w[available occupied reserved], RestaurantTable.statuses.keys
  end

  test "status predicates and scopes work" do
    assert restaurant_tables(:table_two).occupied?
    assert_includes RestaurantTable.available, restaurant_tables(:table_one)
    assert_not_includes RestaurantTable.available, restaurant_tables(:table_two)
  end

  test "rejects an unknown status" do
    assert_raises(ArgumentError) { build_table(status: "broken") }
  end

  test "has many orders" do
    assert_includes restaurant_tables(:table_two).orders, orders(:pending_order)
  end

  test "destroying a table keeps its orders but clears the table" do
    order = orders(:pending_order)
    assert_no_difference "Order.count" do
      restaurant_tables(:table_two).destroy
    end
    assert_nil order.reload.restaurant_table_id
  end
end
