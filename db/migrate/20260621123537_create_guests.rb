class CreateGuests < ActiveRecord::Migration[8.1]
  def change
    create_table :guests do |t|
      t.string :first_names
      t.string :last_name
      t.string :document_number
      t.string :sex
      t.date :birthdate
      t.date :expiry_date
      t.string :nationality
      t.string :issuing_state
      t.string :room_number
      t.datetime :checked_in_at
      t.string :status

      t.timestamps
    end
  end
end
