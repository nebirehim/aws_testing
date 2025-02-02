from sqlalchemy.sql import text
import conn_service as cm


def execute_and_commit_procedure(schema_name: str, procedure_name: str, params: dict = None):
    """
    Executes a stored procedure with optional parameters.

    :param schema_name: Name of the schema in database.
    :param procedure_name: Name of the stored procedure.
    :param params: Dictionary of procedure parameters (optional).
    """
    with cm.get_db_connection() as conn:
        try:
            trans = conn.begin()

            # Construct the SQL EXEC statement dynamically
            if params:
                param_str = ", ".join([f"@{key} = :{key}" for key in params.keys()])
                sql_statement = text(f"EXEC {schema_name}.{procedure_name} {param_str}")
            else:
                sql_statement = text(f"EXEC {schema_name}.{procedure_name}")

            # Execute the procedure with or without parameters
            conn.execute(sql_statement, params or {})

            trans.commit()
            print(f"Procedure '{procedure_name}' executed successfully.")

        except Exception as e:
            trans.rollback()
            raise RuntimeError(f"Failed to execute procedure '{procedure_name}': {e}")
