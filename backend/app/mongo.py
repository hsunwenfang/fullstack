from pymongo import MongoClient

from .config import settings


_mongo_client: MongoClient | None = None


def get_mongo_client() -> MongoClient:
    global _mongo_client
    if _mongo_client is None:
        _mongo_client = MongoClient(settings.mongo_url)
    return _mongo_client


def get_mongo_db():
    client = get_mongo_client()
    return client[settings.mongo_db]
