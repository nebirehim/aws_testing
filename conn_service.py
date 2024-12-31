import contextlib
import logging
import os
import configparser

from sqlalchemy import create_engine, URL

logger = logging.getLogger(__name__)

# Load configuration file
config_parser = configparser.ConfigParser()
config_path = os.path.join(os.path.dirname(__file__), "passwords.ini")
if not config_parser.read(config_path):
    raise RuntimeError(f"Configuration file not found or could not be read at: {config_path}")
if 'database' not in config_parser.sections():
    raise RuntimeError("The configuration file is missing the 'database' section.")

def get_db_connection_engine():
    # Retrieve database credentials
    dsn = config_parser.get('database','dsn')
    db = 'AWSDB'
    user = config_parser.get('database', 'user')
    password = config_parser.get('database', 'password')
    odbcDriverForSqlServer = 'ODBC Driver 18 for SQL Server'

    # Create SQLAlchemy engine
    url = URL.create(
        drivername="mssql+pyodbc",
        username=user,
        password=password,
        host=dsn,
        database=db,
        query={"driver": odbcDriverForSqlServer, "Encrypt": "no"}
    )
    return create_engine(url, echo=False, fast_executemany=True)

@contextlib.contextmanager
def get_db_connection():
    try:
        logger.info("Attempting to establish database connection")
        conn = get_db_connection_engine().connect()
        logger.info("AWSDB database connection established")
        yield conn
    except Exception as e:
        logger.error(f"Failed to connect to the database: {e}")
        raise
    finally:
        conn.close()
        logger.info("Database connection closed")
