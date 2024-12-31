from sqlalchemy.sql import text
import conn_service as cm 

def execute_and_commit_procedure(procedure_name: str):
    with cm.get_db_connection() as conn:
        try:
            trans = conn.begin()
            # Use the `text` function to wrap the SQL statement
            sql_statement = text(f"EXEC AppSchema.{procedure_name}")
            r = conn.execute(sql_statement)
            trans.commit()
        except Exception as e:
            trans.rollback()
            raise RuntimeError(f"Failed to execute procedure '{procedure_name}': {e}")
