require "test_helper"

class OrdersControllerTest < ActionDispatch::IntegrationTest
  def order_params(**overrides)
    {
      restaurant_table_id: restaurant_tables(:table_one).id,
      items: [
        { menu_item_id: menu_items(:soup).id, quantity: 2, special_requests: "No basil" },
        { menu_item_id: menu_items(:steak).id, quantity: 1 }
      ]
    }.merge(overrides)
  end

  def place_order(user, **params)
    post orders_url, params: order_params(**params), headers: auth_headers(user), as: :json
  end

  def change_status(user, order, status)
    patch order_url(order), params: { status: status }, headers: auth_headers(user), as: :json
  end

  # --- authentication ---------------------------------------------------------

  test "all endpoints require authentication" do
    get orders_url
    assert_response :unauthorized

    post orders_url, params: order_params, as: :json
    assert_response :unauthorized

    patch order_url(orders(:pending_order)), params: { status: "cancelled" }, as: :json
    assert_response :unauthorized
  end

  # --- index ------------------------------------------------------------------

  test "customers only see their own orders" do
    get orders_url, headers: auth_headers(users(:customer))

    assert_response :success
    ids = response.parsed_body["orders"].map { |o| o["id"] }
    assert_equal [ orders(:pending_order).id, orders(:delivered_order).id ].sort, ids.sort
  end

  test "another customer does not see them" do
    get orders_url, headers: auth_headers(users(:other_customer))

    ids = response.parsed_body["orders"].map { |o| o["id"] }
    assert_equal [ orders(:preparing_order).id, orders(:ready_order).id ].sort, ids.sort
  end

  test "staff see every order" do
    %i[waiter chef admin].each do |role|
      get orders_url, headers: auth_headers(users(role))

      assert_equal Order.count, response.parsed_body["orders"].size
    end
  end

  test "index filters by status" do
    get orders_url, params: { status: "preparing" }, headers: auth_headers(users(:chef))

    assert_equal [ orders(:preparing_order).id ], response.parsed_body["orders"].map { |o| o["id"] }
  end

  test "index returns the newest orders first" do
    orders(:delivered_order).update_columns(created_at: 2.days.ago)
    orders(:pending_order).update_columns(created_at: 1.hour.ago)

    get orders_url, headers: auth_headers(users(:customer))

    assert_equal [ orders(:pending_order).id, orders(:delivered_order).id ],
                 response.parsed_body["orders"].map { |o| o["id"] }
  end

  # --- show -------------------------------------------------------------------

  test "show returns the order with its items and table" do
    get order_url(orders(:pending_order)), headers: auth_headers(users(:customer))

    assert_response :success
    order = response.parsed_body["order"]
    assert_equal "pending", order["status"]
    assert_equal "25.00", order["total_price"]
    assert_equal 2, order["table_number"]
    assert_equal [ { "id" => order_items(:soup_in_pending).id, "menu_item_id" => menu_items(:soup).id,
                     "quantity" => 2, "special_requests" => "No basil",
                     "name" => "Tomato Soup", "unit_price" => "12.50" } ], order["items"]
  end

  test "table_number is null for an order without a table" do
    get order_url(orders(:delivered_order)), headers: auth_headers(users(:customer))

    assert_nil response.parsed_body["order"]["table_number"]
  end

  test "a customer cannot see another customer's order" do
    get order_url(orders(:preparing_order)), headers: auth_headers(users(:customer))

    assert_response :not_found
  end

  test "staff can see any order" do
    get order_url(orders(:preparing_order)), headers: auth_headers(users(:waiter))

    assert_response :success
  end

  test "show returns 404 for an unknown order" do
    get order_url(id: 0), headers: auth_headers(users(:admin))

    assert_response :not_found
  end

  # --- create -----------------------------------------------------------------

  test "customer places an order; the server sets prices, total and owner" do
    assert_difference [ "Order.count" ], 1 do
      assert_difference "OrderItem.count", 2 do
        place_order users(:customer)
      end
    end

    assert_response :created
    order = Order.find(response.parsed_body["order"]["id"])
    assert_equal users(:customer), order.user
    assert order.pending?
    assert_equal restaurant_tables(:table_one), order.restaurant_table
    assert_equal BigDecimal("70.00"), order.total_price # 2 x 12.50 + 1 x 45.00
    assert_equal [ BigDecimal("12.50"), BigDecimal("45.00") ], order.order_items.order(:id).map(&:unit_price)
    assert_equal "No basil", order.order_items.find_by(menu_item: menu_items(:soup)).special_requests
    assert_equal "70.00", response.parsed_body["order"]["total_price"]
  end

  test "prices, total and user sent by the client are ignored" do
    place_order users(:customer),
                total_price: 0.01, user_id: users(:other_customer).id,
                items: [ { menu_item_id: menu_items(:steak).id, quantity: 1, unit_price: 0.01 } ]

    assert_response :created
    order = Order.order(:id).last
    assert_equal users(:customer), order.user
    assert_equal BigDecimal("45.00"), order.total_price
    assert_equal BigDecimal("45.00"), order.order_items.first.unit_price
  end

  test "quantity defaults to 1 and the table is optional" do
    place_order users(:customer), restaurant_table_id: nil,
                                  items: [ { menu_item_id: menu_items(:soup).id } ]

    assert_response :created
    order = Order.order(:id).last
    assert_nil order.restaurant_table
    assert_equal 1, order.order_items.first.quantity
  end

  test "the same item can appear on several lines" do
    place_order users(:customer), items: [ { menu_item_id: menu_items(:soup).id, quantity: 1 },
                                           { menu_item_id: menu_items(:soup).id, quantity: 2, special_requests: "Extra hot" } ]

    assert_response :created
    assert_equal BigDecimal("37.50"), Order.order(:id).last.total_price
  end

  test "waiter places an order for a customer" do
    place_order users(:waiter), user_id: users(:customer).id

    assert_response :created
    assert_equal users(:customer), Order.order(:id).last.user
  end

  test "admin places an order for a customer" do
    place_order users(:admin), user_id: users(:other_customer).id

    assert_response :created
    assert_equal users(:other_customer), Order.order(:id).last.user
  end

  test "staff without a user_id own the order themselves" do
    place_order users(:waiter)

    assert_response :created
    assert_equal users(:waiter), Order.order(:id).last.user
  end

  test "user_id must be a customer" do
    assert_no_difference "Order.count" do
      place_order users(:waiter), user_id: users(:chef).id
    end

    assert_response :unprocessable_content
    assert_equal [ "User must be an existing customer" ], response.parsed_body["errors"]
  end

  test "user_id must exist" do
    assert_no_difference "Order.count" do
      place_order users(:waiter), user_id: 0
    end

    assert_response :unprocessable_content
  end

  test "chefs cannot place orders" do
    assert_no_difference "Order.count" do
      place_order users(:chef)
    end

    assert_response :forbidden
  end

  test "an order needs at least one item" do
    [ [], nil, "soup" ].each do |items|
      assert_no_difference "Order.count" do
        place_order users(:customer), items: items
      end

      assert_response :unprocessable_content
      assert_includes response.parsed_body["errors"], "Items can't be blank"
    end
  end

  test "unavailable items are rejected and nothing is saved" do
    assert_no_difference [ "Order.count", "OrderItem.count" ] do
      place_order users(:customer), items: [ { menu_item_id: menu_items(:soup).id, quantity: 1 },
                                             { menu_item_id: menu_items(:sold_out).id, quantity: 1 } ]
    end

    assert_response :unprocessable_content
    assert_equal [ "Seasonal Special is not available" ], response.parsed_body["errors"]
  end

  test "unknown menu items are rejected" do
    assert_no_difference "Order.count" do
      place_order users(:customer), items: [ { menu_item_id: 0, quantity: 1 } ]
    end

    assert_response :unprocessable_content
    assert_equal [ "Menu item 0 does not exist" ], response.parsed_body["errors"]
  end

  test "invalid quantities are rejected" do
    [ 0, -1, 1.5, "abc" ].each do |quantity|
      assert_no_difference [ "Order.count", "OrderItem.count" ] do
        place_order users(:customer), items: [ { menu_item_id: menu_items(:soup).id, quantity: quantity } ]
      end

      assert_response :unprocessable_content, "quantity #{quantity.inspect} should be rejected"
    end
  end

  test "an unknown table is rejected" do
    assert_no_difference "Order.count" do
      place_order users(:customer), restaurant_table_id: 0
    end

    assert_response :unprocessable_content
    assert_includes response.parsed_body["errors"], "Restaurant table must exist"
  end

  test "all problems are reported together" do
    place_order users(:customer), restaurant_table_id: 0,
                                  items: [ { menu_item_id: menu_items(:sold_out).id }, { menu_item_id: 0 } ]

    assert_response :unprocessable_content
    assert_equal 3, response.parsed_body["errors"].size
  end

  test "later menu price changes do not alter a placed order" do
    place_order users(:customer), items: [ { menu_item_id: menu_items(:steak).id, quantity: 1 } ]
    menu_items(:steak).update!(price: 99)

    get order_url(Order.order(:id).last), headers: auth_headers(users(:customer))

    assert_equal "45.00", response.parsed_body["order"]["items"].first["unit_price"]
    assert_equal "45.00", response.parsed_body["order"]["total_price"]
  end

  # --- update: validation -----------------------------------------------------

  test "status is required" do
    patch order_url(orders(:pending_order)), params: {}, headers: auth_headers(users(:admin)), as: :json

    assert_response :unprocessable_content
  end

  test "an unknown status is rejected" do
    change_status users(:admin), orders(:pending_order), "lost"

    assert_response :unprocessable_content
    assert_equal [ "Status is not included in the list" ], response.parsed_body["errors"]
  end

  test "only the status can be changed" do
    order = orders(:pending_order)

    patch order_url(order), params: { status: "cancelled", total_price: 1, user_id: users(:chef).id },
                            headers: auth_headers(users(:admin)), as: :json

    assert_response :success
    order.reload
    assert_equal [ users(:customer), BigDecimal("25.00") ], [ order.user, order.total_price ]
  end

  test "update returns 404 for an unknown order" do
    patch order_url(id: 0), params: { status: "cancelled" }, headers: auth_headers(users(:admin)), as: :json

    assert_response :not_found
  end

  # --- update: transitions by role --------------------------------------------

  test "chef moves an order pending -> preparing -> ready" do
    change_status users(:chef), orders(:pending_order), "preparing"
    assert_response :success
    assert_equal "preparing", response.parsed_body["order"]["status"]
    assert orders(:pending_order).reload.preparing?

    change_status users(:chef), orders(:pending_order), "ready"
    assert_response :success
    assert orders(:pending_order).reload.ready?
  end

  test "waiter delivers a ready order" do
    change_status users(:waiter), orders(:ready_order), "delivered"

    assert_response :success
    assert orders(:ready_order).reload.delivered?
  end

  test "waiter can cancel a pending order" do
    change_status users(:waiter), orders(:pending_order), "cancelled"

    assert_response :success
    assert orders(:pending_order).reload.cancelled?
  end

  test "customer can cancel their own pending order" do
    change_status users(:customer), orders(:pending_order), "cancelled"

    assert_response :success
    assert orders(:pending_order).reload.cancelled?
  end

  test "a customer cannot touch another customer's order" do
    other = orders(:preparing_order)
    other.update_columns(status: Order.statuses[:pending])

    change_status users(:customer), other, "cancelled"

    assert_response :not_found
    assert other.reload.pending?
  end

  test "valid transitions are forbidden for the wrong role" do
    {
      users(:chef) => [ orders(:ready_order), "delivered" ],
      users(:waiter) => [ orders(:pending_order), "preparing" ],
      users(:customer) => [ orders(:pending_order), "preparing" ]
    }.each do |user, (order, status)|
      before = order.status

      change_status user, order, status

      assert_response :forbidden, "#{user.role} -> #{status}"
      assert_equal before, order.reload.status
    end
  end

  test "chefs and customers cannot cancel after preparation started" do
    change_status users(:chef), orders(:preparing_order), "cancelled"
    assert_response :unprocessable_content
    assert orders(:preparing_order).reload.preparing?
  end

  test "admin can perform any valid transition" do
    change_status users(:admin), orders(:pending_order), "preparing"
    assert_response :success
    change_status users(:admin), orders(:preparing_order), "ready"
    assert_response :success
    change_status users(:admin), orders(:ready_order), "delivered"
    assert_response :success
  end

  # --- update: impossible transitions are 422 for everyone ---------------------

  test "impossible transitions are rejected for every role" do
    cases = [
      [ orders(:delivered_order), "pending" ],
      [ orders(:delivered_order), "cancelled" ],
      [ orders(:pending_order), "pending" ],
      [ orders(:pending_order), "delivered" ],
      [ orders(:preparing_order), "pending" ]
    ]

    %i[customer waiter chef admin].each do |role|
      cases.each do |order, status|
        next if role == :customer && order.user != users(:customer)

        change_status users(role), order, status

        assert_response :unprocessable_content, "#{role}: #{order.status} -> #{status}"
        assert_match(/Cannot change status from #{order.status} to #{status}/, response.parsed_body["errors"].first)
      end
    end
  end

  test "cancelled orders are final" do
    orders(:pending_order).cancelled!

    change_status users(:admin), orders(:pending_order), "pending"

    assert_response :unprocessable_content
    assert orders(:pending_order).reload.cancelled?
  end

  test "orders cannot be deleted through the API" do
    assert_no_difference "Order.count" do
      delete order_url(orders(:pending_order)), headers: auth_headers(users(:admin))
    end

    assert_response :not_found
  end
end
