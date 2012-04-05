# == Schema Information
#
# Table name: users
#
#  id         :integer         not null, primary key
#  name       :string(255)
#  email      :string(255)
#  is_admin   :boolean
#  created_at :datetime        not null
#  updated_at :datetime        not null
#

class User < ActiveRecord::Base
	attr_accessible :name, :email, :is_admin, :password
	before_save :create_remember_token

	validates :name,	presence: true,
										length: { maximum: 50 },
										uniqueness: true

	VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
	validates :email,	presence: true,
										format: { with: VALID_EMAIL_REGEX },
										uniqueness: { case_sensitive: false }

	has_secure_password
	validates :password,	length: { minimum: 6 }

	private

		def create_remember_token
			self.remember_token = SecureRandom.urlsafe_base64
		end
end
