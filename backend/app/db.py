from typing import Generator

from sqlmodel import SQLModel, create_engine, Session
import time
from sqlalchemy import text
from sqlalchemy.exc import OperationalError

from .config import settings


connect_args = {}
if settings.database_url.startswith("sqlite"):
    connect_args = {"check_same_thread": False}
engine = create_engine(settings.database_url, echo=False, pool_pre_ping=True, connect_args=connect_args)


def create_db_and_tables() -> None:
    # Wait for DB to be reachable and create tables with simple retry
    max_attempts = 30
    for attempt in range(1, max_attempts + 1):
        try:
            with engine.begin() as conn:
                # lightweight probe
                conn.execute(text("SELECT 1"))
                SQLModel.metadata.create_all(conn)
            break
        except OperationalError:
            if attempt == max_attempts:
                raise
            time.sleep(2)


def get_session() -> Generator[Session, None, None]:
    with Session(engine) as session:
        yield session
