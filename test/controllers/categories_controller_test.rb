require "test_helper"

class CategoriesControllerTest < ActionDispatch::IntegrationTest
  # --- authentication ---------------------------------------------------------

  test "all endpoints require authentication" do
    get categories_url
    assert_response :unauthorized

    post categories_url, params: { name: "Desserts" }, as: :json
    assert_response :unauthorized
  end

  # --- reading ----------------------------------------------------------------

  test "any authenticated role can list categories, ordered by name" do
    %i[customer waiter chef admin].each do |role|
      get categories_url, headers: auth_headers(users(role))

      assert_response :success
      assert_equal %w[Mains Starters], response.parsed_body["categories"].map { |c| c["name"] }
    end
  end

  test "index exposes only public fields" do
    get categories_url, headers: auth_headers(users(:customer))

    assert_equal %w[description id name], response.parsed_body["categories"].first.keys.sort
  end

  test "show returns a category" do
    get category_url(categories(:starters)), headers: auth_headers(users(:customer))

    assert_response :success
    assert_equal "Starters", response.parsed_body["category"]["name"]
  end

  test "show returns 404 for an unknown category" do
    get category_url(id: 0), headers: auth_headers(users(:customer))

    assert_response :not_found
  end

  # --- writing: authorization -------------------------------------------------

  test "only admins can create, update or delete" do
    %i[customer waiter chef].each do |role|
      headers = auth_headers(users(role))

      assert_no_difference "Category.count" do
        post categories_url, params: { name: "Desserts" }, headers: headers, as: :json
      end
      assert_response :forbidden

      patch category_url(categories(:starters)), params: { name: "Hacked" }, headers: headers, as: :json
      assert_response :forbidden
      assert_equal "Starters", categories(:starters).reload.name

      assert_no_difference "Category.count" do
        delete category_url(categories(:starters)), headers: headers
      end
      assert_response :forbidden
    end
  end

  # --- writing: admin ---------------------------------------------------------

  test "admin creates a category" do
    assert_difference "Category.count", 1 do
      post categories_url, params: { name: "Desserts", description: "Sweet" },
                           headers: auth_headers(users(:admin)), as: :json
    end

    assert_response :created
    assert_equal "Desserts", response.parsed_body["category"]["name"]
  end

  test "create rejects invalid data" do
    assert_no_difference "Category.count" do
      post categories_url, params: { name: "starters" }, headers: auth_headers(users(:admin)), as: :json
    end

    assert_response :unprocessable_content
    assert_includes response.parsed_body["errors"], "Name has already been taken"
  end

  test "admin updates a category" do
    patch category_url(categories(:starters)), params: { name: "Appetizers" },
                                               headers: auth_headers(users(:admin)), as: :json

    assert_response :success
    assert_equal "Appetizers", categories(:starters).reload.name
  end

  test "update rejects invalid data" do
    patch category_url(categories(:starters)), params: { name: "" },
                                               headers: auth_headers(users(:admin)), as: :json

    assert_response :unprocessable_content
    assert_equal "Starters", categories(:starters).reload.name
  end

  test "admin deletes a category and its unordered menu items" do
    category = Category.create!(name: "Desserts")
    category.menu_items.create!(name: "Cake", price: 15)

    assert_difference [ "Category.count", "MenuItem.count" ], -1 do
      delete category_url(category), headers: auth_headers(users(:admin))
    end

    assert_response :no_content
  end

  test "a category with menu items used in orders cannot be deleted" do
    assert_no_difference [ "Category.count", "MenuItem.count" ] do
      delete category_url(categories(:starters)), headers: auth_headers(users(:admin))
    end

    assert_response :unprocessable_content
    assert_equal [ "Cannot delete a category that has menu items used in orders" ],
                 response.parsed_body["errors"]
  end

  test "delete returns 404 for an unknown category" do
    delete category_url(id: 0), headers: auth_headers(users(:admin))

    assert_response :not_found
  end
end
