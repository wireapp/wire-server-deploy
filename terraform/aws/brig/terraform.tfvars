# Name of the prekeys table
prekey_table_name = "replace_this_with_prekey_table_name"
# Capacity allowed for the table. 100 should be plenty for production loads
# More info at: https://aws.amazon.com/dynamodb/pricing/provisioned/
prekey_table_read_capacity = 10
prekey_table_write_capacity = 10

# Name of the internal queue used by brig
internal_queue_name = "replace_this_with_internal_queue_name"

### Email section ###
email_sender = "test@example.com"
ses_queue_name = "replace_this_with_name_of_the_queue_to_get_email_notifications"
