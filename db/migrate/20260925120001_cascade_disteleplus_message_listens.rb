# frozen_string_literal: true

class CascadeDisteleplusMessageListens < ActiveRecord::Migration[7.2]
  def up
    remove_foreign_key :disteleplus_message_listens, column: :message_id
    add_foreign_key :disteleplus_message_listens,
                    :disteleplus_messages,
                    column: :message_id,
                    on_delete: :cascade
  end

  def down
    remove_foreign_key :disteleplus_message_listens, column: :message_id
    add_foreign_key :disteleplus_message_listens, :disteleplus_messages, column: :message_id
  end
end
