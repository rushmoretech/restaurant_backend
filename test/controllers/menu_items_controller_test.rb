require "test_helper"

class MenuItemsControllerTest < ActionDispatch::IntegrationTest
  def item_params(**overrides)
    { category_id: categories(:mains).id, name: "Pasta", description: "Fresh", price: 22 }.merge(overrides)
  end

  # --- authentication ---------------------------------------------------------

  test "all endpoints require authentication" do
    get menu_items_url
    assert_response :unauthorized

    post menu_items_url, params: item_params, as: :json
    assert_response :unauthorized
  end

  # --- reading ----------------------------------------------------------------

  test "any authenticated role can list menu items" do
    %i[customer waiter chef admin].each do |role|
      get menu_items_url, headers: auth_headers(users(role))

      assert_response :success
      assert_equal 3, response.parsed_body["menu_items"].size
    end
  end

  test "index is ordered by name" do
    get menu_items_url, headers: auth_headers(users(:customer))

    names = response.parsed_body["menu_items"].map { |item| item["name"] }
    assert_equal names.sort, names
  end

  test "index filters by category" do
    get menu_items_url, params: { category_id: categories(:starters).id }, headers: auth_headers(users(:customer))

    assert_equal [ "Tomato Soup" ], response.parsed_body["menu_items"].map { |item| item["name"] }
  end

  test "index filters by availability" do
    get menu_items_url, params: { available: "true" }, headers: auth_headers(users(:customer))

    names = response.parsed_body["menu_items"].map { |item| item["name"] }
    assert_equal [ "Ribeye Steak", "Tomato Soup" ], names
  end

  test "available=false does not filter" do
    get menu_items_url, params: { available: "false" }, headers: auth_headers(users(:customer))

    assert_equal 3, response.parsed_body["menu_items"].size
  end

  test "price is serialized with two decimals" do
    get menu_item_url(menu_items(:soup)), headers: auth_headers(users(:customer))

    assert_response :success
    item = response.parsed_body["menu_item"]
    assert_equal "12.50", item["price"]
    assert_equal %w[category_id description id is_available name price], item.keys.sort
  end

  test "show returns 404 for an unknown item" do
    get menu_item_url(id: 0), headers: auth_headers(users(:customer))

    assert_response :not_found
  end

  # --- writing: authorization -------------------------------------------------

  test "only admins can create, update or delete" do
    %i[customer waiter chef].each do |role|
      headers = auth_headers(users(role))

      assert_no_difference "MenuItem.count" do
        post menu_items_url, params: item_params, headers: headers, as: :json
      end
      assert_response :forbidden

      patch menu_item_url(menu_items(:sold_out)), params: { price: 1 }, headers: headers, as: :json
      assert_response :forbidden
      assert_equal 30, menu_items(:sold_out).reload.price

      assert_no_difference "MenuItem.count" do
        delete menu_item_url(menu_items(:sold_out)), headers: headers
      end
      assert_response :forbidden
    end
  end

  # --- writing: admin ---------------------------------------------------------

  test "admin creates a menu item" do
    assert_difference "MenuItem.count", 1 do
      post menu_items_url, params: item_params, headers: auth_headers(users(:admin)), as: :json
    end

    assert_response :created
    item = response.parsed_body["menu_item"]
    assert_equal "Pasta", item["name"]
    assert_equal "22.00", item["price"]
    assert item["is_available"]
  end

  test "create rejects invalid data" do
    assert_no_difference "MenuItem.count" do
      post menu_items_url, params: item_params(name: "", price: -5),
                           headers: auth_headers(users(:admin)), as: :json
    end

    assert_response :unprocessable_content
    assert_includes response.parsed_body["errors"], "Name can't be blank"
    assert_includes response.parsed_body["errors"], "Price must be greater than or equal to 0"
  end

  test "create rejects an unknown category" do
    post menu_items_url, params: item_params(category_id: 0), headers: auth_headers(users(:admin)), as: :json

    assert_response :unprocessable_content
    assert_includes response.parsed_body["errors"], "Category must exist"
  end

  test "admin updates a menu item" do
    patch menu_item_url(menu_items(:sold_out)), params: { price: 35.5, is_available: true },
                                                headers: auth_headers(users(:admin)), as: :json

    assert_response :success
    item = menu_items(:sold_out).reload
    assert_equal BigDecimal("35.5"), item.price
    assert item.is_available
  end

  test "update rejects invalid data" do
    patch menu_item_url(menu_items(:soup)), params: { price: "abc" },
                                            headers: auth_headers(users(:admin)), as: :json

    assert_response :unprocessable_content
    assert_equal BigDecimal("12.50"), menu_items(:soup).reload.price
  end

  test "admin deletes an item that was never ordered" do
    assert_difference "MenuItem.count", -1 do
      delete menu_item_url(menu_items(:sold_out)), headers: auth_headers(users(:admin))
    end

    assert_response :no_content
  end

  test "an item used in orders cannot be deleted" do
    assert_no_difference "MenuItem.count" do
      delete menu_item_url(menu_items(:soup)), headers: auth_headers(users(:admin))
    end

    assert_response :unprocessable_content
    assert_not_empty response.parsed_body["errors"]
  end

  test "delete returns 404 for an unknown item" do
    delete menu_item_url(id: 0), headers: auth_headers(users(:admin))

    assert_response :not_found
  end
end
