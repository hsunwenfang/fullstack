from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import Field


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")
    # FastAPI
    app_name: str = Field(default="Fullstack AI App")
    debug: bool = Field(default=False)

    # Database URLs
    # Default to SQLite for easy local runs; Docker overrides via .env
    database_url: str = Field(default="sqlite:///./app.db", alias="DATABASE_URL")
    mongo_url: str = Field(default="mongodb://localhost:27017", alias="MONGO_URL")
    mongo_db: str = Field(default="appdb", alias="MONGO_DB")

    # GenAI provider (OpenAI-compatible)
    openai_api_key: str | None = Field(default=None, alias="OPENAI_API_KEY")
    openai_base_url: str | None = Field(default=None, alias="OPENAI_BASE_URL")
    openai_model: str = Field(default="gpt-4o-mini", alias="OPENAI_MODEL")

settings = Settings()  # type: ignore
