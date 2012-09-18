class CreateReports < ActiveRecord::Migration
  def change
    create_table :reports do |t|
      t.string :client
      t.string :title
      t.string :analytics_key

      t.timestamps
    end
  end
end
