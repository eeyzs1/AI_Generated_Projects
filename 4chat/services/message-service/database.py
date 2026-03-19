"""
ScyllaDB connection for message-service
Uses cassandra-driver (compatible with both Cassandra and ScyllaDB)
"""
import os
import logging
from cassandra.cluster import Cluster
from cassandra.auth import PlainTextAuthProvider
from cassandra.policies import DCAwareRoundRobinPolicy

logger = logging.getLogger(__name__)

SCYLLA_HOSTS = os.environ.get("SCYLLA_HOSTS", "scylladb").split(",")
SCYLLA_PORT = int(os.environ.get("SCYLLA_PORT", "9042"))
SCYLLA_KEYSPACE = os.environ.get("SCYLLA_KEYSPACE", "im_message")
SCYLLA_USER = os.environ.get("SCYLLA_USER", "")
SCYLLA_PASSWORD = os.environ.get("SCYLLA_PASSWORD", "")

_cluster = None
_session = None


def get_session():
    global _cluster, _session
    if _session is None:
        kwargs = {
            "contact_points": SCYLLA_HOSTS,
            "port": SCYLLA_PORT,
            "load_balancing_policy": DCAwareRoundRobinPolicy(),
        }
        if SCYLLA_USER and SCYLLA_PASSWORD:
            kwargs["auth_provider"] = PlainTextAuthProvider(SCYLLA_USER, SCYLLA_PASSWORD)
        _cluster = Cluster(**kwargs)
        s = _cluster.connect()
        s.execute(f"""
            CREATE KEYSPACE IF NOT EXISTS {SCYLLA_KEYSPACE}
            WITH replication = {{'class': 'SimpleStrategy', 'replication_factor': 1}}
        """)
        s.set_keyspace(SCYLLA_KEYSPACE)
        s.execute("""
            CREATE TABLE IF NOT EXISTS messages (
                room_id    INT,
                created_at TIMESTAMP,
                id         UUID,
                sender_id  INT,
                content    TEXT,
                PRIMARY KEY (room_id, created_at, id)
            ) WITH CLUSTERING ORDER BY (created_at DESC, id DESC)
        """)
        _session = s
    return _session
