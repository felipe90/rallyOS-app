import shutil
import os

def main():
    dump_path = "supabase/full_schema.sql"
    target_path = "supabase/temp_migrations/00000000000001_foundation.sql"
    
    os.makedirs("supabase/temp_migrations", exist_ok=True)
    
    # Copy the full topological sort provided by Postgres to guarantee 100% CI/CD stability
    shutil.copy2(dump_path, target_path)
    
    print("Database Squashed to Foundation successfully.")

if __name__ == "__main__":
    main()
