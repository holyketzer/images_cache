require 'rails_helper'

describe Image do
  describe 'associations' do
    it { should belong_to(:imageable) }
  end

  describe 'caching' do
    before do
      $redis.flushdb

      tmp_files = File.join Rails.root, 'public', Rails.application.config.cloudinary_cache_path, '*.jpg'
      Dir.glob(tmp_files).each { |f| File.delete(f) }
    end

    describe 'creating' do
      it 'should be loaded into cloudinary' do
        image = create(:image)
        expect(image.cloudinary_url).to_not be_empty
        expect(image.local).to be_nil
        expect(image.popular?).to eq false
      end

      it 'should became popular after link url' do
        image = create(:image)
        expect(image.url).to match(/http.+cloudinary.com/)
        expect(image.popular?).to eq true

        image.reload
        expect(image.local).to_not be_empty
        expect(image.local).to match(/^\w+\.jpg$/)
        expect(image.url).to include image.local
      end

      it 'should became unpopular if there are more popular images' do
        # MAX_CACHE_SIZE is setted in test env config
        expect(Image.const_get(:MAX_CACHE_SIZE)).to eq 2

        image = create(:image)
        image.url

        more_popular_images = create_list(:image, 2)
        2.times do
          more_popular_images.each { |i| i.url }
        end

        # Emulate Sidetiq call
        image.perform

        expect(image.popular?).to eq false
        more_popular_images.each do |i|
          expect(i.popular?).to eq true
        end
      end
    end
  end
end
