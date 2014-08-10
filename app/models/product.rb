class Product < ActiveRecord::Base
  has_one :image, as: :imageable

  accepts_nested_attributes_for :image
end