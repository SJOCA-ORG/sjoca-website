class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :role, null: false, default: "superadmin"
      t.string :name
      t.datetime :last_signed_in_at
      t.timestamps
    end

    # Case-insensitively unique: an address typed with a capital letter is the
    # same person, and two rows for one person is how someone ends up locked
    # out of an account they are sure they have.
    add_index :users, "LOWER(email)", unique: true, name: "index_users_on_lower_email"
  end
end
