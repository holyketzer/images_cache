FactoryGirl.define do
  factory :product do
    sequence(:name) { |n| "Product#{n}" }
    image
  end

  images = ['tiger.jpg', 'another image.jpg', 'blue fish.jpg', 'yellow sun.jpg'].map { |file| 'spec/support/images/' + file }

  factory :image, aliases: [:avatar] do
    sequence(:cloudinary) { |n| File.open(File.join(Rails.root, images[n % images.size])) }
  end
end