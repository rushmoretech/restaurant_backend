class User < ApplicationRecord
  has_secure_password

  enum :role, { customer: 0, waiter: 1, chef: 2, admin: 3 }

  has_many :orders, dependent: :destroy

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, allow_nil: true
  validates :role, presence: true
end
