"""
Message model - CQL table definition (ScyllaDB/Cassandra)
Table is created in database.py on startup.
"""
# Schema:
#   PRIMARY KEY (room_id, created_at, id)
#   CLUSTERING ORDER BY (created_at DESC, id DESC)
#
# room_id    INT        - partition key, all messages in a room on same node
# created_at TIMESTAMP  - clustering key, newest first
# id         UUID       - timeuuid for uniqueness
# sender_id  INT
# content    TEXT
