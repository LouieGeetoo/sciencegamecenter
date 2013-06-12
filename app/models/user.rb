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
	attr_accessible :name, :email, :is_admin, :password, :birth_date,
									:disabled, :parent_email, :is_teacher, :is_scientist,
									:is_authoritative, :is_game_developer, :description,
									:dummy_password, :prefers_gravatar
	before_save :create_remember_token
	before_validation :set_dummy_password_if_needed

	default_scope order: 'name ASC'

	has_many :player_reviews, dependent: :nullify
	has_many :comments, dependent: :nullify

	has_paper_trail

	alias_attribute :admin, :is_admin
	alias_attribute :teacher, :is_teacher
	alias_attribute :scientist, :is_scientist
	alias_attribute :authoritative, :is_authoritative
	alias_attribute :game_developer, :is_game_developer
	alias_attribute :developer, :is_game_developer
	alias_attribute :is_developer, :is_game_developer

	validates :name,	presence: true,
										length: { maximum: 50 },
										exclusion: { in: %w(admin superuser administrator fasadmin) }

	VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
	validates :email,	format: { with: VALID_EMAIL_REGEX },
										uniqueness: { case_sensitive: false }

	has_secure_password
	validates :password,	length: { minimum: 6 }, if: :validate_password?

	validates :birth_date, presence: true
	validates :parent_email, format: { with: VALID_EMAIL_REGEX },
													 if: :is_under_thirteen?
	validate :parent_email_differs_from_email, if: :is_under_thirteen?

	def is_under_thirteen?
		13.years.ago < self.birth_date
	end

	def is_oauth?
		self.oauth_token.present?
	end

	def is_not_oauth?
		!is_oauth?
	end

	def is_facebook?
		self.uid.present? && self.provider == 'facebook'
	end

	def has_password?
		self.password_digest.present? && !self.dummy_password?
	end

	def validate_password?
		has_password? || new_record?
	end

	def is_expert?
		is_teacher? || is_scientist? || is_game_developer?
	end

	def roles
		return description if description && !description.empty?
		roles = []
		if is_admin
			roles += ["SGC Admin"]
		end
		if is_authoritative
			roles += ["Authoritative"]
		end
		if is_teacher
			roles += ["Teacher"]
		end
		if is_scientist
			roles += ["Scientist"]
		end
		if is_game_developer
			roles += ["Game Developer"]
		end
		roles = roles.count > 0 ? roles.join(", ") : "Player"
	end

	def send_password_reset
  	generate_token(:password_reset_token)
  	self.password_reset_sent_at = Time.zone.now
  	save!(validate: false)
  	UserMailer.password_reset(self).deliver
  end

  def self.from_omniauth(auth, user = nil)
  	existing_password_user = user || where(email: auth.info.email).first
  	if existing_password_user && (existing_password_user.uid.blank? || existing_password_user.provider != auth.provider)
  		unless where(auth.slice(:provider, :uid)).count > 0
	  		existing_password_user.provider = auth.provider
	  		existing_password_user.original_provider = auth.provider if existing_password_user.original_provider.blank?
	  		existing_password_user.uid = auth.uid
	  		existing_password_user.oauth_token = auth.credentials.token
			  existing_password_user.oauth_expires_at = Time.at(auth.credentials.expires_at)
			  existing_password_user.save!(validate: false)
			  existing_password_user
			end
  	else
	  	where(auth.slice(:provider, :uid)).first_or_initialize.tap do |user|
		  	user.provider = auth.provider
		  	user.original_provider = auth.provider if user.original_provider.blank?
		    user.uid = auth.uid
		    user.oauth_token = auth.credentials.token
		    user.oauth_expires_at = Time.at(auth.credentials.expires_at)
		    user.name ||= auth.info.name
		    user.email ||= auth.info.email
		    user.birth_date ||= DateTime.strptime(auth.extra.raw_info.birthday, '%m/%d/%Y')
		    if user.password_digest.blank?
			    user.password_digest = SecureRandom.urlsafe_base64
			    user.dummy_password = true
			  end
		  	user.save!(validate: false)
		  end
		end
  end

  def remove_omniauth!
  	self.provider = nil
    self.uid = nil
    self.oauth_token = nil
    self.oauth_expires_at = nil
    self.save(validate: false)
  end

  def self.chart_data(start = 3.weeks.ago) #TODO: Make this not run a query for each date
  	(start.to_date..Date.today).map do |date|
  		if (date == start.to_date) || (date == Date.today) || (User.where(["date(created_at) = ?", date]).count > 0)
  		{
  			created_at: date,
  			count: User.where(["created_at <= ?", date]).count,
  			facebook_count: User.where(original_provider: 'facebook').where(["date(created_at) <= ?", date]).count
  		}
  		else
  		{
  			created_at: date
  		}
  		end
  	end
  end

  def self.ages_chart_data
  	ages = Array.new
  	User.all.each do |user|
  		ages[user.age] = (ages[user.age].present? ? ages[user.age]+1 : 0)
  	end
  	groups = {"0-7" => 0, "8-12" => 0, "13-15" => 0, "16-17" => 0, "18-24" => 0, "25-34" => 0, "35+" => 0}
  	(0..7).each 		{ |n| groups["0-7"] += (ages[n] || 0) }
  	(8..12).each 		{ |n| groups["8-12"] += (ages[n] || 0) }
  	(13..15).each 	{ |n| groups["13-15"] += (ages[n] || 0) }
  	(16..17).each 	{ |n| groups["16-17"] += (ages[n] || 0) }
  	(18..24).each 	{ |n| groups["18-24"] += (ages[n] || 0) }
  	(25..34).each 	{ |n| groups["25-34"] += (ages[n] || 0) }
  	(35..150).each 	{ |n| groups["35+"] += (ages[n] || 0) }
  	groups.map do |group|
  		{
  			age_group: group[0],
  			count: group[1]
  		}
  	end
  end

  def age(dob = birth_date) # from http://stackoverflow.com/a/2357790/560089
	  now = Time.now.utc.to_date
	  now.year - dob.year - ((now.month > dob.month || (now.month == dob.month && now.day >= dob.day)) ? 0 : 1)
	end

	private

		def create_remember_token
			generate_token(:remember_token)
		end

		def generate_token(column)
		  begin
		    self[column] = SecureRandom.urlsafe_base64
		  end while User.exists?(column => self[column])
		end

		def parent_email_differs_from_email
    if email == parent_email
      errors.add(:parent_email, "must be different from your own.") 
	    end
	  end

	  def set_dummy_password_if_needed
	  	if self.password.blank? && self.dummy_password
	  		self.password_digest = SecureRandom.urlsafe_base64
	  	end
	  end
end
