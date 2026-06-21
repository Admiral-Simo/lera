class AddDocumentTypeToGuests < ActiveRecord::Migration[8.1]
  def change
    add_column :guests, :document_type, :string
  end
end
