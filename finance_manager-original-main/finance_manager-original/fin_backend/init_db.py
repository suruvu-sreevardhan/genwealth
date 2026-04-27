# fin_backend/init_db.py
from database import Base, engine
import models

# This will create all tables
Base.metadata.drop_all(bind=engine)
Base.metadata.create_all(bind=engine)
print("Database tables created successfully!")
