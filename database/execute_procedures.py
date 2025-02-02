import os
import database.connection_file as conn

DIRS = ['view_definitions', 'procedure_definitions']

files_to_ignore = ['Countries.Update_Macroeconomics.StoredProcedure.sql']


for dir in DIRS:
    source_files = os.listdir(dir)

    for file in source_files:
        if file not in files_to_ignore:
            print(file)
            with open(f"{dir}/{file}", "r", encoding='utf-8') as f:
                definition = f.read()

            conn.get_database_connection().execute(definition)
