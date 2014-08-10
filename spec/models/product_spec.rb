require 'rails_helper'

describe Product do
  describe 'associations' do
    it { should have_one(:image) }
  end
end
