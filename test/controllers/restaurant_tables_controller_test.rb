require "test_helper"

class RestaurantTablesControllerTest < ActionDispatch::IntegrationTest
  # --- authentication ---------------------------------------------------------

  test "all endpoints require authentication" do
    get restaurant_tables_url
    assert_response :unauthorized

    post restaurant_tables_url, params: { table_number: 5, seats: 4 }, as: :json
    assert_response :unauthorized
  end

  # --- reading ----------------------------------------------------------------

  test "any authenticated role can list tables, ordered by number" do
    %i[customer waiter chef admin].each do |role|
      get restaurant_tables_url, headers: auth_headers(users(role))

      assert_response :success
      assert_equal [ 1, 2 ], response.parsed_body["restaurant_tables"].map { |t| t["table_number"] }
    end
  end

  test "index exposes only public fields" do
    get restaurant_tables_url, headers: auth_headers(users(:customer))

    assert_equal %w[id seats status table_number], response.parsed_body["restaurant_tables"].first.keys.sort
  end

  test "index filters by status" do
    get restaurant_tables_url, params: { status: "occupied" }, headers: auth_headers(users(:customer))

    assert_equal [ 2 ], response.parsed_body["restaurant_tables"].map { |t| t["table_number"] }
  end

  test "index with an unknown status returns nothing" do
    get restaurant_tables_url, params: { status: "broken" }, headers: auth_headers(users(:customer))

    assert_response :success
    assert_empty response.parsed_body["restaurant_tables"]
  end

  test "show returns a table" do
    get restaurant_table_url(restaurant_tables(:table_one)), headers: auth_headers(users(:customer))

    assert_response :success
    table = response.parsed_body["restaurant_table"]
    assert_equal 1, table["table_number"]
    assert_equal "available", table["status"]
  end

  test "show returns 404 for an unknown table" do
    get restaurant_table_url(id: 0), headers: auth_headers(users(:customer))

    assert_response :not_found
  end

  # --- create / destroy: admin only -------------------------------------------

  test "only admins can create or delete tables" do
    %i[customer waiter chef].each do |role|
      headers = auth_headers(users(role))

      assert_no_difference "RestaurantTable.count" do
        post restaurant_tables_url, params: { table_number: 5, seats: 4 }, headers: headers, as: :json
      end
      assert_response :forbidden

      assert_no_difference "RestaurantTable.count" do
        delete restaurant_table_url(restaurant_tables(:table_one)), headers: headers
      end
      assert_response :forbidden
    end
  end

  test "admin creates a table" do
    assert_difference "RestaurantTable.count", 1 do
      post restaurant_tables_url, params: { table_number: 5, seats: 6 },
                                  headers: auth_headers(users(:admin)), as: :json
    end

    assert_response :created
    table = response.parsed_body["restaurant_table"]
    assert_equal 5, table["table_number"]
    assert_equal 6, table["seats"]
    assert_equal "available", table["status"]
  end

  test "create rejects invalid data" do
    assert_no_difference "RestaurantTable.count" do
      post restaurant_tables_url, params: { table_number: 1, seats: 0, status: "broken" },
                                  headers: auth_headers(users(:admin)), as: :json
    end

    assert_response :unprocessable_content
    errors = response.parsed_body["errors"]
    assert_includes errors, "Table number has already been taken"
    assert_includes errors, "Seats must be greater than 0"
    assert_includes errors, "Status is not included in the list"
  end

  test "admin deletes a table but its orders are kept" do
    order = orders(:pending_order)

    assert_difference "RestaurantTable.count", -1 do
      assert_no_difference "Order.count" do
        delete restaurant_table_url(restaurant_tables(:table_two)), headers: auth_headers(users(:admin))
      end
    end

    assert_response :no_content
    assert_nil order.reload.restaurant_table_id
  end

  test "delete returns 404 for an unknown table" do
    delete restaurant_table_url(id: 0), headers: auth_headers(users(:admin))

    assert_response :not_found
  end

  # --- update -----------------------------------------------------------------

  test "customers and chefs cannot update tables" do
    %i[customer chef].each do |role|
      patch restaurant_table_url(restaurant_tables(:table_one)), params: { status: "occupied" },
                                                                 headers: auth_headers(users(role)), as: :json

      assert_response :forbidden
      assert restaurant_tables(:table_one).reload.available?
    end
  end

  test "waiter can change a table's status" do
    patch restaurant_table_url(restaurant_tables(:table_one)), params: { status: "occupied" },
                                                               headers: auth_headers(users(:waiter)), as: :json

    assert_response :success
    assert restaurant_tables(:table_one).reload.occupied?
  end

  test "waiter cannot change anything but the status" do
    table = restaurant_tables(:table_one)

    patch restaurant_table_url(table), params: { status: "reserved", table_number: 99, seats: 20 },
                                       headers: auth_headers(users(:waiter)), as: :json

    assert_response :success
    table.reload
    assert table.reserved?
    assert_equal 1, table.table_number
    assert_equal 4, table.seats
  end

  test "admin can change every attribute" do
    table = restaurant_tables(:table_one)

    patch restaurant_table_url(table), params: { table_number: 10, seats: 8, status: "reserved" },
                                       headers: auth_headers(users(:admin)), as: :json

    assert_response :success
    table.reload
    assert_equal [ 10, 8, "reserved" ], [ table.table_number, table.seats, table.status ]
  end

  test "update rejects invalid data" do
    patch restaurant_table_url(restaurant_tables(:table_one)), params: { status: "broken" },
                                                               headers: auth_headers(users(:waiter)), as: :json

    assert_response :unprocessable_content
    assert restaurant_tables(:table_one).reload.available?
  end

  test "update returns 404 for an unknown table" do
    patch restaurant_table_url(id: 0), params: { status: "occupied" },
                                       headers: auth_headers(users(:waiter)), as: :json

    assert_response :not_found
  end
end
