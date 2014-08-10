class CreateImages < ActiveRecord::Migration
  def change
    create_table :images do |t|
      t.references :imageable, polymorphic: true, index: true
      t.string :cloudinary
      t.string :local

      t.timestamps
    end

    remove_column :products, :image
  end
end
