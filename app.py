import time
import pyodbc
import conn_service as cm
import util 
import logging 

logger = logging.getLogger(__name__)

def execute_procedure():
   util.execute_and_commit_procedure("PopulateTables")
   logger.info("Data inserted successfully")

if __name__ == "__main__":
    logging.basicConfig(level=logging.DEBUG)
    execute_procedure()
