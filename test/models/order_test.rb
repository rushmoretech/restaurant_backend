require "test_helper"

class OrderTest < ActiveSupport::TestCase
  def build_order(**attrs)
    Order.new({ user: users(:customer), total_price: 10 }.merge(attrs))
  end

  test "fixtures are valid" do
    Order.find_each { |order| assert order.valid?, order.errors.full_messages.to_sentence }
  end

  test "valid with required attributes" do
    assert build_order.valid?
  end

  test "requires a user" do
    order = build_order(user: nil)
    assert_not order.valid?
    assert_includes order.errors[:user], "must exist"
  end

  test "restaurant table is optional" do
    order = build_order(restaurant_table: nil)
    assert order.valid?
    assert orders(:delivered_order).restaurant_table.nil?
  end

  test "can be assigned to a table" do
    assert_equal restaurant_tables(:table_two), orders(:pending_order).restaurant_table
  end

  test "status defaults to pending" do
    assert build_order.pending?
  end

  test "status cannot be nil" do
    order = build_order(status: nil)
    assert_not order.valid?
    assert_includes order.errors[:status], "can't be blank"
  end

  test "defines the expected statuses" do
    assert_equal %w[pending preparing ready delivered cancelled], Order.statuses.keys
  end

  test "status predicates, scopes and transitions work" do
    order = orders(:pending_order)
    assert order.pending?
    assert_includes Order.pending, order

    order.preparing!
    assert order.reload.preparing?
    assert_not_includes Order.pending, order
  end

  test "an unknown status is a validation error, not an exception" do
    order = build_order(status: "lost")
    assert_not order.valid?
    assert_includes order.errors[:status], "is not included in the list"
  end

  test "total_price defaults to zero" do
    assert_equal 0, Order.new.total_price
  end

  test "requires a total_price" do
    order = build_order(total_price: nil)
    assert_not order.valid?
    assert_includes order.errors[:total_price], "can't be blank"
  end

  test "total_price cannot be negative" do
    order = build_order(total_price: -1)
    assert_not order.valid?
    assert_includes order.errors[:total_price], "must be greater than or equal to 0"
  end

  test "has many order items and menu items through them" do
    order = orders(:pending_order)
    assert_includes order.order_items, order_items(:soup_in_pending)
    assert_includes order.menu_items, menu_items(:soup)
  end

  test "destroying an order destroys its order items" do
    assert_difference "OrderItem.count", -1 do
      orders(:pending_order).destroy
    end
  end

  test "destroying an order keeps the menu items" do
    assert_no_difference "MenuItem.count" do
      orders(:pending_order).destroy
    end
  end

  # --- status flow and permissions ------------------------------------------

  test "STATUS_FLOW covers every status" do
    assert_equal Order.statuses.keys.sort, Order::STATUS_FLOW.keys.sort
  end

  test "can_transition_to? follows the status flow" do
    assert orders(:pending_order).can_transition_to?("preparing")
    assert orders(:pending_order).can_transition_to?(:cancelled)
    assert_not orders(:pending_order).can_transition_to?("ready")
    assert_not orders(:pending_order).can_transition_to?("pending")
    assert_not orders(:preparing_order).can_transition_to?("cancelled")
  end

  test "delivered and cancelled orders are final" do
    Order.statuses.each_key do |status|
      assert_not orders(:delivered_order).can_transition_to?(status)
    end
    assert_not Order.new(status: :cancelled).can_transition_to?("pending")
  end

  test "each role can only perform its own transitions" do
    pending = orders(:pending_order)
    preparing = orders(:preparing_order)
    ready = orders(:ready_order)

    assert pending.transition_permitted_for?(users(:chef), "preparing")
    assert preparing.transition_permitted_for?(users(:chef), "ready")
    assert_not ready.transition_permitted_for?(users(:chef), "delivered")

    assert ready.transition_permitted_for?(users(:waiter), "delivered")
    assert pending.transition_permitted_for?(users(:waiter), "cancelled")
    assert_not preparing.transition_permitted_for?(users(:waiter), "ready")

    assert pending.transition_permitted_for?(users(:customer), "cancelled")
    assert_not pending.transition_permitted_for?(users(:customer), "preparing")
  end

  test "admins can perform every transition in the flow but nothing outside it" do
    Order::STATUS_FLOW.each do |from, targets|
      order = Order.new(status: from)
      Order.statuses.each_key do |to|
        assert_equal targets.include?(to), order.transition_permitted_for?(users(:admin), to), "#{from} -> #{to}"
      end
    end
  end

  test "visible_to scopes customers to their own orders and shows staff everything" do
    assert_equal [ orders(:delivered_order), orders(:pending_order) ].sort_by(&:id),
                 Order.visible_to(users(:customer)).sort_by(&:id)
    assert_equal Order.count, Order.visible_to(users(:waiter)).count
    assert_equal Order.count, Order.visible_to(users(:admin)).count
  end
end
