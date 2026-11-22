require "test_helper"

class UserTest < ActiveSupport::TestCase
  def build_user(**attrs)
    User.new({
      first_name: "Elena",
      last_name: "Radu",
      email: "elena@example.com",
      password: "password123"
    }.merge(attrs))
  end

  test "fixtures are valid" do
    User.find_each { |user| assert user.valid?, "#{user.email}: #{user.errors.full_messages.to_sentence}" }
  end

  test "valid with all attributes" do
    assert build_user.valid?
  end

  test "requires first_name" do
    user = build_user(first_name: nil)
    assert_not user.valid?
    assert_includes user.errors[:first_name], "can't be blank"
  end

  test "requires last_name" do
    user = build_user(last_name: nil)
    assert_not user.valid?
    assert_includes user.errors[:last_name], "can't be blank"
  end

  test "requires email" do
    user = build_user(email: nil)
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "rejects malformed emails" do
    [ "plainaddress", "missing@", "@missing.com", "spaces in@example.com" ].each do |email|
      assert_not build_user(email: email).valid?, "#{email.inspect} should be invalid"
    end
  end

  test "accepts well-formed emails" do
    [ "a@b.co", "first.last@example.com", "user+tag@example.org" ].each do |email|
      assert build_user(email: email).valid?, "#{email.inspect} should be valid"
    end
  end

  test "email must be unique regardless of case" do
    user = build_user(email: users(:customer).email.upcase)
    assert_not user.valid?
    assert_includes user.errors[:email], "has already been taken"
  end

  test "requires a password on create" do
    user = build_user(password: nil)
    assert_not user.valid?
    assert_includes user.errors[:password], "can't be blank"
  end

  test "authenticates with the correct password only" do
    user = users(:customer)
    assert user.authenticate("password123")
    assert_not user.authenticate("wrong")
  end

  test "password is stored as a digest, not plain text" do
    user = build_user
    user.save!
    assert_not_equal "password123", user.password_digest
  end

  test "role defaults to customer" do
    assert_equal "customer", build_user.role
  end

  test "defines the expected roles" do
    assert_equal %w[customer waiter chef admin], User.roles.keys
  end

  test "role predicates and scopes work" do
    assert users(:chef).chef?
    assert_not users(:chef).admin?
    assert_includes User.waiter, users(:waiter)
    assert_not_includes User.waiter, users(:chef)
  end

  test "rejects an unknown role" do
    assert_raises(ArgumentError) { build_user(role: "manager") }
  end

  test "has many orders" do
    assert_includes users(:customer).orders, orders(:pending_order)
    assert_includes users(:customer).orders, orders(:delivered_order)
  end

  test "destroying a user destroys their orders and order items" do
    user = users(:customer)
    assert_difference [ "Order.count", "OrderItem.count" ], -2 do
      user.destroy
    end
  end
end
